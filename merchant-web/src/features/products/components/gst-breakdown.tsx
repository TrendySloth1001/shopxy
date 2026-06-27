import { money } from "../format";
import { gstFromInclusive } from "../gst";

/**
 * Breaks a GST-inclusive selling price into its taxable value and CGST/SGST
 * components so the merchant can see exactly how much of the price is tax —
 * instead of a bare "18%". Catalogue prices are tax-inclusive, so this backs
 * the GST out of the price rather than adding it on top.
 */
export function GstBreakdown({
  sellingPrice,
  taxPercent,
}: {
  sellingPrice: number;
  taxPercent: number;
}) {
  if (!taxPercent || taxPercent <= 0) {
    return (
      <p className="text-body-sm text-muted">
        No GST applied — the full {money(sellingPrice)} is the taxable value.
      </p>
    );
  }

  const b = gstFromInclusive(sellingPrice, taxPercent);
  const half = taxPercent / 2;

  return (
    <dl className="flex flex-col gap-xs">
      <Row label="Taxable value" hint="price before GST" value={money(b.taxable)} />
      <Row label={`CGST @ ${formatRate(half)}%`} value={money(b.cgst)} />
      <Row label={`SGST @ ${formatRate(half)}%`} value={money(b.sgst)} />
      <Row
        label={`Total GST @ ${formatRate(taxPercent)}%`}
        value={money(b.gst)}
        strong
      />
      <div className="mt-xs flex items-baseline justify-between gap-md border-t border-hairline pt-sm">
        <dt className="text-body-md text-ink">Selling price (incl. GST)</dt>
        <dd className="text-title-sm tabular-nums text-ink">{money(sellingPrice)}</dd>
      </div>
      <p className="mt-xs text-body-sm text-subtle">
        Prices include GST. CGST + SGST shown for a sale within your state; a sale
        to another state is charged the same total as IGST.
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
