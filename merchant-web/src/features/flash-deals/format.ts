import { windowState } from "@/shared/datetime";
import type { FlashSale, FlashStatus } from "./schema";

export { money } from "@/features/products/format";

/** Whole-percent discount off MRP (0 when MRP unknown). */
export function discountPct(mrp: number, flashPrice: number): number {
  if (mrp <= 0) return 0;
  return Math.round(((mrp - flashPrice) / mrp) * 100);
}

/** Fraction sold (0..1). */
export function soldPct(sale: Pick<FlashSale, "soldCount" | "stockLimit">): number {
  if (sale.stockLimit <= 0) return 0;
  return Math.max(0, Math.min(1, sale.soldCount / sale.stockLimit));
}

/**
 * Bucket a sale into a tab, matching the backend `listForShop` filters:
 *   active    = isActive && now ∈ [start, end]
 *   scheduled = isActive && start > now
 *   past      = !isActive || end < now
 */
export function flashBucket(sale: FlashSale, now: Date = new Date()): FlashStatus {
  if (!sale.isActive) return "past";
  const state = windowState(sale.startAt, sale.endAt, now);
  if (state === "scheduled") return "scheduled";
  if (state === "ended") return "past";
  return "active";
}
