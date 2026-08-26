"use client";

import { useTranslations } from "next-intl";
import { dayLabel } from "@/shared/datetime";

export function DayDivider({ date }: { date: Date }) {
  const t = useTranslations("common.day");
  return (
    <div className="flex items-center gap-md py-sm">
      <span className="h-px flex-1 bg-hairline" />
      <span className="text-label-md font-semibold text-muted">
        {dayLabel(date, { today: t("today"), yesterday: t("yesterday") })}
      </span>
      <span className="h-px flex-1 bg-hairline" />
    </div>
  );
}
