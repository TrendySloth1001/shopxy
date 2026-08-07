"use client";

import { useTranslations } from "next-intl";
import { dayLabel } from "@/shared/datetime";

/**
 * A centred label between two hairlines — the one way a dated list here breaks
 * into day groups.
 *
 * Mirrors the Flutter merchant app's `SectionDivider.date` (same relative
 * "Today" / "Yesterday" wording, same day boundary) so a merchant reads the
 * same grouping whichever app they're in. Shared rather than inlined so the
 * other dated lists can adopt it without the two drifting apart.
 *
 * Rows must be sorted by the same date this groups on, otherwise a heading
 * repeats further down the scroll.
 */
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
