import { API_BASE_URL } from "./config";
import type {
  FeedItem,
  NumberReputation,
  ReportListItem,
  SentinelJobSummary,
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

export function getTrendingFeed(windowDays = 7): Promise<TrendingFeedResponse> {
  return apiFetch(`/feed/trending?window_days=${windowDays}`);
}

export function getFeedItems(): Promise<FeedItem[]> {
  return apiFetch("/feed");
}

export function getFlaggedNumbers(): Promise<NumberReputation[]> {
  return apiFetch("/numbers");
}

export function getReports(params?: { limit?: number; category?: string; province?: string }): Promise<
  ReportListItem[]
> {
  const query = new URLSearchParams();
  if (params?.limit) query.set("limit", String(params.limit));
  if (params?.category) query.set("category", params.category);
  if (params?.province) query.set("province", params.province);
  const qs = query.toString();
  return apiFetch(`/reports${qs ? `?${qs}` : ""}`);
}

export function getSentinelJobs(): Promise<SentinelJobSummary[]> {
  return apiFetch("/sentinel/jobs");
}
