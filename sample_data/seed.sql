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
-- ============================================================================
create table if not exists public.numbers (
    msisdn text primary key,
    report_count integer not null default 0,
    categories jsonb not null default '{}'::jsonb,
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
    category text not null,
    province text not null default 'Harare',
    message_excerpt text default '',
    reporter_id uuid references auth.users (id) on delete set null,
    reporter_trust numeric not null default 1.0,
    created_at timestamptz not null default now()
);

create index if not exists reports_msisdn_idx on public.reports (msisdn);
create index if not exists reports_created_at_idx on public.reports (created_at desc);
create index if not exists reports_category_idx on public.reports (category);

alter table public.reports enable row level security;

create policy "reports are publicly readable"
    on public.reports for select
    using (true);

create policy "authenticated users can create reports"
    on public.reports for insert
    to authenticated
    with check (auth.uid() = reporter_id);

-- ============================================================================
-- scam_samples: labeled corpus used to train/evaluate the baseline classifier
-- (loaded from sample_data/scam_corpus.jsonl; see docs/dataset_statement.md)
-- ============================================================================
create table if not exists public.scam_samples (
    id uuid primary key default gen_random_uuid(),
    text text not null,
    label text not null check (label in ('scam', 'legit')),
    category text not null default 'other',
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
    province text,
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
    scope text not null,              -- 'category' | 'province'
    key text not null,                -- e.g. 'ecocash_reversal' or 'Harare'
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
insert into public.feed_items (title, category, summary, province) values
    ('EcoCash ''wrong transfer'' scams surge in Harare', 'ecocash_reversal',
     'Multiple reports of scammers sending small deposits then asking victims to "reverse" money to a different number, keeping the original deposit.',
     'Harare'),
    ('Fake remote job offers targeting job seekers', 'fake_job',
     'Scammers posing as well-known employers are requesting "registration fees" for non-existent remote jobs.',
     null),
    ('Forex bureau impersonation scams in the CBD', 'fake_forex',
     'Reports of fake forex dealers asking victims to send USD first "for verification" before disappearing.',
     'Harare')
on conflict do nothing;

-- Seed: a couple of sample numbers/reports so Lookup has something to find in a fresh project
insert into public.numbers (msisdn, report_count, categories, last_reported_at, is_publicly_flagged) values
    ('0771234567', 2, '{"ecocash_reversal": 2}'::jsonb, now(), false),
    ('0782345678', 1, '{"fake_job": 1}'::jsonb, now(), false),
    -- demo "known scammer" number (+263 71 042 3555): 6 reports over 3 categories,
    -- which risk_level_for() in backend/app/services/reputation.py scores as high
    ('0710423555', 6, '{"ecocash_reversal": 3, "fake_job": 1, "fake_forex": 2}'::jsonb, now(), true)
on conflict (msisdn) do nothing;

insert into public.reports (msisdn, category, province, message_excerpt, reporter_trust) values
    ('0771234567', 'ecocash_reversal', 'Harare', 'Wrong deposit, please reverse...', 1.4),
    ('0771234567', 'ecocash_reversal', 'Harare', 'Confirmed. You have received $80...', 1.0),
    ('0782345678', 'fake_job', 'Bulawayo', 'Congratulations! Shortlisted for remote job...', 1.2),
    ('0710423555', 'ecocash_reversal', 'Harare', 'Good day, I sent $50 to your number by mistake...', 1.5),
    ('0710423555', 'ecocash_reversal', 'Harare', 'Please reverse to 0710423555, my child is in hospital', 1.3),
    ('0710423555', 'ecocash_reversal', 'Harare', 'Agent said reverse the money before 5pm...', 1.0),
    ('0710423555', 'fake_job', 'Bulawayo', 'Econet HR: pay $15 registration for your interview slot', 1.2),
    ('0710423555', 'fake_forex', 'Harare', 'Rate 1:14 today, send USD first for verification', 1.1),
    ('0710423555', 'fake_forex', 'Midlands', 'Cash out USD cash today, deposit ZWL first', 0.9)
on conflict do nothing;

-- Note: sample_data/scam_corpus.jsonl and sample_data/transactions_sample.csv are loaded
-- by the backend's data-generation scripts / classifier at runtime, not via this SQL file.
-- To load the corpus into `scam_samples` for reference/analytics, use the Supabase CLI:
--   supabase db execute --file - <<< "$(python3 -c "..." )"
-- or a one-off script that reads the JSONL and INSERTs rows.
