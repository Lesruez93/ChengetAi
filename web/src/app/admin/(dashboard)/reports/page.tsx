import { BackendOfflineNotice } from "@/components/BackendOfflineNotice";
import { ApiError, getReports } from "@/lib/api";

export const dynamic = "force-dynamic";

function formatDate(iso: string) {
  return new Date(iso).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" });
}

export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ category?: string; province?: string }>;
}) {
  const { category, province } = await searchParams;

  let reports;
  try {
    reports = await getReports({ limit: 200, category, province });
  } catch (err) {
    return (
      <div>
        <h1 className="text-2xl font-semibold text-foreground">Reports</h1>
        <div className="mt-6">
          <BackendOfflineNotice detail={err instanceof ApiError ? err.message : String(err)} />
        </div>
      </div>
    );
  }

  return (
    <div>
      <h1 className="text-2xl font-semibold text-foreground">Reports</h1>
      <p className="mt-1 text-sm text-neutral">
        Moderation queue: the {reports.length} most recent community reports
        {category ? ` in “${category}”` : ""}
        {province ? ` from ${province}` : ""}.
      </p>

      <div className="mt-6 overflow-x-auto rounded-2xl border border-black/5 dark:border-white/10">
        <table className="w-full min-w-[720px] text-left text-sm">
          <thead className="bg-surface-tint text-xs uppercase tracking-wide text-neutral">
            <tr>
              <th className="px-4 py-3 font-medium">Number</th>
              <th className="px-4 py-3 font-medium">Category</th>
              <th className="px-4 py-3 font-medium">Province</th>
              <th className="px-4 py-3 font-medium">Excerpt</th>
              <th className="px-4 py-3 font-medium">Trust</th>
              <th className="px-4 py-3 font-medium">Reported</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((r) => (
              <tr key={r.id} className="border-t border-black/5 dark:border-white/10">
                <td className="px-4 py-3 font-medium text-foreground">{r.msisdn}</td>
                <td className="px-4 py-3 text-neutral">{r.category.replace(/_/g, " ")}</td>
                <td className="px-4 py-3 text-neutral">{r.province}</td>
                <td className="max-w-xs truncate px-4 py-3 text-neutral" title={r.message_excerpt}>
                  {r.message_excerpt || "—"}
                </td>
                <td className="px-4 py-3 text-neutral">{r.reporter_trust.toFixed(1)}</td>
                <td className="px-4 py-3 text-neutral">{formatDate(r.created_at)}</td>
              </tr>
            ))}
            {reports.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-neutral">
                  No reports match this filter.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </div>
  );
}
