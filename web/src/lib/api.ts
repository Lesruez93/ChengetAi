import { API_BASE_URL } from "./config";
import type {
  Country,
  FeedItem,
  NumberReputation,
  ReportListItem,
  ScamCategory,
  SentinelJobSummary,
  SupportPathway,
  TrendingFeedResponse,
} from "./types";

/**
 * Thrown when the backend is unreachable or returns a non-2xx response.
 * Callers in server components catch this and render a "backend offline"
 * state instead of crashing the page — the dashboard should stay usable
 * for browsing UI/layout even when the FastAPI backend isn't running.
 */
export class ApiError extends Error {
  constructor(message: string, readonly statusCode?: number) {
    super(message);
    this.name = "ApiError";
  }
}

async function apiFetch<T>(path: string): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, { cache: "no-store" });
  } catch (err) {
    throw new ApiError(`Could not reach the ChengetAI backend at ${API_BASE_URL}: ${String(err)}`);
  }
  if (!response.ok) {
    throw new ApiError(`Request to ${path} failed`, response.status);
  }
  return (await response.json()) as T;
}

function qs(params: Record<string, string | number | undefined>): string {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== "") query.set(key, String(value));
  }
  const s = query.toString();
  return s ? `?${s}` : "";
}

/** Omit `country` for the cross-country view; pass it to get the regional map too. */
export function getTrendingFeed(windowDays = 7, country?: string): Promise<TrendingFeedResponse> {
  return apiFetch(`/feed/trending${qs({ window_days: windowDays, country })}`);
}

export function getFeedItems(country?: string): Promise<FeedItem[]> {
  return apiFetch(`/feed${qs({ country })}`);
}

export function getFlaggedNumbers(country?: string): Promise<NumberReputation[]> {
  return apiFetch(`/numbers${qs({ country })}`);
}

export function getReports(params?: {
  limit?: number;
  category?: string;
  country?: string;
  region?: string;
}): Promise<ReportListItem[]> {
  return apiFetch(`/reports${qs({ ...params })}`);
}

export function getSentinelJobs(): Promise<SentinelJobSummary[]> {
  return apiFetch("/sentinel/jobs");
}

export function getCountries(): Promise<Country[]> {
  return apiFetch("/reference/countries");
}

export function getCategories(): Promise<ScamCategory[]> {
  return apiFetch("/reference/categories");
}

export function getSupportPathway(country: string, category?: string): Promise<SupportPathway> {
  return apiFetch(`/support/${country}${qs({ category })}`);
}
