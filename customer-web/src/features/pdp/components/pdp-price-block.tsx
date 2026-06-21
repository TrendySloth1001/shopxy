import { Truck, RotateCcw, ShieldCheck } from "lucide-react";
import { formatINR } from "@/shared/format";
import { type ProductDetail, type Variant } from "../types";

interface Props {
  product: ProductDetail;
  selectedVariant: Variant | null;
}

// ── Assurance block (delivery / returns / authentic) ──────────────────────────

function AssuranceBlock() {
  // Shop returns info is not on the PDP payload — show generic trust copy
  const rows: { icon: React.ReactNode; text: React.ReactNode }[] = [
    {
      icon: <Truck size={14} className="text-brand" aria-hidden />,
      text: (
        <span>
          Free delivery{" "}
          <span className="font-normal text-muted">· 3–5 days · merchant confirms</span>
        </span>
      ),
    },
    {
      icon: <RotateCcw size={14} className="text-brand" aria-hidden />,
      text: <span>7-day returns</span>,
    },
    {
      icon: <ShieldCheck size={14} className="text-brand" aria-hidden />,
      text: <span>100% authentic</span>,
    },
  ];

  return (
    <div className="mx-0 mt-sm rounded-md border border-hairline bg-white">
      {rows.map((row, i) => (
        <div key={i}>
          {i > 0 ? <div className="mx-md border-t border-hairline" /> : null}
          <div className="flex items-center gap-sm px-md py-sm">
            <span className="flex w-5 shrink-0 items-center justify-center">{row.icon}</span>
            <span className="text-body-sm font-semibold text-ink">{row.text}</span>
          </div>
        </div>
      ))}
    </div>
  );
}

export function PdpPriceBlock({ product, selectedVariant }: Props) {
  const displayPrice = selectedVariant?.sellingPrice ?? product.sellingPrice;
  const baseMrp = selectedVariant?.mrp ?? product.mrp;

  const isDiscounted = baseMrp > 0 && baseMrp > displayPrice;
  const pct = isDiscounted ? Math.round(((baseMrp - displayPrice) / baseMrp) * 100) : 0;
  const savedAmount = isDiscounted ? baseMrp - displayPrice : 0;

  return (
    <div className="px-lg pb-sm pt-xs">
      <div className="flex flex-wrap items-end gap-sm">
        <span className="text-[26px] font-black leading-none tracking-tight text-ink">
          {formatINR(displayPrice)}
        </span>
        {isDiscounted ? (
          <>
            <span className="mb-[2px] text-body-md text-muted line-through">
              M.R.P. {formatINR(baseMrp)}
            </span>
            <span className="mb-[2px] rounded-xs bg-success-soft px-sm py-xs text-label-md font-extrabold text-success">
              {pct}% off
            </span>
          </>
        ) : null}
      </div>
      {isDiscounted && savedAmount > 0 ? (
        <div className="mt-sm inline-flex items-center gap-xs rounded-full bg-success-soft px-md py-xs">
          <span className="text-label-md font-extrabold text-success">
            You save {formatINR(savedAmount)} ({pct}%)
          </span>
        </div>
      ) : null}
      {/* MRP is ALWAYS shown and labelled inclusive of all taxes (Legal
          Metrology). When discounted the struck-through M.R.P. above already
          carries it; otherwise show an explicit MRP line so the consumer
          always sees the maximum retail price. */}
      {!isDiscounted ? (
        <p className="mt-xs text-label-md text-muted">
          M.R.P. {formatINR(baseMrp)} · inclusive of all taxes
        </p>
      ) : (
        <p className="mt-xs text-label-md text-muted">Inclusive of all taxes</p>
      )}

      {/* Legal Metrology / consumer disclosures — country of origin + net
          quantity where available, shown before add-to-cart. */}
      <ComplianceBlock product={product} />

      {/* Assurance rows: free delivery · returns · authentic */}
      <AssuranceBlock />
    </div>
  );
}

// ── Compliance disclosures (country of origin, net quantity) ──────────────────

function ComplianceBlock({ product }: { product: ProductDetail }) {
  const rows: { label: string; value: string }[] = [];
  if (product.countryOfOrigin) {
    rows.push({ label: "Country of origin", value: product.countryOfOrigin });
  }
  if (product.unit) {
    rows.push({ label: "Net quantity", value: product.unit });
  }
  if (product.brand) {
    rows.push({ label: "Marketed by", value: product.brand });
  }
  if (rows.length === 0) return null;

  return (
    <dl className="mt-sm grid grid-cols-[auto_1fr] gap-x-md gap-y-xs">
      {rows.map((r) => (
        <div key={r.label} className="contents">
          <dt className="text-label-md text-muted">{r.label}</dt>
          <dd className="text-label-md font-semibold text-ink">{r.value}</dd>
        </div>
      ))}
    </dl>
  );
}
