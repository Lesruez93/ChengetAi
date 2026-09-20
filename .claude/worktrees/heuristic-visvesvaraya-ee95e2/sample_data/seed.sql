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
insert into public.feed_items (title, category, summary, country, region) values
    ('Wrong-deposit reversal scams surge across East and Southern Africa', 'mobile_money_reversal',
     'Reports from four markets describe the same script: a small or fake deposit notice, then pressure to "reverse" money to a different number. Check your real balance in the wallet app, not the SMS.',
     null, null),
    ('BVN revalidation phishing targeting Nigerian bank customers', 'otp_phishing',
     'SMS impersonating major banks asks customers to revalidate their BVN through a link within 24 hours. No Nigerian bank revalidates a BVN by SMS link.',
     'NG', 'Lagos'),
    ('SIM re-registration scams reported in Kenya', 'sim_swap',
     'Messages claiming your line will be deactivated unless you confirm your ID are a pretext for SIM swap. Confirm any re-registration requirement with your operator directly.',
     'KE', null),
    ('Grant approval scams asking for a release fee in South Africa', 'fake_loan_aid',
     'Messages announce an approved grant and request an activation or release fee. No genuine grant requires payment to be released.',
     'ZA', 'Gauteng'),
    ('Fake remote job offers targeting job seekers', 'fake_job',
     'Scammers posing as well-known employers are requesting "registration fees" for non-existent remote jobs.',
     null, null)
on conflict do nothing;

-- Seed: sample numbers/reports across several markets, so Lookup, the country
-- hotspot map and the country-scoped views all have data in a fresh project.
insert into public.numbers (msisdn, country, report_count, categories, countries, last_reported_at, is_publicly_flagged) values
    ('+263771234567', 'ZW', 2, '{"mobile_money_reversal": 2}'::jsonb, '{"ZW": 2}'::jsonb, now(), false),
    ('+263782345678', 'ZW', 1, '{"fake_job": 1}'::jsonb, '{"ZW": 1}'::jsonb, now(), false),
    ('+254712345678', 'KE', 2, '{"mobile_money_reversal": 2}'::jsonb, '{"KE": 2}'::jsonb, now(), false),
    ('+2348031234567', 'NG', 2, '{"otp_phishing": 1, "impersonation": 1}'::jsonb, '{"NG": 2}'::jsonb, now(), false),
    ('+27821234567', 'ZA', 1, '{"fake_loan_aid": 1}'::jsonb, '{"ZA": 1}'::jsonb, now(), false)
on conflict (msisdn) do nothing;

insert into public.reports (msisdn, country, category, region, message_excerpt, reporter_trust) values
    ('+263771234567', 'ZW', 'mobile_money_reversal', 'Harare', 'Wrong deposit, please reverse to [number]', 1.4),
    ('+263771234567', 'ZW', 'mobile_money_reversal', 'Harare', 'Confirmed. You have received [redacted]...', 1.0),
    ('+263782345678', 'ZW', 'fake_job', 'Bulawayo', 'Congratulations! Shortlisted for remote job...', 1.2),
    ('+254712345678', 'KE', 'mobile_money_reversal', 'Nairobi', 'I sent you money by mistake, please send it back', 1.3),
    ('+254712345678', 'KE', 'mobile_money_reversal', 'Nairobi', 'Please return the M-PESA sent in error', 1.0),
    ('+2348031234567', 'NG', 'otp_phishing', 'Lagos', 'Your BVN is due for revalidation, click [link]', 1.5),
    ('+2348031234567', 'NG', 'impersonation', 'Lagos', 'This is your bank''s fraud desk, call [number]', 1.2),
    ('+27821234567', 'ZA', 'fake_loan_aid', 'Gauteng', 'Your grant is approved, pay [redacted] to release', 1.1)
on conflict do nothing;

-- Note: sample_data/scam_corpus.jsonl and sample_data/transactions_sample.csv are loaded
-- by the backend's data-generation scripts / classifier at runtime, not via this SQL file.
-- To load the corpus into `scam_samples` for reference/analytics, use the Supabase CLI:
--   supabase db execute --file - <<< "$(python3 -c "..." )"
-- or a one-off script that reads the JSONL and INSERTs rows.
