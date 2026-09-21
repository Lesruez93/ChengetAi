import type { Metadata } from "next";
import { Analytics } from "@vercel/analytics/next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "ChengetAI — Check it, report it safely, reach help",
    template: "%s · ChengetAI",
  },
  description:
    "ChengetAI warns you about known scammers on incoming calls, SMS and WhatsApp calls, and checks any message you paste in — WhatsApp, email, Facebook or Messenger. Safe community reporting and country-specific support pathways across African mobile-money markets: Zimbabwe, Kenya, Nigeria, Uganda, South Africa, Ghana and Tanzania.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col bg-background text-foreground">
        {children}
        <Analytics />
      </body>
    </html>
  );
}
