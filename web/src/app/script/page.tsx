import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";

// Unlisted on purpose: reachable by direct link only, so it is kept out of the
// site nav and out of search results.
export const metadata: Metadata = {
  title: "Summit Speaking Script",
  robots: { index: false, follow: false },
};

const SCRIPT_PDF_URL = "/chengetai-summit-speaking-script.pdf";
const SCRIPT_PDF_FILENAME = "ChengetAI — Summit Speaking Script.pdf";

export default function ScriptPage() {
  return (
    <>
      <header className="border-b border-black/5 dark:border-white/10">
        <div className="mx-auto flex max-w-5xl items-center justify-between gap-4 px-6 py-4">
          <Link href="/" className="flex items-center gap-2 text-lg font-semibold text-brand-primary">
            <Image src="/logo-mark.png" alt="ChengetAI" width={32} height={32} className="h-8 w-8" priority />
            ChengetAI
          </Link>
          <a
            href={SCRIPT_PDF_URL}
            download={SCRIPT_PDF_FILENAME}
            className="rounded-full bg-brand-primary px-5 py-2 text-sm font-medium text-white transition hover:bg-brand-primary/90"
          >
            Download PDF
          </a>
        </div>
      </header>
      <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col px-6 py-8">
        <h1 className="text-2xl font-semibold text-foreground">Summit Speaking Script</h1>
        {/* Browsers without an inline PDF viewer (most Android browsers) render
            the fallback link instead of the document. */}
        <object
          data={SCRIPT_PDF_URL}
          type="application/pdf"
          aria-label="ChengetAI Summit Speaking Script (PDF)"
          className="mt-6 h-[80vh] w-full rounded-2xl border border-black/5 dark:border-white/10"
        >
          <p className="p-6 text-sm text-neutral">
            This browser can&apos;t show the PDF inline.{" "}
            <a href={SCRIPT_PDF_URL} download={SCRIPT_PDF_FILENAME} className="font-medium text-brand-primary underline">
              Download the script
            </a>{" "}
            instead.
          </p>
        </object>
      </main>
    </>
  );
}
