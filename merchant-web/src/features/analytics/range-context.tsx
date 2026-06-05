"use client";

import { createContext, useContext, useMemo, useState, type ReactNode } from "react";
import { dateInputToIso, inputDateDaysAgo, startOfMonthInput, todayInputDate } from "@/shared/datetime";

type RangeValue = {
  /** `YYYY-MM-DD` for the date inputs. */
  from: string;
  to: string;
  /** UTC ISO range for the API (memoised). */
  iso: { from: string; to: string };
  setFrom: (v: string) => void;
  setTo: (v: string) => void;
  preset: (p: "7d" | "30d" | "month") => void;
};

const Ctx = createContext<RangeValue | null>(null);

/**
 * Shares the analytics date window across the tabbed sub-pages. Lives in the
 * analytics layout, which doesn't remount when switching tabs — so the chosen
 * range survives navigation between "By product" and "Overview".
 */
export function AnalyticsRangeProvider({ children }: { children: ReactNode }) {
  const [from, setFrom] = useState(() => inputDateDaysAgo(7));
  const [to, setTo] = useState(() => todayInputDate());

  const value = useMemo<RangeValue>(
    () => ({
      from,
      to,
      iso: { from: dateInputToIso(from), to: dateInputToIso(to, true) },
      setFrom,
      setTo,
      preset: (p) => {
        setTo(todayInputDate());
        setFrom(p === "month" ? startOfMonthInput() : p === "30d" ? inputDateDaysAgo(30) : inputDateDaysAgo(7));
      },
    }),
    [from, to],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAnalyticsRange(): RangeValue {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useAnalyticsRange must be used within <AnalyticsRangeProvider>");
  return ctx;
}
