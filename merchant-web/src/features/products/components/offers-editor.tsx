"use client";

import { Plus, X } from "lucide-react";
import type { ProductOffer } from "../schema";
import { MiniButton } from "./form-controls";

const OFFER_KINDS = ["BANK", "COUPON", "EMI", "EXCHANGE"] as const;
const cell =
  "h-10 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

/** Bank / coupon / EMI / exchange offers shown beneath the price. */
export function OffersEditor({
  offers,
  onChange,
}: {
  offers: ProductOffer[];
  onChange: (next: ProductOffer[]) => void;
}) {
  function patch(i: number, p: Partial<ProductOffer>) {
    onChange(offers.map((o, idx) => (idx === i ? { ...o, ...p } : o)));
  }
  return (
    <div className="flex flex-col gap-md">
      {offers.map((o, i) => (
        <div key={i} className="flex flex-wrap items-center gap-sm">
          <select
            value={o.kind}
            onChange={(e) => patch(i, { kind: e.target.value })}
            className={`${cell} w-32`}
          >
            {OFFER_KINDS.map((k) => (
              <option key={k} value={k}>
                {k}
              </option>
            ))}
          </select>
          <input
            value={o.headline}
            placeholder="Headline"
            onChange={(e) => patch(i, { headline: e.target.value })}
            className={`${cell} min-w-[200px] flex-1`}
          />
          <input
            value={o.code ?? ""}
            placeholder="Code (optional)"
            onChange={(e) => patch(i, { code: e.target.value })}
            className={`${cell} w-40`}
          />
          <button
            type="button"
            onClick={() => onChange(offers.filter((_, idx) => idx !== i))}
            aria-label="Remove offer"
            className="rounded-md p-sm text-muted hover:bg-surface-tint hover:text-ink"
          >
            <X size={16} />
          </button>
        </div>
      ))}
      <MiniButton
        onClick={() => onChange([...offers, { kind: "COUPON", headline: "", code: "" }])}
      >
        <Plus size={16} /> Add offer
      </MiniButton>
    </div>
  );
}
