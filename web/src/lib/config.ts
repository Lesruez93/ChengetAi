/**
 * Server-side only: the FastAPI backend base URL. Deliberately not
 * NEXT_PUBLIC_* — every data fetch in this app happens in server components
 * or route handlers, so the backend URL (and, in production, any auth
 * headers added later) never needs to reach the browser bundle.
 */
export const API_BASE_URL = process.env.CHENGETAI_API_BASE_URL ?? "http://localhost:8000";
