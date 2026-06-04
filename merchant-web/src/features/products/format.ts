import type { Product } from "./schema";
import { unitLabel } from "./units";

const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  minimumFractionDigits: 2,
});

export function money(n: number): string {
  return inr.format(n);
}

/** Whole number when integral, else 2dp. */
export function qty(n: number): string {
  return Number.isInteger(n) ? n.toString() : n.toFixed(2);
}

export type StockState = "out" | "low" | "healthy";

export function stockState(p: Pick<Product, "stockQuantity" | "lowStockThreshold">): StockState {
  if (p.stockQuantity <= 0) return "out";
  if (p.stockQuantity <= p.lowStockThreshold) return "low";
  return "healthy";
}

export function unitName(code: string): string {
  return unitLabel(code);
}
