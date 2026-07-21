"use client";

import { useTranslations } from "next-intl";
import { Plus, X } from "@/shared/icons";
import type { ProductOffer } from "../schema";
import { ComboSelect } from "@/shared/ui/combo-select";
import { MiniButton } from "./form-controls";

const OFFER_KINDS = ["BANK", "COUPON", "EMI", "EXCHANGE"] as const;
const cell =
  "h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

/** Bank / coupon / EMI / exchange offers shown beneath the price. */
export function OffersEditor({
  offers,
  onChange,
}: {
  offers: ProductOffer[];
  onChange: (next: ProductOffer[]) => void;
}) {
  const t = useTranslations("products");
  function patch(i: number, p: Partial<ProductOffer>) {
    onChange(offers.map((o, idx) => (idx === i ? { ...o, ...p } : o)));
  }
  return (
    <div className="flex flex-col gap-md">
      {offers.map((o, i) => (
        <div key={i} className="flex flex-wrap items-center gap-sm">
          <ComboSelect
            ariaLabel={t("offers.kindLabel")}
            value={o.kind}
            onChange={(v) => patch(i, { kind: v })}
            options={OFFER_KINDS.map((k) => ({ value: k, label: k }))}
            className="w-32"
          />
          <input
            value={o.headline}
            placeholder={t("offers.headlinePlaceholder")}
            onChange={(e) => patch(i, { headline: e.target.value })}
            className={`${cell} min-w-[200px] flex-1`}
          />
          <input
            value={o.code ?? ""}
            placeholder={t("offers.codePlaceholder")}
            onChange={(e) => patch(i, { code: e.target.value })}
            className={`${cell} w-40`}
          />
          <button
            type="button"
            onClick={() => onChange(offers.filter((_, idx) => idx !== i))}
            aria-label={t("offers.removeOffer")}
            className="rounded-md p-sm text-muted hover:bg-surface-tint hover:text-ink"
          >
            <X size={16} />
          </button>
        </div>
      ))}
      <MiniButton
        onClick={() => onChange([...offers, { kind: "COUPON", headline: "", code: "" }])}
      >
        <Plus size={16} /> {t("offers.addOffer")}
      </MiniButton>
    </div>
  );
}
