import { BackendOfflineNotice } from "@/components/BackendOfflineNotice";
import { Badge } from "@/components/Badge";
import { ApiError, getFlaggedNumbers } from "@/lib/api";
import { severityForRiskLevel } from "@/lib/risk-colors";

export const dynamic = "force-dynamic";

function formatDate(iso: string | null) {
  return iso ? new Date(iso).toLocaleString("en-ZW", { dateStyle: "medium", timeStyle: "short" }) : "—";
}

export default async function FlaggedNumbersPage() {
  let numbers;
  try {
    numbers = await getFlaggedNumbers();
  } catch (err) {
    return (
      <div>
        <h1 className="text-2xl font-semibold text-foreground">Flagged Numbers</h1>
        <div className="mt-6">
          <BackendOfflineNotice detail={err instanceof ApiError ? err.message : String(err)} />
        </div>
      </div>
    );
  }

  return (
    <div>
      <h1 className="text-2xl font-semibold text-foreground">Flagged Numbers</h1>
      <p className="mt-1 text-sm text-neutral">
        Every number with at least one report, ranked by report count. Publicly flagged numbers
        have cleared the abuse-resistance threshold (multiple corroborating reports) — see{" "}
        <code className="rounded bg-black/5 px-1 py-0.5 dark:bg-white/10">docs/architecture.md</code>.
      </p>

      <div className="mt-6 overflow-x-auto rounded-2xl border border-black/5 dark:border-white/10">
        <table className="w-full min-w-[720px] text-left text-sm">
          <thead className="bg-surface-tint text-xs uppercase tracking-wide text-neutral">
            <tr>
              <th className="px-4 py-3 font-medium">Number</th>
              <th className="px-4 py-3 font-medium">Risk</th>
              <th className="px-4 py-3 font-medium">Reports</th>
              <th className="px-4 py-3 font-medium">Categories</th>
              <th className="px-4 py-3 font-medium">Publicly flagged</th>
              <th className="px-4 py-3 font-medium">Last reported</th>
            </tr>
          </thead>
          <tbody>
            {numbers.map((n) => (
              <tr key={n.msisdn} className="border-t border-black/5 dark:border-white/10">
                <td className="px-4 py-3 font-medium text-foreground">{n.msisdn}</td>
                <td className="px-4 py-3">
                  <Badge severity={severityForRiskLevel(n.risk_level)}>{n.risk_level}</Badge>
                </td>
                <td className="px-4 py-3 text-neutral">{n.report_count}</td>
                <td className="px-4 py-3 text-neutral">
                  {Object.entries(n.categories)
                    .map(([cat, count]) => `${cat.replace(/_/g, " ")} (${count})`)
                    .join(", ")}
                </td>
                <td className="px-4 py-3 text-neutral">{n.is_publicly_flagged ? "Yes" : "No"}</td>
                <td className="px-4 py-3 text-neutral">{formatDate(n.last_reported_at)}</td>
              </tr>
            ))}
            {numbers.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-neutral">
                  No reported numbers yet.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </div>
  );
}
