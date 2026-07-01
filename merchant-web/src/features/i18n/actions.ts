"use server";

import { cookies } from "next/headers";
import { LOCALE_COOKIE, isSupportedLocale } from "@/i18n/config";

/**
 * Persist the chosen UI locale to the `locale` cookie (read server-side by
 * src/i18n/request.ts). A server action rather than client-side `document.cookie`
 * so it plays nicely with the React Compiler and keeps cookie writes on the
 * server. Validates the input at the boundary. The caller refreshes the route.
 */
export async function setLocale(locale: string): Promise<void> {
  if (!isSupportedLocale(locale)) return;
  const store = await cookies();
  store.set(LOCALE_COOKIE, locale, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
}
