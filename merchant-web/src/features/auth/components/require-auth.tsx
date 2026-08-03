"use client";

import { useEffect, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useAuth } from "../auth-context";
import { needsRecoveryPinSetup } from "../types";

/**
 * Client gate for protected pages. Middleware already blocks cookieless
 * visitors; this handles the case where the cookie exists but the session is
 * actually invalid (expired + refresh failed), and avoids flashing protected
 * content before the session resolves.
 */
export function RequireAuth({ children }: { children: ReactNode }) {
  const { status, user } = useAuth();
  const router = useRouter();
  const t = useTranslations("auth");

  useEffect(() => {
    if (status === "guest") {
      router.replace("/login");
      return;
    }
    if (status !== "authed" || !user) return;
    // A Google-only account without a recovery PIN yet takes priority over
    // every other gate — persists across a reload between signup and
    // setting the PIN (not just a one-time redirect from the button).
    if (needsRecoveryPinSetup(user)) {
      router.replace("/onboarding/recovery-pin");
      return;
    }
    // A merchant who hasn't created their shop yet (signed up but didn't
    // finish onboarding) can't use the dashboard — send them to finish it.
    // Staff and shop owners both carry a shopId, so they pass through.
    if (user.shopId == null) {
      router.replace("/onboarding");
    }
  }, [status, user, router]);

  if (status !== "authed") {
    return (
      <div className="flex min-h-dvh items-center justify-center">
        <p className="text-body-md text-subtle">{t("common.loading")}</p>
      </div>
    );
  }
  return <>{children}</>;
}
