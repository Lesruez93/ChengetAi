export function SiteFooter() {
  return (
    <footer className="border-t border-black/5 py-10 text-sm text-neutral dark:border-white/10">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 px-6 md:flex-row md:items-center md:justify-between">
        <p>
          <span className="font-medium text-foreground">ChengetAI</span>
        </p>
        <a
          href="https://github.com/Lesruez93/ChengetAi"
          target="_blank"
          rel="noreferrer"
          className="transition hover:text-brand-primary"
        >
          github.com/Lesruez93/ChengetAi
        </a>
      </div>
    </footer>
  );
}
