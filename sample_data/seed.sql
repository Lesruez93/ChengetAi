-- ChengetAI Supabase schema + seed data
-- Run against a Supabase Postgres project (SQL editor or `supabase db push`).
-- Tables mirror backend/app/models/domain.py; the backend defaults to an
-- in-memory store when USE_SUPABASE=false, so this file is only required
-- once you point the backend at a real Supabase project.

-- ============================================================================
-- Extensions
-- ============================================================================
create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- ============================================================================
-- profiles: app-level user profile, 1:1 with auth.users
-- ============================================================================
create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text,
    phone_number text,
    trust_score numeric not null default 1.0 check (trust_score >= 0 and trust_score <= 2.0),
    consent_given_at timestamptz,          -- DPA consent checkbox timestamp, see docs/dataset_statement.md
    created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles are self-readable"
    on public.profiles for select
    using (auth.uid() = id);

create policy "profiles are self-updatable"
    on public.profiles for update
    using (auth.uid() = id);

create policy "profiles are self-insertable"
    on public.profiles for insert
    with check (auth.uid() = id);

-- ============================================================================
-- numbers: aggregated reputation per MSISDN (denormalized cache over reports)
--
-- msisdn is E.164 (+263771234567), never the local 0-prefixed form: across the
-- markets this deployment covers, local forms collide outright (0771234567 is
-- valid in Zimbabwe, Uganda and Tanzania), so a national-format primary key
-- would merge unrelated people's reputations into one row.
-- ============================================================================
create table if not exists public.numbers (
    msisdn text primary key check (msisdn ~ '^\+[1-9][0-9]{7,14}$'),
    country text not null default '',        -- ISO 3166-1 alpha-2, most-reported market
    report_count integer not null default 0,
    categories jsonb not null default '{}'::jsonb,
    countries jsonb not null default '{}'::jsonb,  -- report counts per reporting country
    last_reported_at timestamptz,
    is_publicly_flagged boolean not null default false,
    updated_at timestamptz not null default now()
);

alter table public.numbers enable row level security;

create policy "numbers are publicly readable"
    on public.numbers for select
    using (true);

-- writes to `numbers` happen only via the service-role key from the backend
-- (see backend/app/services/supabase_store.py); no client-side insert/update policy.

-- ============================================================================
-- reports: individual community reports against a number
-- ============================================================================
create table if not exists public.reports (
    id uuid primary key default gen_random_uuid(),
    msisdn text not null references public.numbers (msisdn) on delete cascade,
    country text not null,                   -- ISO 3166-1 alpha-2 of the reporter's market
    category text not null,
    region text not null default '',         -- province/county/state/zone, per country
    message_excerpt text default '',         -- redacted by the backend before insert
    reporter_id uuid references auth.users (id) on delete set null,
    reporter_trust numeric not null default 1.0,
    created_at timestamptz not null default now()
);

create index if not exists reports_msisdn_idx on public.reports (msisdn);
create index if not exists reports_created_at_idx on public.reports (created_at desc);
create index if not exists reports_category_idx on public.reports (category);
-- The feed filters by country and window on every read, so this pair is the
-- hot path for /feed/trending once report volume grows.
create index if not exists reports_country_created_at_idx
    on public.reports (country, created_at desc);

alter table public.reports enable row level security;

create policy "reports are publicly readable"
    on public.reports for select
    using (true);

create policy "authenticated users can create reports"
    on public.reports for insert
    to authenticated
    with check (auth.uid() = reporter_id);

-- Anonymous reporting is a deliberate product decision, not an oversight: the
-- people most exposed to retaliation are exactly the ones who will not report
-- under their own identity. Anonymous rows are inserted by the backend's
-- service-role key (which bypasses RLS) rather than by an anon client, so the
-- intake path still applies rate limiting, redaction and validation.

-- ============================================================================
-- scam_samples: labeled corpus used to train/evaluate the baseline classifier
-- (loaded from sample_data/scam_corpus.jsonl; see docs/dataset_statement.md)
-- ============================================================================
create table if not exists public.scam_samples (
    id uuid primary key default gen_random_uuid(),
    text text not null,
    label text not null check (label in ('scam', 'legit')),
    category text not null default 'other',
    country text not null default '',
    created_at timestamptz not null default now()
);

