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

// The Safety, Reporting & Protection spine. Detection is only the first beat;
// the page leads with all three because a tool that stops at a verdict leaves
// the user exactly where it found them.
const FLOW = [
  {
    step: "01",
    title: "Get warned, or check it yourself",
    body: "Incoming calls, texts and WhatsApp calls are screened as they arrive, and you are warned when the number is a known scammer. Anything the phone can’t hand over — a WhatsApp message, an email, a Facebook or Messenger text — you paste in, and get a verdict with the exact phrases that triggered it.",
  },
  {
    step: "02",
    title: "Report it safely",
    body: "Anonymously, with no account. Your report still counts toward the number’s reputation. Phone numbers, one-time codes and ID numbers are stripped from the message before it is ever stored.",
  },
  {
    step: "03",
    title: "Reach help",
    body: "Every scam verdict comes with what to do in the next five minutes, then the ordered list of who to contact in your country — wallet provider first, because it is the only one that can still stop the transfer.",
  },
];

// Call Guard: the three channels Android actually lets a third-party app see,
// in descending order of reliability. This copy tracks docs/architecture.md
// deliberately — the site must not promise more than the Kotlin screening
// pipeline delivers, least of all on the WhatsApp path.
const SCREENED_CHANNELS = [
  {
    channel: "Incoming calls",
    signal: "Every call, with the number",
    body: "The caller’s number is checked against the flagged-number database while the phone is still ringing. If it belongs to a known scammer, a warning tells you the risk level, how many people reported it and what for — before you answer. ChengetAI never rejects the call: a wrongly blocked call is a harm you would never see, so answering stays your decision.",
  },
  {
    channel: "Incoming SMS",
    signal: "Two independent signals",
    body: "Every text is checked twice — who sent it, and what it says. A number bought yesterday has no reputation yet but runs the same script; a SIM-swapped line keeps its clean history. Either signal alone raises the warning. Bank and telco shortcodes can’t be looked up as numbers, so the text itself is still classified, because shortcode spoofing is one of the most common phishing routes in these markets.",
  },
  {
    channel: "WhatsApp calls",
    signal: "Best-effort — limits stated",
    body: "WhatsApp calls never reach Android’s call screening, so ChengetAI reads WhatsApp’s own incoming-call notification instead. That yields a number only for callers who aren’t in your contacts, and a WhatsApp update can end it silently — so every screening outcome is recorded, including the ones that found nothing, and the app shows you when a channel has gone quiet.",
  },
];

