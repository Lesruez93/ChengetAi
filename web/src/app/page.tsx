import Image from "next/image";
import Link from "next/link";

import { BackendOfflineNotice } from "@/components/BackendOfflineNotice";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { StatCard } from "@/components/StatCard";
import { ApiError, getTrendingFeed } from "@/lib/api";
import type { TrendingFeedResponse } from "@/lib/types";

export const dynamic = "force-dynamic"; // live stats section reads the backend on every request

const PROBLEMS = [
  {
    title: "The same scam, seven countries",
    body: "“Reverse this wrong deposit” runs identically on EcoCash, M-PESA, MTN MoMo, Airtel Money and OPay. The script crosses borders faster than any single country’s warnings do.",
  },
  {
    title: "Reporting goes nowhere",
    body: "Victims are told to “report it”, but not to whom, in what order, or how fast. By the time someone finds the right desk, the transfer is no longer recoverable.",
  },
  {
    title: "Reporting costs safety",
    body: "The people most exposed to retaliation are the least able to report under their own name. Any system that demands an identity first silences exactly those reports.",
  },
  {
    title: "No shared scam-number database",
    body: "Every victim starts from zero: there is no citizen-accessible way to check “has this number scammed someone else?” — least of all across a border.",
  },
];

const FEATURES = [
  {
    title: "Check Message",
    body: "Paste or share any SMS/WhatsApp message. An AI classifier verdicts it scam, suspicious, or safe — grounded in your market’s own wallets and currency — with highlighted risk phrases and a plain-language explanation.",
  },
  {
    title: "Get Help",
    body: "Every non-safe verdict arrives with a pathway, not just a label: what to do in the next five minutes, then the ordered escalation ladder for your country — wallet provider, regulator, police, support line.",
  },
  {
    title: "Report — anonymously if you need to",
    body: "Report a number without an account. Excerpts are redacted at intake, so third-party numbers, OTPs and ID numbers never reach the database. One hostile report can’t brand a number.",
  },
  {
    title: "Number Lookup & cross-border reach",
    body: "Search any number for a crowd-sourced reputation: report count, categories, risk level — and which countries it has been reported from, because a number working three markets is an operation, not a dispute.",
  },
  {
    title: "Trending Feed & Hotspot Maps",
    body: "A live “trending this week” ranking, a regional risk map inside your country, and a cross-country rollup — all computed with weighted rules over community reports, transparently not an AI model.",
  },
  {
    title: "Agent Fraud Sentinel",
    body: "SMEs and mobile-money agents upload a transaction log and get back flagged anomalies — rapid reversals, structuring, unusual hours — with human-readable reasons.",
  },
];

const GITHUB_REPO_URL = "https://github.com/Lesruez93/ChengetAi";
const APK_DOWNLOAD_URL =
  "https://github.com/Lesruez93/ChengetAi/releases/download/v0.1.0-mvp/app-release.apk";

const MOBILE_SCREENSHOTS = [
  { src: "/screenshots/mobile-number-lookup.png", alt: "Number Lookup screen", label: "Number Lookup" },
];

const ADMIN_SCREENSHOTS = [
  { src: "/screenshots/admin-overview.png", alt: "Admin dashboard overview", label: "Overview" },
  { src: "/screenshots/admin-reports.png", alt: "Admin reports moderation queue", label: "Reports moderation" },
  { src: "/screenshots/admin-numbers.png", alt: "Admin flagged-number review", label: "Number reputation" },
  { src: "/screenshots/admin-sentinel.png", alt: "Admin Sentinel job history", label: "Sentinel job history" },
  { src: "/screenshots/admin-login.png", alt: "Admin login screen", label: "Login" },
];

async function loadLiveStats(): Promise<{ data: TrendingFeedResponse | null; error: string | null }> {
  try {
    const data = await getTrendingFeed(7);
    return { data, error: null };
  } catch (err) {
    return { data: null, error: err instanceof ApiError ? err.message : String(err) };
  }
}

