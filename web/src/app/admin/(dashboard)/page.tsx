import { BackendOfflineNotice } from "@/components/BackendOfflineNotice";
import { Badge } from "@/components/Badge";
import { StatCard } from "@/components/StatCard";
import { ApiError, getFlaggedNumbers, getReports, getSentinelJobs, getTrendingFeed } from "@/lib/api";
import { severityForHotspotLevel } from "@/lib/risk-colors";

export const dynamic = "force-dynamic";

export default async function AdminOverviewPage() {
  let trending, numbers, reports, jobs;
  try {
    [trending, numbers, reports, jobs] = await Promise.all([
      getTrendingFeed(7),
      getFlaggedNumbers(),
      getReports({ limit: 500 }),
      getSentinelJobs(),
    ]);
  } catch (err) {
    return (
      <div>
        <h1 className="text-2xl font-semibold text-foreground">Overview</h1>
        <div className="mt-6">
          <BackendOfflineNotice detail={err instanceof ApiError ? err.message : String(err)} />
        </div>
      </div>
    );
  }

  const totalFlagged = numbers.filter((n) => n.is_publicly_flagged).length;
  const totalAnomalies = jobs.reduce((sum, j) => sum + j.n_flagged, 0);
  // A number reported from more than one market is the signal a moderator most
  // needs to see: it separates an organised operation from a local dispute.
  const crossBorder = numbers.filter((n) => Object.keys(n.countries).length > 1).length;
  const activeMarkets = trending.country_hotspots.filter((h) => h.report_count > 0).length;

  return (
    <div>
      <h1 className="text-2xl font-semibold text-foreground">Overview</h1>
      <p className="mt-1 text-sm text-neutral">
        Live snapshot of community reports, number reputation, and Sentinel activity.
      </p>

      <div className="mt-6 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Numbers with reports"
          value={numbers.length}
          hint={`${totalFlagged} publicly flagged · ${crossBorder} cross-border`}
        />
        <StatCard
          label="Reports on file"
          value={reports.length}
          hint={`most recent 500 · ${activeMarkets} active markets`}
        />
        <StatCard label="Sentinel runs" value={jobs.length} hint={`${totalAnomalies} anomalies flagged total`} />
        <StatCard
          label="Trending categories (7d)"
          value={trending.trending_categories.length}
          hint={trending.trending_categories[0]?.label ?? "no data yet"}
        />
      </div>

      <div className="mt-10 grid gap-8 lg:grid-cols-2">
        <section>
          <h2 className="text-sm font-semibold uppercase tracking-wide text-brand-secondary">
            Trending categories (7d)
          </h2>
          <ul className="mt-4 space-y-2">
            {trending.trending_categories.slice(0, 8).map((c) => (
              <li
                key={c.category}
                className="flex items-center justify-between rounded-xl border border-black/5 px-4 py-3 text-sm dark:border-white/10"
              >
                <span className="font-medium text-foreground">{c.label}</span>
                <span className="text-neutral">
                  {c.report_count} reports · score {c.score.toFixed(2)}
                </span>
              </li>
            ))}
            {trending.trending_categories.length === 0 ? (
              <p className="text-sm text-neutral">No reports in the last 7 days.</p>
            ) : null}
          </ul>
          <p className="mt-3 text-xs text-neutral">{trending.method_note}</p>
        </section>

        {/* The admin view is cross-market by default, so it shows the country
            rollup rather than one country's regions. Regional detail lives on
            the per-country view, where it is legible. */}
        <section>
          <h2 className="text-sm font-semibold uppercase tracking-wide text-brand-secondary">
            Country hotspot map
          </h2>
          <ul className="mt-4 grid grid-cols-2 gap-2">
            {trending.country_hotspots.map((h) => (
              <li
                key={h.country}
                className="flex items-center justify-between rounded-xl border border-black/5 px-4 py-3 text-sm dark:border-white/10"
              >
                <div>
                  <p className="font-medium text-foreground">{h.country_name}</p>
                  <p className="text-xs text-neutral">{h.report_count} reports</p>
                </div>
                <Badge severity={severityForHotspotLevel(h.level)}>{h.level}</Badge>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </div>
  );
}
