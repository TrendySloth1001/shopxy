import type { Metadata } from "next";
import { Inter, Plus_Jakarta_Sans } from "next/font/google";
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

export const metadata: Metadata = {
  title: {
    default: "ShopXY — Merchant",
    template: "%s · ShopXY Merchant",
  },
  description: "Manage inventory, invoices, parties and vendors.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${inter.variable} ${jakarta.variable} h-full`}
      suppressHydrationWarning
    >
      <head>
        {/* Apply the stored theme to <html> before first paint — no light-mode
            flash for dark users. Must run before the body renders. */}
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
      </head>
      <body className="min-h-full bg-canvas text-ink antialiased">
        <ThemeProvider>
          <AuthProvider>{children}</AuthProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
