import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { AuthProvider } from "@/features/auth/auth-context";
import "./globals.css";

// Inter — same typeface as the Flutter merchant app. Exposed as the
// `--font-inter` CSS variable consumed by the type tokens in globals.css.
const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "ShopXY — Merchant",
  description: "Manage inventory, invoices, parties and vendors.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} h-full`}>
      <body className="min-h-full bg-canvas text-ink antialiased">
        <AuthProvider>{children}</AuthProvider>
      </body>
    </html>
  );
}
