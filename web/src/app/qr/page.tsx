import type { Metadata } from "next";
import Image from "next/image";
import QRCode from "qrcode";

// Full-screen QR for projecting during talks. Unlisted like /script: reachable
// by direct link only, kept out of the site nav and out of search results.
export const metadata: Metadata = {
  title: "Scan to open",
  robots: { index: false, follow: false },
};

const SITE_URL = "https://chengetai.vercel.app/";
const SITE_URL_LABEL = "chengetai.vercel.app";
// The QR spec requires a 4-module light border; scanners struggle without it.
const QUIET_ZONE = 4;

interface QrSvg {
  size: number;
  path: string;
}

/** Renders the QR matrix as one SVG path — crisp at projector scale, no raster. */
function buildQrSvg(url: string): QrSvg {
  const { modules } = QRCode.create(url, { errorCorrectionLevel: "M" });
  const cells = Array.from({ length: modules.size }, (_, row) => row).flatMap((row) =>
    Array.from({ length: modules.size }, (_, col) => col)
      .filter((col) => modules.get(row, col))
      .map((col) => `M${col + QUIET_ZONE} ${row + QUIET_ZONE}h1v1h-1z`),
  );
  return { size: modules.size + QUIET_ZONE * 2, path: cells.join("") };
}

export default function QrPage() {
  const qr = buildQrSvg(SITE_URL);

  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-8 px-6 py-10 text-center">
      <div className="flex items-center gap-3 text-2xl font-semibold text-brand-primary md:text-3xl">
        <Image src="/logo-mark.png" alt="" width={48} height={48} className="h-12 w-12" priority />
        ChengetAI
      </div>

      {/* Always dark-on-white, even in dark mode: inverted QR codes fail on many scanners. */}
      <div className="rounded-3xl bg-white p-4 shadow-xl">
        <svg
          viewBox={`0 0 ${qr.size} ${qr.size}`}
          role="img"
          aria-label={`QR code linking to ${SITE_URL}`}
          shapeRendering="crispEdges"
          className="block h-[min(60vh,80vw)] w-[min(60vh,80vw)]"
        >
          <rect width={qr.size} height={qr.size} fill="#ffffff" />
          <path d={qr.path} fill="#000000" />
        </svg>
      </div>

      <div>
        <p className="text-xl text-neutral md:text-2xl">Scan with your phone camera</p>
        <p className="mt-2 text-3xl font-semibold tracking-tight text-foreground md:text-5xl">
          {SITE_URL_LABEL}
        </p>
      </div>
    </main>
  );
}
