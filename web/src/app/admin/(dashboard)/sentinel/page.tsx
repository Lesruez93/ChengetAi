import { BackendOfflineNotice } from "@/components/BackendOfflineNotice";
import { ApiError, getSentinelJobs } from "@/lib/api";

export const dynamic = "force-dynamic";

function formatDate(iso: string) {
  return new Date(iso).toLocaleString("en-ZW", { dateStyle: "medium", timeStyle: "short" });
}

export default async function SentinelJobsPage() {
  let jobs;
  try {
    jobs = await getSentinelJobs();
  } catch (err) {
    return (
      <div>
        <h1 className="text-2xl font-semibold text-foreground">Sentinel Jobs</h1>
        <div className="mt-6">
          <BackendOfflineNotice detail={err instanceof ApiError ? err.message : String(err)} />
        </div>
      </div>
    );
  }

  return (
    <div>
      <h1 className="text-2xl font-semibold text-foreground">Sentinel Jobs</h1>
      <p className="mt-1 text-sm text-neutral">
        Every Agent Fraud Sentinel CSV analysis run, newest first. Upload a new file from the
        ChengetAI mobile app&apos;s Sentinel screen — this table refreshes on reload.
      </p>

      <div className="mt-6 overflow-x-auto rounded-2xl border border-black/5 dark:border-white/10">
        <table className="w-full min-w-[600px] text-left text-sm">
          <thead className="bg-surface-tint text-xs uppercase tracking-wide text-neutral">
            <tr>
              <th className="px-4 py-3 font-medium">File</th>
              <th className="px-4 py-3 font-medium">Transactions</th>
              <th className="px-4 py-3 font-medium">Flagged</th>
              <th className="px-4 py-3 font-medium">Flag rate</th>
              <th className="px-4 py-3 font-medium">Run at</th>
            </tr>
          </thead>
          <tbody>
            {jobs.map((j) => (
              <tr key={j.id} className="border-t border-black/5 dark:border-white/10">
                <td className="px-4 py-3 font-medium text-foreground">{j.filename}</td>
                <td className="px-4 py-3 text-neutral">{j.n_transactions}</td>
                <td className="px-4 py-3 text-neutral">{j.n_flagged}</td>
                <td className="px-4 py-3 text-neutral">
                  {j.n_transactions > 0 ? `${((j.n_flagged / j.n_transactions) * 100).toFixed(1)}%` : "—"}
                </td>
                <td className="px-4 py-3 text-neutral">{formatDate(j.created_at)}</td>
              </tr>
            ))}
            {jobs.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-neutral">
                  No Sentinel analysis runs yet.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </div>
  );
}
