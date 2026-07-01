import { getRequestConfig } from "next-intl/server";
import { cookies } from "next/headers";
import { DEFAULT_LOCALE, LOCALE_COOKIE, isSupportedLocale, type AppLocale } from "./config";

/**
 * next-intl request config (App Router, NO i18n routing). The active locale is
 * read from the `locale` cookie set by the language picker's server action;
 * unknown/absent → English.
 */
export default getRequestConfig(async () => {
  const store = await cookies();
  const cookieLocale = store.get(LOCALE_COOKIE)?.value;
  const locale: AppLocale = isSupportedLocale(cookieLocale) ? cookieLocale : DEFAULT_LOCALE;

  return {
    locale,
    messages: (await import(`../../messages/${locale}.json`)).default,
  };
});
