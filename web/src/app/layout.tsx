import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "ChengetAI — AI Scam & Fraud Protection for Zimbabwe",
    template: "%s · ChengetAI",
  },
  description:
    "AI-powered scam message detection, phone number reputation, a trending scams map, and agent fraud detection for Zimbabwe.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col bg-background text-foreground">{children}</body>
    </html>
  );
}
