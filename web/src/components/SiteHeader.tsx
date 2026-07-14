import Image from "next/image";
import Link from "next/link";

const NAV_LINKS = [
  { href: "#problem", label: "The Problem" },
  { href: "#features", label: "Features" },
  { href: "#ai", label: "How it works" },
  { href: "#demo", label: "Demo" },
];

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-30 border-b border-black/5 bg-background/80 backdrop-blur dark:border-white/10">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <Link href="/" className="flex items-center gap-2 text-lg font-semibold text-brand-primary">
          <Image src="/logo-mark.png" alt="ChengetAI" width={32} height={32} className="h-8 w-8" priority />
          ChengetAI
        </Link>
        <nav className="hidden items-center gap-6 text-sm text-neutral md:flex">
          {NAV_LINKS.map((link) => (
            <a key={link.href} href={link.href} className="transition hover:text-brand-primary">
              {link.label}
            </a>
          ))}
        </nav>
        <Link
          href="/admin"
          className="rounded-full border border-brand-primary/30 px-4 py-1.5 text-sm font-medium text-brand-primary transition hover:bg-brand-primary hover:text-white"
        >
          Admin Dashboard
        </Link>
      </div>
    </header>
  );
}
