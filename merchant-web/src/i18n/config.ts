/**
 * Locale config shared by the request handler, the set-locale server action and
 * the client picker. Deliberately free of server-only imports (`next/headers`)
 * so it's safe to import from client components too.
 *
 * Adding a language: append its code here, drop a `messages/<code>.json`, list
 * it in the picker, and (if it's a new script) add a font rule in globals.css.
 */
export const SUPPORTED_LOCALES = ["en", "hi"] as const;
export type AppLocale = (typeof SUPPORTED_LOCALES)[number];
export const DEFAULT_LOCALE: AppLocale = "en";
export const LOCALE_COOKIE = "locale";

export function isSupportedLocale(value: string | undefined): value is AppLocale {
  return !!value && (SUPPORTED_LOCALES as readonly string[]).includes(value);
}
