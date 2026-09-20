export function BackendOfflineNotice({ detail }: { detail?: string }) {
  return (
    <div className="rounded-2xl border border-warning/30 bg-warning/5 p-6 text-sm text-foreground">
      <p className="font-medium text-warning">Backend unreachable</p>
      <p className="mt-1 text-neutral">
        Couldn&apos;t load live data from the ChengetAI API. Make sure the FastAPI backend is
        running and <code className="rounded bg-black/5 px-1 py-0.5 dark:bg-white/10">CHENGETAI_API_BASE_URL</code>{" "}
        points at it (see <code className="rounded bg-black/5 px-1 py-0.5 dark:bg-white/10">web/.env.example</code>).
      </p>
      {detail ? <p className="mt-2 text-xs text-neutral/80">{detail}</p> : null}
    </div>
  );
}
