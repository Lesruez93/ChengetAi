/**
 * MVP admin auth: a single shared password gates /admin, backed by a
 * stateless signed cookie (no session store needed). This is deliberately
 * lightweight for the challenge demo — the roadmap item is real Supabase
 * Auth with a per-admin account and an `is_admin` role claim, matching the
 * auth model already used by the Flutter consumer app and the Supabase
 * schema in sample_data/seed.sql.
 *
 * Uses Web Crypto (available in both the Node and Edge runtimes) rather
 * than Node's `crypto` module so this works unchanged from middleware.ts,
 * which runs on the Edge runtime.
 */

export const ADMIN_SESSION_COOKIE = "chengetai_admin_session";

function getSecret(): string {
  // Falls back to the admin password itself so a fresh clone with only
  // ADMIN_PASSWORD set (see .env.example) still works; set ADMIN_SESSION_SECRET
  // separately in production so rotating the login password doesn't also
  // invalidate the token derivation in a confusing way.
  return process.env.ADMIN_SESSION_SECRET || process.env.ADMIN_PASSWORD || "chengetai-dev-secret";
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** The expected session cookie value when the admin is correctly logged in. */
export async function expectedSessionToken(): Promise<string> {
  return sha256Hex(`chengetai-admin-session:${getSecret()}`);
}

export function checkAdminPassword(candidate: string): boolean {
  const expected = process.env.ADMIN_PASSWORD;
  if (!expected) return false; // fail closed if no password is configured
  return candidate === expected;
}
