/** Shared mapping from risk/hotspot level strings to Tailwind color classes.
 * Mirrors app/lib/core/theme.dart's AppColors.forHotspotLevel/forRiskLevel so
 * the web dashboard and the Flutter app agree on what "red" means. */

export type Severity = "danger" | "warning" | "safe" | "neutral";

const SEVERITY_CLASSES: Record<Severity, { bg: string; text: string; dot: string }> = {
  danger: { bg: "bg-danger/10", text: "text-danger", dot: "bg-danger" },
  warning: { bg: "bg-warning/10", text: "text-warning", dot: "bg-warning" },
  safe: { bg: "bg-safe/10", text: "text-safe", dot: "bg-safe" },
  neutral: { bg: "bg-neutral/10", text: "text-neutral", dot: "bg-neutral" },
};

export function severityForRiskLevel(level: string): Severity {
  switch (level) {
    case "high":
      return "danger";
    case "medium":
      return "warning";
    case "low":
      return "safe";
    default:
      return "neutral";
  }
}

export function severityForHotspotLevel(level: string): Severity {
  switch (level) {
    case "red":
      return "danger";
    case "yellow":
      return "warning";
    case "green":
      return "safe";
    default:
      return "neutral";
  }
}

export function classesForSeverity(severity: Severity) {
  return SEVERITY_CLASSES[severity];
}