export default async function LandingPage() {
  const { data: trending, error } = await loadLiveStats();

  return (
    <>
      <SiteHeader />
      <main className="flex-1">
        {/* Hero */}
        <section className="relative overflow-hidden bg-surface-tint">
          <Image
            src="/logo-mark.png"
            alt=""
            width={480}
            height={480}
            priority
            className="pointer-events-none absolute top-1/2 right-[-60px] hidden w-[380px] -translate-y-1/2 opacity-90 md:block lg:right-[-20px] lg:w-[460px]"
          />
          <div className="relative mx-auto max-w-6xl px-6 py-20 md:py-28">
            <h1 className="max-w-3xl text-4xl font-semibold tracking-tight text-foreground md:text-5xl">
              Chengeta — check it, report it safely, and know who to call next.
            </h1>
            <p className="mt-5 max-w-2xl text-lg text-neutral">
              ChengetAI helps people across African mobile-money markets verify a suspicious
              message, report the number behind it without putting themselves at risk, and reach
              the right help fast. Covering Zimbabwe, Kenya, Nigeria, Uganda, South Africa, Ghana
              and Tanzania — one shared scam database, grounded in each market&apos;s own wallets
              and currency.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <a
                href="#features"
                className="rounded-full bg-brand-primary px-6 py-3 text-sm font-medium text-white transition hover:bg-brand-primary/90"
              >
                Explore the product
              </a>
              <Link
                href="/admin"
                className="rounded-full border border-black/10 px-6 py-3 text-sm font-medium text-foreground transition hover:border-brand-primary hover:text-brand-primary dark:border-white/15"
              >
                Open admin dashboard
              </Link>
            </div>
          </div>
        </section>

        {/* Problem */}
        <section id="problem" className="mx-auto max-w-6xl px-6 py-20">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-brand-secondary">
            The problem
          </h2>
          <p className="mt-2 max-w-2xl text-2xl font-semibold text-foreground">
            Mobile money is the default payment rail across much of Africa — and its
            primary fraud surface.
          </p>
          <p className="mt-4 max-w-3xl text-neutral">
            Losses hit the poorest hardest and erode trust in digital finance exactly where
            financial inclusion is deepening fastest. Generic spam filters, trained on Western scam
            corpora, miss every local wallet&apos;s terminology and the scripts built around it.
            And detection alone is not protection: a verdict that does not tell you who to call,
            in what order, leaves the user exactly where it found them.
          </p>
          <div className="mt-10 grid gap-5 sm:grid-cols-2">
            {PROBLEMS.map((p) => (
              <div key={p.title} className="rounded-2xl border border-black/5 p-6 dark:border-white/10">
                <h3 className="font-semibold text-foreground">{p.title}</h3>
                <p className="mt-2 text-sm text-neutral">{p.body}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Features */}
        <section id="features" className="bg-surface-tint py-20">
          <div className="mx-auto max-w-6xl px-6">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-brand-secondary">
              Detect, report safely, reach help
            </h2>
            <p className="mt-2 max-w-2xl text-2xl font-semibold text-foreground">
              Built for the people who actually handle mobile money every day.
            </p>
            <div className="mt-10 grid gap-6 md:grid-cols-2">
              {FEATURES.map((f) => (
                <div key={f.title} className="rounded-2xl bg-white p-6 shadow-sm dark:bg-white/5">
                  <h3 className="font-semibold text-brand-primary">{f.title}</h3>
                  <p className="mt-2 text-sm text-neutral">{f.body}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Live stats */}
        <section className="mx-auto max-w-6xl px-6 py-20">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-brand-secondary">
            Live from the ChengetAI API
          </h2>
          <p className="mt-2 max-w-2xl text-2xl font-semibold text-foreground">
            This week&apos;s trending scams, computed from real community reports.
          </p>
          {error || !trending ? (
            <div className="mt-8">
              <BackendOfflineNotice detail={error ?? undefined} />
            </div>
          ) : (
            <>
              <div className="mt-8 grid gap-5 sm:grid-cols-3">
                <StatCard
                  label="Trending categories (7d)"
                  value={trending.trending_categories.length}
                  hint={trending.trending_categories[0]?.label ?? "no data yet"}
                />
                <StatCard
                  label="Markets with activity"
                  value={trending.country_hotspots.filter((h) => h.report_count > 0).length}
                  hint={`out of ${trending.country_hotspots.length} covered`}
                />
                <StatCard
                  label="Total reports this week"
                  value={trending.trending_categories.reduce((sum, c) => sum + c.report_count, 0)}
                  hint="community-submitted"
                />
              </div>
              <p className="mt-4 text-xs text-neutral">{trending.method_note}</p>
            </>
          )}
        </section>

        {/* AI justification */}
        <section id="ai" className="bg-surface-tint py-20">
          <div className="mx-auto max-w-6xl px-6">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-brand-secondary">
              Where AI is used — and where it deliberately isn&apos;t
            </h2>
            <div className="mt-8 grid gap-6 md:grid-cols-2">
              <div className="rounded-2xl bg-white p-6 shadow-sm dark:bg-white/5">
                <h3 className="font-semibold text-foreground">AI is used for</h3>
                <ul className="mt-3 space-y-2 text-sm text-neutral">
                  <li>
                    <span className="font-medium text-foreground">Message classification</span> — a
                    TF-IDF/logistic-regression baseline and a pluggable Anthropic LLM strategy, because
                    scam text is adversarial and constantly mutating.
                  </li>
                  <li>
                    <span className="font-medium text-foreground">Agent Fraud Sentinel</span> — an
                    IsolationForest over transaction features, because agent fraud patterns are
                    unlabeled and drift over time.
                  </li>
                </ul>
              </div>
              <div className="rounded-2xl bg-white p-6 shadow-sm dark:bg-white/5">
                <h3 className="font-semibold text-foreground">AI is NOT used for</h3>
                <ul className="mt-3 space-y-2 text-sm text-neutral">
                  <li>
                    <span className="font-medium text-foreground">Number reputation</span> — plain
                    CRUD with rate limiting, duplicate collapse, and a public-flag threshold.
                  </li>
                  <li>
                    <span className="font-medium text-foreground">Trending feed & hotspot maps</span> —
                    weighted-rules aggregation (report count × recency × trust) over the same
                    reports table, not a model.
                  </li>
                  <li>
                    <span className="font-medium text-foreground">Support pathways</span> — a
                    curated, human-maintained registry per country. Who to call after a scam is
                    too consequential to generate, so it never is.
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </section>

        {/* Demo & downloads */}
        <section id="demo" className="mx-auto max-w-6xl px-6 py-20">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-brand-secondary">
            See it in action
          </h2>
          <p className="mt-2 max-w-2xl text-2xl font-semibold text-foreground">
            Real screens from a running backend — not mockups.
          </p>
          <p className="mt-4 max-w-3xl text-neutral">
            Every screenshot below was captured against the live ChengetAI API with real
            seeded/uploaded data. Grab the Android build or the full source below.
          </p>

          <div className="mt-8 flex flex-wrap gap-3">
            <a
              href={APK_DOWNLOAD_URL}
              className="rounded-full bg-brand-primary px-6 py-3 text-sm font-medium text-white transition hover:bg-brand-primary/90"
            >
              Download Android APK
            </a>
            <a
              href={GITHUB_REPO_URL}
              target="_blank"
              rel="noreferrer"
              className="rounded-full border border-black/10 px-6 py-3 text-sm font-medium text-foreground transition hover:border-brand-primary hover:text-brand-primary dark:border-white/15"
            >
              View source on GitHub
            </a>
          </div>
          <p className="mt-3 text-xs text-neutral">
            Pilot/demo build, signed with the default debug keystore — enable “install from
            unknown sources” on your Android device to install.
          </p>

          <h3 className="mt-14 text-lg font-semibold text-foreground">Mobile app</h3>
          <div className="mt-4 flex flex-wrap gap-6">
            {MOBILE_SCREENSHOTS.map((shot) => (
              <a
                key={shot.src}
                href={shot.src}
                target="_blank"
                rel="noreferrer"
                className="group block w-[180px] shrink-0 overflow-hidden rounded-2xl border border-black/5 shadow-sm transition hover:border-brand-primary dark:border-white/10"
              >
                <Image
                  src={shot.src}
                  alt={shot.alt}
                  width={1080}
                  height={2412}
                  className="w-full transition group-hover:opacity-90"
                />
                <p className="border-t border-black/5 bg-white px-3 py-2 text-xs font-medium text-neutral dark:border-white/10 dark:bg-white/5">
                  {shot.label}
                </p>
              </a>
            ))}
          </div>

          <h3 className="mt-14 text-lg font-semibold text-foreground">Admin dashboard</h3>
          <div className="mt-4 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {ADMIN_SCREENSHOTS.map((shot) => (
              <a
                key={shot.src}
                href={shot.src}
                target="_blank"
                rel="noreferrer"
                className="group block overflow-hidden rounded-2xl border border-black/5 shadow-sm transition hover:border-brand-primary dark:border-white/10"
              >
                <Image
                  src={shot.src}
                  alt={shot.alt}
                  width={1440}
                  height={1000}
                  className="w-full transition group-hover:opacity-90"
                />
                <p className="border-t border-black/5 bg-white px-3 py-2 text-xs font-medium text-neutral dark:border-white/10 dark:bg-white/5">
                  {shot.label}
                </p>
              </a>
            ))}
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
