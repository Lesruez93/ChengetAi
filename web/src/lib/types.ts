/** Mirrors backend/app/schemas/*.py field-for-field. See docs/api.md for the full reference. */

export type Verdict = "scam" | "suspicious" | "safe";
export type RiskLevel = "unknown" | "low" | "medium" | "high";
export type HotspotLevel = "green" | "yellow" | "red";
export type ReportStatus = "recorded" | "duplicate_collapsed" | "rate_limited";

export interface FeedItem {
  id: string;
  title: string;
  category: string;
  summary: string;
  province: string | null;
  created_at: string;
}

export interface TrendingCategory {
  category: string;
  score: number;
  report_count: number;
}

export interface ProvinceHotspot {
  province: string;
  level: HotspotLevel;
  report_count: number;
  top_category: string | null;
}

export interface TrendingFeedResponse {
  generated_at: string;
  window_days: number;
  trending_categories: TrendingCategory[];
  hotspots: ProvinceHotspot[];
  method_note: string;
}

export interface NumberReputation {
  msisdn: string;
  report_count: number;
  categories: Record<string, number>;
  last_reported_at: string | null;
  is_publicly_flagged: boolean;
  risk_level: RiskLevel;
}

export interface ReportListItem {
  id: string;
  msisdn: string;
  category: string;
  province: string;
  message_excerpt: string;
  reporter_id: string | null;
  reporter_trust: number;
  created_at: string;
}

export interface SentinelJobSummary {
  id: string;
  filename: string;
  n_transactions: number;
  n_flagged: number;
  created_at: string;
}