alter table public.scam_samples enable row level security;

create policy "scam samples are publicly readable"
    on public.scam_samples for select
    using (true);

-- ============================================================================
-- feed_items: editorial/aggregated "trending scams" entries
-- ============================================================================
create table if not exists public.feed_items (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    category text not null,
    summary text not null,
    country text,                            -- null = relevant across every market
    region text,
    created_at timestamptz not null default now()
);

alter table public.feed_items enable row level security;

create policy "feed items are publicly readable"
    on public.feed_items for select
    using (true);

-- ============================================================================
-- scam_trend_scores: cached output of the /feed/trending weighted-rules job
-- (recomputable at any time from `reports`; cached for cheap reads)
-- ============================================================================
create table if not exists public.scam_trend_scores (
    id uuid primary key default gen_random_uuid(),
    scope text not null,              -- 'category' | 'region' | 'country'
    key text not null,                -- e.g. 'mobile_money_reversal', 'Nairobi', 'KE'
    country text not null default '', -- scoping market for a 'category'/'region' row
    score numeric not null,
    report_count integer not null default 0,
    window_days integer not null default 7,
    computed_at timestamptz not null default now()
);

create index if not exists scam_trend_scores_scope_key_idx on public.scam_trend_scores (scope, key);

alter table public.scam_trend_scores enable row level security;

create policy "trend scores are publicly readable"
    on public.scam_trend_scores for select
    using (true);

-- ============================================================================
-- sentinel_jobs: audit log of Agent Fraud Sentinel CSV analyses (B2B module)
-- ============================================================================
create table if not exists public.sentinel_jobs (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid references auth.users (id) on delete set null,
    filename text not null,
    country text not null default '',
    n_transactions integer not null default 0,
    n_flagged integer not null default 0,
    created_at timestamptz not null default now()
);

alter table public.sentinel_jobs enable row level security;

create policy "sentinel jobs are self-readable"
    on public.sentinel_jobs for select
    using (auth.uid() = owner_id);

create policy "authenticated users can create their own sentinel jobs"
    on public.sentinel_jobs for insert
    to authenticated
    with check (auth.uid() = owner_id);

-- ============================================================================
-- Seed: sample feed items so the Alerts screen is never empty on a fresh project
-- ============================================================================
insert into public.feed_items (title, category, summary, country, region, created_at) values
    ('Wrong-deposit reversal scams surge across East and Southern Africa', 'mobile_money_reversal',
     'Reports from four markets describe the same script: a small or fake deposit notice, then pressure to "reverse" money to a different number. Check your real balance in the wallet app, not the SMS.',
     null, null, now() - interval '5 hours'),
    ('BVN revalidation phishing targeting Nigerian bank customers', 'otp_phishing',
     'SMS impersonating major banks asks customers to revalidate their BVN through a link within 24 hours. No Nigerian bank revalidates a BVN by SMS link.',
     'NG', 'Lagos', now() - interval '7 hours'),
    ('Reversal requests spreading from Dar es Salaam along the coast', 'mobile_money_reversal',
     'Reports describe an M-Pesa or Mixx notice followed by a call pressuring you to send the money back. Check the balance in the wallet menu before returning anything.',
     'TZ', 'Dar es Salaam', now() - interval '11 hours'),
    ('Callers posing as MoMo support in Greater Accra', 'impersonation',
     'Callers claiming to be MTN or Telecel support say your wallet is locked and ask you to call back on a number they supply. Use the short code printed by your provider instead.',
     'GH', 'Greater Accra', now() - interval '16 hours'),
    ('SIM re-registration scams reported in Kenya', 'sim_swap',
     'Messages claiming your line will be deactivated unless you confirm your ID are a pretext for SIM swap. Confirm any re-registration requirement with your operator directly.',
     'KE', null, now() - interval '1 day'),
    ('Callers posing as the EcoCash fraud desk in Harare', 'impersonation',
     'Callers claiming to be an EcoCash agent or fraud desk press you to read back a code to "reverse" a deposit you never received. No agent ever needs your code or PIN.',
     'ZW', 'Harare', now() - interval '9 hours'),
    ('SIM re-registration and upgrade pretexts in South Africa', 'sim_swap',
     'A "SIM upgrade" or re-registration request that asks for a code is an attempt to take over the number your banking OTPs arrive on. If your line goes dead, treat it as urgent.',
     'ZA', 'Western Cape', now() - interval '30 hours'),
    ('Placement-fee job scams reported across Uganda', 'fake_job',
     'Messages offering a confirmed placement ask for a processing fee by MoMo before any interview. A fee charged before work is the scam, whatever employer is named.',
     'UG', null, now() - interval '34 hours'),
    ('Grant approval scams asking for a release fee in South Africa', 'fake_loan_aid',
     'Messages announce an approved grant and request an activation or release fee. No genuine grant requires payment to be released.',
     'ZA', 'Gauteng', now() - interval '2 days'),
    ('Fake remote job offers targeting job seekers', 'fake_job',
     'Scammers posing as well-known employers are requesting "registration fees" for non-existent remote jobs.',
     null, null, now() - interval '3 days')
