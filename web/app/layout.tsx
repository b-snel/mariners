import type { Metadata } from "next";
import { Space_Grotesk, JetBrains_Mono } from "next/font/google";
import "./globals.css";

// Self-hosted at build time by next/font — no runtime request to Google, so the
// static export stays self-contained.
const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-space-grotesk",
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--font-jetbrains",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Mariners 2026 — Live Sabermetrics",
  description:
    "An animated WebGL view of the 2026 Seattle Mariners: PCA, expected-stats, and value trends, refreshed after every game.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${spaceGrotesk.variable} ${jetbrainsMono.variable}`}>
      <body>
        <div className="grid-backdrop" aria-hidden />
        <main>{children}</main>
      </body>
    </html>
  );
}
