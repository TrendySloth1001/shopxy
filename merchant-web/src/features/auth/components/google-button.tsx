"use client";

import { useTranslations } from "next-intl";

import { GoogleIcon } from "@/shared/icons";

/**
 * "Continue with Google" button. The Google "G" brand mark lives in the shared
 * icon source (`@/shared/icons`). The button chrome itself uses tokens.
 *
 * It points at the BFF route `/api/auth/google`, the conventional OAuth start.
 * The backend Google OAuth flow is not built yet — until it is, that route
 * returns a "coming soon" notice instead of a dead link (see PENDING.md).
 */
export function GoogleButton() {
  const t = useTranslations("auth");
  return (
    <a
      href="/api/auth/google"
      className="inline-flex h-12 w-full items-center justify-center gap-sm rounded-full border border-hairline bg-surface text-label-lg text-ink transition-colors hover:border-brand hover:text-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <GoogleIcon />
      {t("login.continueWithGoogle")}
    </a>
  );
}
