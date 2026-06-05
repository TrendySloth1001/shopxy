import { windowState } from "@/shared/datetime";
import type { Promotion } from "./schema";

const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  minimumFractionDigits: 2,
});

/** Paise → "₹12.34". */
export function rupees(paise: number): string {
  return inr.format(paise / 100);
}

export function spendPctOfBudget(p: Promotion): number {
  if (p.budgetPaise <= 0) return 0;
  return Math.max(0, Math.min(1, p.spendPaise / p.budgetPaise));
}

export function spendPctOfDailyCap(p: Promotion): number {
  if (p.dailyCapPaise <= 0) return 0;
  return Math.max(0, Math.min(1, p.spendTodayPaise / p.dailyCapPaise));
}

/** Human status, mirroring the Flutter `Promotion.statusLabel`. */
export function statusLabel(p: Promotion, now: Date = new Date()): string {
  if (!p.isActive) {
    switch (p.pausedReason) {
      case "budget_exhausted":
        return "Budget exhausted";
      case "daily_cap_reached":
        return "Daily cap reached";
      case "window_ended":
        return "Ended";
      case "cancelled_by_merchant":
        return "Cancelled";
      default:
        return "Paused";
    }
  }
  const state = windowState(p.startAt, p.endAt, now);
  if (state === "scheduled") return "Scheduled";
  if (state === "ended") return "Ended";
  return "Live";
}
