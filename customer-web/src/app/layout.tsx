import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { AuthProvider } from "@/features/auth/auth-context";
import { peekSessionUser } from "@/server/auth/session";
import { NotificationsProvider } from "@/features/notifications/notifications-context";
import { CartProvider } from "@/features/cart/cart-context";
import { SiteFooter } from "@/shared/ui/site-footer";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "ShopXY",
  description: "Your shops, invitations and invoice ledgers in one place.",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const initialUser = await peekSessionUser();
  return (
    <html lang="en" className={`${inter.variable} h-full`}>
      <body className="min-h-full bg-canvas text-ink antialiased">
        <AuthProvider initialUser={initialUser}>
          <NotificationsProvider>
            <CartProvider>
              {children}
              <SiteFooter />
            </CartProvider>
          </NotificationsProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
