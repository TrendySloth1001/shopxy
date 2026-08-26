"use client";

import type { ReactNode } from "react";
import { useTranslations } from "next-intl";
import { Lock } from "@/shared/icons";
import { useAuth } from "../auth-context";
import { canManage, canView } from "../capabilities";
import type { Area } from "@/features/team/permissions";

export function MaybeLocked({
  area,
  action = "manage",
  label,
  children,
}: {
  area: Area;
  action?: "view" | "manage";
  label?: string;
  children: ReactNode;
}) {
  const { user } = useAuth();
  const t = useTranslations("auth");
  const allowed = action === "view" ? canView(user, area) : canManage(user, area);
  if (allowed) return <>{children}</>;

  return (
    <span
      aria-disabled="true"
      title={t("locked.tooltip")}
      className="inline-flex h-10 cursor-not-allowed items-center gap-xs rounded-button border border-hairline px-md text-label-md text-disabled"
    >
      <Lock size={14} className="shrink-0" />
      {label ?? t("locked.label")}
    </span>
  );
}
