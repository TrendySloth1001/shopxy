import { useTranslations } from "next-intl";
import { money } from "../format";
import { gstBreakdownForProduct, type ProductPricingMode } from "../gst";

/**
 * Breaks a selling price into its taxable value and CGST/SGST components so
 * the merchant can see exactly how much of the price is tax — instead of a
 * bare "18%". Mode-aware: TAX_INCLUSIVE backs GST out of the price,
 * TAX_EXCLUSIVE adds it on top, NO_GST (or a zero rate under any mode) shows
 * the plain no-tax line — matching whichever convention this product will
 * actually be billed under.
 */
export function GstBreakdown({
  sellingPrice,
  taxPercent,
  pricingMode,
}: {
  sellingPrice: number;
  taxPercent: number;
  pricingMode: ProductPricingMode;
}) {
  const t = useTranslations("products");
  const b = gstBreakdownForProduct(sellingPrice, taxPercent, pricingMode);
  if (!b) {
    return (
      <p className="text-body-sm text-muted">
        {t("gstBreakdown.noGst", { price: money(sellingPrice) })}
      </p>
    );
  }

  const inclusive = pricingMode === "TAX_INCLUSIVE";
  const half = taxPercent / 2;

  return (
    <dl className="flex flex-col gap-xs">
      <Row label={t("gstBreakdown.taxableValue")} hint={t("gstBreakdown.taxableHint")} value={money(b.taxable)} />
      <Row label={t("gstBreakdown.cgst", { rate: formatRate(half) })} value={money(b.cgst)} />
      <Row label={t("gstBreakdown.sgst", { rate: formatRate(half) })} value={money(b.sgst)} />
      <Row
        label={t("gstBreakdown.totalGst", { rate: formatRate(taxPercent) })}
        value={money(b.gst)}
        strong
      />
      <div className="mt-xs flex items-baseline justify-between gap-md border-t border-hairline pt-sm">
        <dt className="text-body-md text-ink">
          {t(inclusive ? "gstBreakdown.sellingPriceInclGst" : "gstBreakdown.totalPayableExclGst")}
        </dt>
        <dd className="text-title-sm tabular-nums text-ink">{money(b.totalPayable)}</dd>
      </div>
      <p className="mt-xs text-body-sm text-subtle">
        {t(inclusive ? "gstBreakdown.explainer" : "gstBreakdown.explainerExclusive")}
      </p>
    </dl>
  );
}

function Row({
  label,
  hint,
  value,
  strong = false,
}: {
  label: string;
  hint?: string;
  value: string;
  strong?: boolean;
}) {
  return (
    <div className="flex items-baseline justify-between gap-md">
      <dt className={`text-body-sm ${strong ? "text-ink" : "text-muted"}`}>
        {label}
        {hint ? <span className="text-subtle"> · {hint}</span> : null}
      </dt>
      <dd
        className={`tabular-nums ${
          strong ? "text-body-md text-ink" : "text-body-sm text-ink"
        }`}
      >
        {value}
      </dd>
    </div>
  );
}

/** Whole-number rates show as "9", fractional as "2.5". */
function formatRate(n: number): string {
  return Number.isInteger(n) ? n.toString() : n.toFixed(2).replace(/\.?0+$/, "");
}
