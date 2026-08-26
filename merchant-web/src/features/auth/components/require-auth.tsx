"use client";

import { useEffect, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useAuth } from "../auth-context";
import { needsRecoveryPinSetup } from "../types";

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
    if (needsRecoveryPinSetup(user)) {
      router.replace("/onboarding/recovery-pin");
      return;
    }
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