on conflict do nothing;

-- Seed: numbers/reports across **every** supported market, so Lookup, the
-- country hotspot map and the country-scoped views all have data in a fresh
-- project. This mirrors `InMemoryStore._seed()` in
-- backend/app/services/store.py report-for-report, so the demo tells the same
-- story whether the backend is running on Supabase or the in-memory store.
--
-- `numbers` is a denormalized cache over `reports`: the counts below are the
-- aggregate of the report rows that follow, and `is_publicly_flagged` is true
-- exactly where report_count >= NUMBER_PUBLIC_FLAG_THRESHOLD (default 3).
-- Report volume varies by market on purpose — see the docstring in store.py.
insert into public.numbers (msisdn, country, report_count, categories, countries, last_reported_at, is_publicly_flagged) values
    -- Zimbabwe
    ('+263771234567', 'ZW', 3, '{"mobile_money_reversal": 3}'::jsonb, '{"ZW": 3}'::jsonb, now() - interval '2 hours', true),
    ('+263782345678', 'ZW', 1, '{"fake_job": 1}'::jsonb, '{"ZW": 1}'::jsonb, now() - interval '10 hours', false),
    ('+263714567890', 'ZW', 1, '{"faith_seed": 1}'::jsonb, '{"ZW": 1}'::jsonb, now() - interval '20 hours', false),
    ('+263733445566', 'ZW', 1, '{"otp_phishing": 1}'::jsonb, '{"ZW": 1}'::jsonb, now() - interval '26 hours', false),
    -- The fixture the incoming-call screening flow is demoed against. Three
    -- distinct categories puts it at "high" risk on diversity, and four
    -- reports clears the public-flag threshold — the call banner only warns on
    -- a publicly flagged number.
    ('+263710423555', 'ZW', 4, '{"mobile_money_reversal": 2, "otp_phishing": 1, "impersonation": 1}'::jsonb, '{"ZW": 4}'::jsonb, now() - interval '3 hours', true),
    -- Kenya
    ('+254712345678', 'KE', 3, '{"mobile_money_reversal": 3}'::jsonb, '{"KE": 3}'::jsonb, now() - interval '4 hours', true),
    ('+254733221100', 'KE', 1, '{"sim_swap": 1}'::jsonb, '{"KE": 1}'::jsonb, now() - interval '2 days', false),
    ('+254110998877', 'KE', 1, '{"fake_investment": 1}'::jsonb, '{"KE": 1}'::jsonb, now() - interval '21 hours', false),
    -- Nigeria. The first number is the cross-border case: reported three times
    -- from Nigeria and once from Ghana, so `countries` spans two markets and
    -- `country` is the market it harms most rather than the one it dials from.
    ('+2348031234567', 'NG', 4, '{"otp_phishing": 2, "impersonation": 1, "fake_investment": 1}'::jsonb, '{"NG": 3, "GH": 1}'::jsonb, now() - interval '3 hours', true),
    ('+2349021112233', 'NG', 1, '{"fake_loan_aid": 1}'::jsonb, '{"NG": 1}'::jsonb, now() - interval '33 hours', false),
    -- South Africa
    ('+27821234567', 'ZA', 3, '{"fake_loan_aid": 3}'::jsonb, '{"ZA": 3}'::jsonb, now() - interval '14 hours', true),
    ('+27761122334', 'ZA', 1, '{"sim_swap": 1}'::jsonb, '{"ZA": 1}'::jsonb, now() - interval '29 hours', false),
    -- Uganda
    ('+256772345678', 'UG', 1, '{"fake_job": 1}'::jsonb, '{"UG": 1}'::jsonb, now() - interval '30 hours', false),
    ('+256701234567', 'UG', 1, '{"mobile_money_reversal": 1}'::jsonb, '{"UG": 1}'::jsonb, now() - interval '35 hours', false),
    ('+256752233445', 'UG', 1, '{"otp_phishing": 1}'::jsonb, '{"UG": 1}'::jsonb, now() - interval '44 hours', false),
    -- Ghana
    ('+233241234567', 'GH', 2, '{"mobile_money_reversal": 2}'::jsonb, '{"GH": 2}'::jsonb, now() - interval '18 hours', false),
    ('+233501122334', 'GH', 1, '{"impersonation": 1}'::jsonb, '{"GH": 1}'::jsonb, now() - interval '27 hours', false),
    -- Tanzania
    ('+255754112233', 'TZ', 2, '{"mobile_money_reversal": 2}'::jsonb, '{"TZ": 2}'::jsonb, now() - interval '7 hours', false),
    ('+255682233445', 'TZ', 1, '{"fake_investment": 1}'::jsonb, '{"TZ": 1}'::jsonb, now() - interval '31 hours', false),
    ('+255715566778', 'TZ', 1, '{"sim_swap": 1}'::jsonb, '{"TZ": 1}'::jsonb, now() - interval '2 days', false)
