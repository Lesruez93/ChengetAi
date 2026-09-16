/** Mirrors backend/app/schemas/*.py field-for-field. See docs/api.md for the full reference. */

export type Verdict = "scam" | "suspicious" | "safe";
export type RiskLevel = "unknown" | "low" | "medium" | "high";
export type HotspotLevel = "green" | "yellow" | "red";
export type ReportStatus = "recorded" | "duplicate_collapsed" | "rate_limited";
export type ChannelKind = "wallet" | "regulator" | "police" | "support";

export interface FeedItem {
  id: string;
  title: string;
  category: string;
  summary: string;
  /** null means the alert applies across every market. */
  country: string | null;
  region: string | null;
  created_at: string;
}

export interface TrendingCategory {
  category: string;
  label: string;
  score: number;
  report_count: number;
}

export interface RegionHotspot {
  region: string;
  level: HotspotLevel;
  report_count: number;
  top_category: string | null;
}

export interface CountryHotspot {
  country: string;
  country_name: string;
  level: HotspotLevel;
  report_count: number;
  top_category: string | null;
}

export interface TrendingFeedResponse {
  generated_at: string;
  window_days: number;
  /** null when the caller did not scope to one market. */
  country: string | null;
  /** What the country calls its first-level unit — "Province", "County", "Zone". */
  region_label: string | null;
  trending_categories: TrendingCategory[];
  /** Empty unless a country was named; see backend/app/services/feed.py. */
  hotspots: RegionHotspot[];
  country_hotspots: CountryHotspot[];
  method_note: string;
}

export interface NumberReputation {
  /** Always E.164, e.g. "+254712345678". */
  msisdn: string;
  country: string;
  report_count: number;
  categories: Record<string, number>;
  /** Report counts per reporting country; >1 key means cross-border reach. */
  countries: Record<string, number>;
  last_reported_at: string | null;
  is_publicly_flagged: boolean;
  risk_level: RiskLevel;
}

export interface ReportListItem {
  id: string;
  msisdn: string;
  country: string;
  category: string;
  region: string;
  message_excerpt: string;
  reporter_id: string | null;
  reporter_trust: number;
  created_at: string;
}

export interface SentinelJobSummary {
  id: string;
  filename: string;
  country: string;
  n_transactions: number;
  n_flagged: number;
  created_at: string;
}

export interface Country {
  code: string;
  name: string;
  dial_code: string;
  region_label: string;
  regions: string[];
  providers: string[];
  languages: string[];
  currency_code: string;
  currency_symbol: string;
  example_msisdn: string;
}

export interface ScamCategory {
  key: string;
  label: string;
  description: string;
  first_action: string;
}

export interface SupportChannel {
  kind: ChannelKind;
  organisation: string;
  what_it_does: string;
  contact: string | null;
  url: string | null;
  /** False means the contact is unconfirmed and must be shown as such, not hidden. */
  verified: boolean;
}

export interface SupportPathway {
  country: string;
  country_name: string;
  category: string | null;
  immediate_steps: string[];
  category_first_action: string | null;
  channels: SupportChannel[];
  data_note: string;
}
