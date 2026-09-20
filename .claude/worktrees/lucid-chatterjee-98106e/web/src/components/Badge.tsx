import { classesForSeverity, Severity } from "@/lib/risk-colors";

export function Badge({ severity, children }: { severity: Severity; children: React.ReactNode }) {
  const classes = classesForSeverity(severity);
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium ${classes.bg} ${classes.text}`}
    >
      <span className={`h-1.5 w-1.5 rounded-full ${classes.dot}`} />
      {children}
    </span>
  );
}