on conflict (msisdn) do nothing;

insert into public.reports (msisdn, country, category, region, message_excerpt, reporter_trust, created_at) values
    -- Zimbabwe — the wrong-deposit pattern, repeated from one number
    ('+263771234567', 'ZW', 'mobile_money_reversal', 'Harare', 'Wrong deposit, please reverse to [number]', 1.4, now() - interval '1 day'),
    ('+263771234567', 'ZW', 'mobile_money_reversal', 'Harare', 'Confirmed. You have received [redacted]...', 1.0, now() - interval '6 hours'),
    ('+263771234567', 'ZW', 'mobile_money_reversal', 'Harare', 'I sent money to your number by accident...', 1.0, now() - interval '2 hours'),
    ('+263782345678', 'ZW', 'fake_job', 'Bulawayo', 'Congratulations! Shortlisted for remote job...', 1.2, now() - interval '10 hours'),
    ('+263714567890', 'ZW', 'faith_seed', 'Manicaland', 'Sow a seed today...', 1.1, now() - interval '20 hours'),
    ('+263733445566', 'ZW', 'otp_phishing', 'Midlands', 'EcoCash security check: confirm the code sent to you', 1.2, now() - interval '26 hours'),
    ('+263710423555', 'ZW', 'mobile_money_reversal', 'Harare', 'Wrong deposit, reverse to [number] urgently', 1.4, now() - interval '3 hours'),
    ('+263710423555', 'ZW', 'otp_phishing', 'Harare', 'EcoCash agent here, read me the code to reverse it', 1.3, now() - interval '11 hours'),
    ('+263710423555', 'ZW', 'impersonation', 'Bulawayo', 'Calling from the EcoCash fraud desk', 1.2, now() - interval '19 hours'),
    ('+263710423555', 'ZW', 'mobile_money_reversal', 'Harare', 'I will send police if you don''t reverse it', 1.0, now() - interval '1 day'),
    -- Kenya — M-PESA reversal spreading beyond Nairobi, plus a SIM swap wave
    ('+254712345678', 'KE', 'mobile_money_reversal', 'Nairobi', 'I sent you money by mistake, please send it back', 1.3, now() - interval '4 hours'),
    ('+254712345678', 'KE', 'mobile_money_reversal', 'Nairobi', 'Please return the M-PESA sent in error', 1.0, now() - interval '9 hours'),
    ('+254712345678', 'KE', 'mobile_money_reversal', 'Coast', 'Reverse the M-PESA to [number], wrong recipient', 1.1, now() - interval '16 hours'),
    ('+254733221100', 'KE', 'sim_swap', 'Central', 'Your line will be deactivated, confirm your ID to re-register', 1.0, now() - interval '2 days'),
    ('+254110998877', 'KE', 'fake_investment', 'Nairobi', 'Guaranteed 40% weekly returns, slots closing', 0.9, now() - interval '21 hours'),
    -- Nigeria — BVN phishing from a number that is also working Ghana
    ('+2348031234567', 'NG', 'otp_phishing', 'Lagos', 'Your BVN is due for revalidation, click [link]', 1.5, now() - interval '3 hours'),
    ('+2348031234567', 'NG', 'impersonation', 'Lagos', 'This is your bank''s fraud desk, call [number]', 1.2, now() - interval '8 hours'),
    ('+2348031234567', 'NG', 'fake_investment', 'FCT Abuja', 'Double your capital in 24hrs, last slots', 0.9, now() - interval '1 day'),
    ('+2349021112233', 'NG', 'fake_loan_aid', 'South West', 'Loan approved, pay [redacted] insurance fee', 1.0, now() - interval '33 hours'),
    -- South Africa — grant scams, the dominant local pattern, plus SIM swap
    ('+27821234567', 'ZA', 'fake_loan_aid', 'Gauteng', 'Your grant application is approved, pay [redacted] to release', 1.1, now() - interval '14 hours'),
    ('+27821234567', 'ZA', 'fake_loan_aid', 'KwaZulu-Natal', 'Grant pending, activation fee required', 1.0, now() - interval '2 days'),
    ('+27821234567', 'ZA', 'fake_loan_aid', 'Eastern Cape', 'Final notice: clearance fee to release grant', 1.0, now() - interval '40 hours'),
    ('+27761122334', 'ZA', 'sim_swap', 'Western Cape', 'SIM upgrade required, reply with the code to keep your line', 1.1, now() - interval '29 hours'),
    -- Uganda — MoMo reversal and recruitment fees
    ('+256772345678', 'UG', 'fake_job', 'Central', 'Pay processing fee to confirm your placement', 1.0, now() - interval '30 hours'),
    ('+256701234567', 'UG', 'mobile_money_reversal', 'Western', 'MTN MoMo sent to you in error, please send back', 1.0, now() - interval '35 hours'),
    ('+256752233445', 'UG', 'otp_phishing', 'Eastern', 'Airtel Money verification: share the PIN sent to [number]', 1.1, now() - interval '44 hours'),
    -- Ghana — MoMo reversal, and the Nigerian number reported here too
    ('+233241234567', 'GH', 'mobile_money_reversal', 'Greater Accra', 'MoMo sent by mistake, kindly reverse', 1.0, now() - interval '18 hours'),
    ('+233241234567', 'GH', 'mobile_money_reversal', 'Ashanti', 'Please return the MoMo, it was the wrong number', 1.0, now() - interval '38 hours'),
    ('+233501122334', 'GH', 'impersonation', 'Greater Accra', 'MTN support here, your wallet is locked, call [number]', 1.2, now() - interval '27 hours'),
    ('+2348031234567', 'GH', 'otp_phishing', 'Greater Accra', 'Bank verification required, click [link] to confirm', 1.0, now() - interval '12 hours'),
    -- Tanzania — reversal script in Dar, spreading up the coast
    ('+255754112233', 'TZ', 'mobile_money_reversal', 'Dar es Salaam', 'M-Pesa sent to you by accident, please reverse to [number]', 1.2, now() - interval '7 hours'),
    ('+255754112233', 'TZ', 'mobile_money_reversal', 'Coastal', 'Wrong transfer, kindly send it back today', 1.0, now() - interval '23 hours'),
    ('+255682233445', 'TZ', 'fake_investment', 'Northern', 'Forex platform, capital doubled in 48hrs', 0.9, now() - interval '31 hours'),
    ('+255715566778', 'TZ', 'sim_swap', 'Lake', 'Line registration expiring, confirm your ID to avoid blocking', 1.0, now() - interval '2 days')
on conflict do nothing;

-- Note: sample_data/scam_corpus.jsonl and sample_data/transactions_sample.csv are loaded
-- by the backend's data-generation scripts / classifier at runtime, not via this SQL file.
-- To load the corpus into `scam_samples` for reference/analytics, use the Supabase CLI:
--   supabase db execute --file - <<< "$(python3 -c "..." )"
-- or a one-off script that reads the JSONL and INSERTs rows.
