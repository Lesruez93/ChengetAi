"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

const LINKS = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/reports", label: "Reports" },
  { href: "/admin/numbers", label: "Flagged Numbers" },
  { href: "/admin/sentinel", label: "Sentinel Jobs" },
];

export function AdminNav() {
  const pathname = usePathname();
  const router = useRouter();

  async function logout() {
    await fetch("/api/admin/logout", { method: "POST" });
    router.push("/admin/login");
    router.refresh();
  }

  return (
    <aside className="flex w-56 shrink-0 flex-col border-r border-black/5 bg-surface-tint px-4 py-6 dark:border-white/10">
      <Link href="/" className="mb-8 flex items-center gap-2 px-2 text-base font-semibold text-brand-primary">
        <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-brand-primary text-xs text-white">
          CG
        </span>
        ChengetAI
      </Link>
      <nav className="flex flex-1 flex-col gap-1">
        {LINKS.map((link) => {
          const active = link.href === "/admin" ? pathname === "/admin" : pathname.startsWith(link.href);
          return (
            <Link
              key={link.href}
              href={link.href}
              className={`rounded-lg px-3 py-2 text-sm font-medium transition ${
                active
                  ? "bg-brand-primary text-white"
                  : "text-neutral hover:bg-black/5 hover:text-foreground dark:hover:bg-white/10"
              }`}
            >
              {link.label}
            </Link>
          );
        })}
      </nav>
      <button
        onClick={logout}
        className="mt-4 rounded-lg px-3 py-2 text-left text-sm font-medium text-neutral transition hover:bg-black/5 hover:text-danger dark:hover:bg-white/10"
      >
        Log out
      </button>
    </aside>
  );
}