const FEATURES = [
  {
    title: "Call Guard — incoming calls, SMS and WhatsApp calls",
    body: "Screens calls, texts and WhatsApp calls as they arrive and warns you when the sender is a known, community-flagged scammer — no need to suspect anything first. Each channel is opt-in, and the app logs every screened event so you can see it is still working.",
  },
  {
    title: "Check Message — paste from anywhere",
    body: "Copy any suspicious text — an SMS, a WhatsApp message, an email, a Facebook or Messenger message — paste it in, and an AI classifier verdicts it scam, suspicious or safe, grounded in your market’s own wallets and currency, with the risk phrases highlighted and a plain-language reason.",
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
  {
    src: "/screenshots/mobile-check-message.png",
    alt: "Check Message verdict screen",
    label: "Check Message",
    caption: "A pasted message scored Likely Scam at 75% confidence, with the flagged phrase and next steps shown inline.",
  },
  {
    src: "/screenshots/mobile-get-help.png",
    alt: "Get Help screen",
    label: "Get Help",
    caption: "The ordered escalation ladder for Kenya: wallet provider first, then regulators — ranked by how fast each stops the loss.",
  },
  {
    src: "/screenshots/mobile-call-guard-setup.png",
    alt: "Call Guard setup screen",
    label: "Call Guard",
    caption: "Call Guard on, 3 of 3 channels active — calls, SMS and warning notifications are each opt-in per channel.",
  },
  {
    src: "/screenshots/mobile-call-guard-events.png",
    alt: "Call Guard screened events screen",
    label: "Screened events",
    caption: "Every screened call and text, including a HIGH risk WhatsApp sender flagged from 4 corroborating reports.",
  },
  {
    src: "/screenshots/mobile-scam-alerts.png",
    alt: "Scam Alerts screen",
    label: "Scam Alerts",
    caption: "Trending scam patterns across markets — wrong-deposit reversals and SIM re-registration scripts reported within the last day.",
  },
  {
    src: "/screenshots/mobile-number-lookup.png",
    alt: "Number Lookup screen",
    label: "Number Lookup",
    caption: "Look up a number's report history before you call back, reply, or send money.",
  },
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
  // The covered-markets list comes from the live country registry rather than a
  // hardcoded array, so the page can never claim a market the backend has
  // dropped — and picks up a new one the moment it is added.
  const markets = trending?.country_hotspots ?? [];

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
              Chengeta — know who&apos;s calling, check any message, and know who to call next.
            </h1>
            <p className="mt-5 max-w-2xl text-lg text-neutral">
              ChengetAI screens your{" "}
              <strong className="font-semibold text-foreground">
                incoming calls, SMS and WhatsApp calls
              </strong>{" "}
              as they arrive and warns you when the number belongs to a known, community-flagged
              scammer — before you answer or reply. Anything
              your phone can&apos;t hand over, you paste in: a WhatsApp message, an email, a
              Facebook or Messenger text. Then report the number behind it without putting yourself
              at risk, and reach the right help fast.
            </p>
            <p className="mt-4 max-w-2xl text-lg text-neutral">
              Covering Zimbabwe, Kenya, Nigeria, Uganda, South Africa, Ghana and Tanzania — one
              shared scam database, grounded in each market&apos;s own wallets and currency.
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

        {/* How it works — the three-beat flow */}
        <section id="flow" className="bg-surface-tint py-20">
          <div className="mx-auto max-w-6xl px-6">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-brand-secondary">
              How it works
            </h2>
            <p className="mt-2 max-w-2xl text-2xl font-semibold text-foreground">
              Detect, report safely, reach help — in that order.
            </p>
            <p className="mt-4 max-w-3xl text-neutral">
              Most scam tools stop at the first step. A verdict that doesn&apos;t tell you who to
              call, in what order, and how fast is only half an answer.
            </p>
            <ol className="mt-10 grid gap-6 md:grid-cols-3">
              {FLOW.map((f) => (
                <li
                  key={f.step}
                  className="rounded-2xl bg-white p-6 shadow-sm dark:bg-white/5"
                >
                  <span className="text-sm font-semibold text-brand-secondary">{f.step}</span>
                  <h3 className="mt-2 text-lg font-semibold text-brand-primary">{f.title}</h3>
                  <p className="mt-2 text-sm text-neutral">{f.body}</p>
                </li>
              ))}
            </ol>
          </div>
        </section>

        {/* Incoming screening. Given its own section rather than one feature
            card because it is the only part of the product that protects
            someone who has no reason to be suspicious yet. */}
        <section id="protection" className="mx-auto max-w-6xl px-6 py-20">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-brand-secondary">
            Live protection — Call Guard
          </h2>
          <p className="mt-2 max-w-3xl text-2xl font-semibold text-foreground">
            ChengetAI detects known scammers on incoming calls, SMS and WhatsApp calls — and warns
            you before you answer.
          </p>
          <p className="mt-4 max-w-3xl text-neutral">
            Looking a number up or checking a message both require you to already suspect something.
            Call Guard is the inverse: it screens calls and texts against the flagged-number
            database <em>as they arrive</em>, for the moment when nothing looks wrong yet. Warning
            only fires on numbers the community has flagged past a threshold — one hostile report
            can never brand a number.
          </p>
          <div className="mt-10 grid gap-6 md:grid-cols-3">
            {SCREENED_CHANNELS.map((c) => (
              <div
                key={c.channel}
                className="rounded-2xl border border-black/5 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-white/5"
              >
                <h3 className="font-semibold text-brand-primary">{c.channel}</h3>
                <p className="mt-1 text-xs font-medium uppercase tracking-wide text-brand-secondary">
                  {c.signal}
                </p>
                <p className="mt-3 text-sm text-neutral">{c.body}</p>
              </div>
            ))}
          </div>

          {/* The paste flow, stated next to the automatic channels precisely so
              nobody assumes ChengetAI silently reads their chats or inbox. */}
          <div className="mt-6 rounded-2xl border border-brand-primary/20 bg-surface-tint p-6 md:p-8">
            <h3 className="text-lg font-semibold text-foreground">
              WhatsApp messages, email, Facebook, Messenger — paste them in
            </h3>
            <p className="mt-3 max-w-3xl text-sm text-neutral">
              No app can silently read your WhatsApp chats, your inbox or your Facebook messages,
              and ChengetAI does not pretend to. It gives you the other half instead: copy any
              suspicious text — a WhatsApp forward, an email, a Facebook or Messenger message, a
              Telegram text — paste it into Check Message, and get a verdict in seconds with the
              exact phrases that triggered it and what to do next. Same classifier and same local
              grounding as the automatic SMS path, on text from any source.
            </p>
          </div>

          <p className="mt-6 max-w-3xl text-sm text-neutral">
            Call Guard is Android-only, and each channel is separately opt-in — you grant call
            screening, SMS and WhatsApp access one at a time, and can run any one of them alone.
            iOS forbids a third-party app from seeing an incoming caller&apos;s number or reading
            SMS at all, which is a platform limit rather than a scope choice. The paste flow works
            everywhere.
          </p>
        </section>

        {/* Market coverage — driven by the live registry, not a hardcoded list */}
        <section id="coverage" className="mx-auto max-w-6xl px-6 py-20">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-brand-secondary">
            Where it works
          </h2>
          <p className="mt-2 max-w-2xl text-2xl font-semibold text-foreground">
            One shared scam database across {markets.length || "seven"} markets.
          </p>
          <p className="mt-4 max-w-3xl text-neutral">
            A number reported in Lagos is visible to someone in Accra. Scam scripts already cross
            borders faster than any single country&apos;s warnings do — this is the one thing that
            gets better, not worse, as the product spans markets.
          </p>
          {markets.length > 0 ? (
            <ul className="mt-10 flex flex-wrap gap-3">
              {markets.map((m) => (
                <li
                  key={m.country}
                  className="rounded-full border border-black/5 bg-white px-4 py-2 text-sm font-medium text-foreground shadow-sm dark:border-white/10 dark:bg-white/5"
                >
                  {m.country_name}
                  <span className="ml-2 text-xs font-normal text-neutral">{m.country}</span>
                </li>
              ))}
            </ul>
          ) : null}
          <p className="mt-6 max-w-3xl text-sm text-neutral">
            Adding a market is a data change in two files — no new model, no client release. What
            doesn&apos;t come for free is the part that isn&apos;t software: verifying each
            country&apos;s support-desk contacts, which is a prerequisite before piloting there.
          </p>
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
            This week&apos;s trending scams, computed live from community reports.
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
              <p className="mt-4 text-xs text-neutral">
                {trending.method_note} This deployment runs on seeded demonstration data, not real
                user reports — see the dataset statement in the repository.
              </p>
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
            The dashboard screenshots below were captured against a running ChengetAI backend with
            seeded data — not mockups. Grab the Android build or the full source below.
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
          <p className="mt-2 max-w-3xl text-sm text-neutral">
            Check Message, Get Help, Call Guard and Scam Alerts below are from the current build. The
            Number Lookup capture is older and does not yet show the country switcher or cross-border
            reach on a number — a refreshed capture follows the next Android build.
          </p>
          <div className="mt-4 flex flex-wrap gap-6">
            {MOBILE_SCREENSHOTS.map((shot) => (
              <a
                key={shot.src}
                href={shot.src}
                target="_blank"
                rel="noreferrer"
                className="group block w-[208px] shrink-0 overflow-hidden rounded-2xl border border-black/5 shadow-sm transition hover:border-brand-primary dark:border-white/10"
              >
                <Image
                  src={shot.src}
                  alt={shot.alt}
                  width={1080}
                  height={2412}
                  className="w-full transition group-hover:opacity-90"
                />
                <div className="border-t border-black/5 bg-white px-3 py-2.5 dark:border-white/10 dark:bg-white/5">
                  <p className="text-xs font-medium text-foreground">{shot.label}</p>
                  <p className="mt-1 text-[11px] leading-snug text-neutral">{shot.caption}</p>
                </div>
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
