import type { Metadata } from "next";
import { Inter, Noto_Sans_Devanagari, Plus_Jakarta_Sans } from "next/font/google";
import { NextIntlClientProvider } from "next-intl";
import { getLocale, getMessages } from "next-intl/server";
import { AuthProvider } from "@/features/auth/auth-context";
import { ThemeProvider } from "@/features/theme/theme-context";
import { THEME_INIT_SCRIPT } from "@/features/theme/theme";
import "./globals.css";

// Inter — same typeface as the Flutter merchant app. Exposed as the
// `--font-inter` CSS variable consumed by the type tokens in globals.css.
const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

// Plus Jakarta Sans — display face for auth-screen headings (`--font-display`
// → `font-display` utility). Body text stays on Inter.
const jakarta = Plus_Jakarta_Sans({
  variable: "--font-jakarta",
  subsets: ["latin"],
  weight: ["500", "600", "700"],
  display: "swap",
});

// Noto Sans Devanagari — covers the Devanagari script (Hindi). Exposed as
// `--font-noto-devanagari`; globals.css swaps `--font-sans` to it for `lang="hi"`
// so Hindi renders instead of tofu (□) boxes. Latin subset kept so mixed strings
// (e.g. "ShopXY") stay consistent.
const notoDevanagari = Noto_Sans_Devanagari({
  variable: "--font-noto-devanagari",
  subsets: ["devanagari", "latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "ShopXY — Merchant",
    template: "%s · ShopXY Merchant",
  },
  description: "Manage inventory, invoices, parties and vendors.",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  // Active UI locale (from the `locale` cookie via src/i18n/request.ts) drives
  // `<html lang>` — which in turn selects the Devanagari font in globals.css —
  // and the messages handed to the client provider.
  const locale = await getLocale();
  const messages = await getMessages();

  return (
    <html
      lang={locale}
      className={`${inter.variable} ${jakarta.variable} ${notoDevanagari.variable} h-full`}
      suppressHydrationWarning
    >
      <head>
        {/* Apply the stored theme to <html> before first paint — no light-mode
            flash for dark users. Must run before the body renders. */}
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
      </head>
      <body className="min-h-full bg-canvas text-ink antialiased">
        <NextIntlClientProvider locale={locale} messages={messages}>
          <ThemeProvider>
            <AuthProvider>{children}</AuthProvider>
          </ThemeProvider>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
