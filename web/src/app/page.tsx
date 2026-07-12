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
    title: "EcoCash & OneMoney reversal scams",
    body: "A fake or real small deposit lands, then a message pressures the victim to “reverse” a larger amount to a different number.",
  },
  {
    title: "Fake job & forex offers",
    body: "Unsolicited remote-job or forex deals ask for an upfront “registration” or “verification” fee before disappearing.",
  },
  {
    title: "Fake NGO, loan & prophet scams",
    body: "Emergency-aid, loan, and “sow a seed” religious scams exploit trust and urgency, in code-switched Shona/English text generic filters miss.",
  },
  {
    title: "No shared scam-number database",
    body: "Every victim starts from zero: there is no citizen-accessible way to check “has this number scammed someone else?” before engaging.",
  },
];

const FEATURES = [
  {
    title: "Check Message",
    body: "Paste or share any SMS/WhatsApp message. An AI classifier verdicts it scam, suspicious, or safe, with highlighted risk phrases and a plain-language explanation.",
  },
  {
    title: "Number Lookup",
    body: "Search a phone number for a Truecaller-style, crowd-sourced reputation: report count, scam categories, and risk level, with abuse controls so one hostile report can’t brand a number.",
  },
  {
    title: "Trending Feed & Hotspot Map",
    body: "A live “trending this week” ranking and a province-level risk map, computed with weighted rules over community reports — transparently not an AI model.",
  },
  {
    title: "Agent Fraud Sentinel",
    body: "SMEs and mobile-money agents upload a transaction log and get back flagged anomalies — rapid reversals, structuring, unusual hours — with human-readable reasons.",
  },
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
            <span className="inline-flex items-center rounded-full bg-brand-primary/10 px-3 py-1 text-xs font-medium text-brand-primary">
              AI4I 2026 · POTRAZ · Track 3: Development
            </span>
            <h1 className="mt-6 max-w-3xl text-4xl font-semibold tracking-tight text-foreground md:text-5xl">
              Chengeta — protect your money from Zimbabwe&apos;s fastest-growing scams.
            </h1>
            <p className="mt-5 max-w-2xl text-lg text-neutral">
              ChengetAI is an AI protection app for ordinary Zimbabweans, SMEs, and mobile-money
              agents: a scam-message detector, phone number reputation lookup, a trending-scams
              hotspot map, and fraud detection for agent tills — all tuned to local scam patterns.
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
            Mobile money is Zimbabwe&apos;s default payment rail — and its primary fraud
            surface.
          </p>
          <p className="mt-4 max-w-3xl text-neutral">
            Losses hit the poorest hardest and erode trust in digital finance just as the country
            tries to deepen financial inclusion. Generic spam filters, trained on English-language,
            Western scam corpora, miss Shona-English code-switched text and EcoCash/OneMoney
            terminology entirely.
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
              Four capabilities, one app
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
                  hint={trending.trending_categories[0]?.category.replace(/_/g, " ") ?? "no data yet"}
                />
                <StatCard
                  label="Red hotspot provinces"
                  value={trending.hotspots.filter((h) => h.level === "red").length}
                  hint="out of 10 provinces"
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
                    scam text is adversarial, code-switched, and constantly mutating.
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
                    <span className="font-medium text-foreground">Trending feed & hotspot map</span> —
                    weighted-rules aggregation (report count × recency × trust) over the same
                    reports table, not a model.
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
