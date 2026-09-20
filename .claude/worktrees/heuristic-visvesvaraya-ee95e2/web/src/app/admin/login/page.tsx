"use client";

import Image from "next/image";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [password, setPassword] = useState(process.env.NEXT_PUBLIC_ADMIN_DEMO_PASSWORD ?? "");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    const res = await fetch("/api/admin/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ password }),
    });
    setSubmitting(false);
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error ?? "Login failed.");
      return;
    }
    router.push(searchParams.get("from") || "/admin");
    router.refresh();
  }

  return (
    <div className="flex min-h-screen flex-1 items-center justify-center bg-surface-tint px-6">
      <div className="w-full max-w-sm rounded-2xl bg-white p-8 shadow-sm dark:bg-white/5">
        <div className="mb-6 flex items-center gap-2 text-lg font-semibold text-brand-primary">
          <Image src="/logo-mark.png" alt="ChengetAI" width={32} height={32} className="h-8 w-8" />
          ChengetAI Admin
        </div>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <label className="text-sm font-medium text-foreground">
            Admin password
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoFocus
              required
              className="mt-1 w-full rounded-lg border border-black/10 px-3 py-2 text-sm outline-none focus:border-brand-primary dark:border-white/15 dark:bg-transparent"
            />
          </label>
          {error ? <p className="text-sm text-danger">{error}</p> : null}
          <button
            type="submit"
            disabled={submitting}
            className="rounded-lg bg-brand-primary px-4 py-2 text-sm font-medium text-white transition hover:bg-brand-primary/90 disabled:opacity-60"
          >
            {submitting ? "Signing in…" : "Sign in"}
          </button>
        </form>
        <p className="mt-6 text-xs text-neutral">
          MVP note: this is a single shared password for the demo, not per-admin accounts, and the
          field above is prefilled for judges — just click Sign in. See{" "}
          <code className="rounded bg-black/5 px-1 py-0.5 dark:bg-white/10">src/lib/auth.ts</code>{" "}
          for the roadmap to real Supabase Auth with an admin role claim.
        </p>
      </div>
    </div>
  );
}

export default function AdminLoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  );
}
