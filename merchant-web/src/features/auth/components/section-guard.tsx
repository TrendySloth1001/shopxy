"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { Lock } from "@/shared/icons";
import { useAuth } from "../auth-context";
import { areaForPath, canManage, canView } from "../capabilities";
import { AREA_LABELS } from "@/features/team/permissions";

export function NoAccessView({ label }: { label?: string }) {
  const t = useTranslations("auth");
  return (
    <div className="flex min-h-[60vh] w-full flex-col items-center justify-center px-lg py-xxxl text-center">
      <span className="flex size-14 shrink-0 items-center justify-center rounded-full bg-surface-tint text-muted">
        <Lock size={26} />
      </span>
      <h1 className="mt-lg text-title-md text-ink">
        {label ? t("noAccess.titleLabelled", { label }) : t("noAccess.title")}
      </h1>
      <p className="mt-xs max-w-content text-body-md text-muted">
        {t("noAccess.description")}
      </p>
      <Link
        href="/dashboard"
        className="mt-xl inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        {t("noAccess.backToDashboard")}
      </Link>
    </div>
  );
}

export function SectionGuard({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const pathname = usePathname();
  const area = areaForPath(pathname);

  if (!user || !area) return <>{children}</>;

  const needsManage = /\/(new|edit)$/.test(pathname);
  const allowed = needsManage ? canManage(user, area) : canView(user, area);

  if (allowed) return <>{children}</>;
  return <NoAccessView label={AREA_LABELS[area]} />;
}
