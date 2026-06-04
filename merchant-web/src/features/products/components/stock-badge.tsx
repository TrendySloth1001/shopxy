import type { Product } from "../schema";
import { qty, stockState } from "../format";
import { unitLabel } from "../units";

/** Compact stock indicator — soft fill, no border (house style). */
export function StockBadge({ product }: { product: Product }) {
  const state = stockState(product);
  const styles =
    state === "out"
      ? "bg-error-soft text-error"
      : state === "low"
        ? "bg-warning-soft text-warning"
        : "bg-success-soft text-success";
  const label =
    state === "out"
      ? "Out of stock"
      : `${qty(product.stockQuantity)} ${unitLabel(product.unit)}`;
  return (
    <span
      className={`inline-flex items-center rounded-full px-sm py-px text-body-sm tabular-nums ${styles}`}
    >
      {label}
    </span>
  );
}
