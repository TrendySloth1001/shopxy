"use client";

import { Tag } from "@/shared/icons";
import type { ProductOffer } from "../types";

interface Props {
  offers: ProductOffer[];
}

/**
 * Merchant-entered offers. Legacy `kind: "BANK"` rows are filtered out —
 * bank offers were removed from the platform.
 */
export function PdpOffersStrip({ offers }: Props) {
  const allOffers = offers.filter((o) => o.kind !== "COUPON" && o.kind !== "BANK");

  if (allOffers.length === 0) return null;

  return (
    <div className="border-t border-hairline px-lg py-md">
      <p className="mb-sm text-label-md font-extrabold text-ink">Available offers</p>
      <div className="flex flex-col gap-sm">
        {allOffers.slice(0, 4).map((offer, i) => (
          <div key={i} className="flex items-start gap-sm">
            <Tag size={14} className="mt-xxs shrink-0 text-success" aria-hidden />
            <div className="flex-1">
              <span className="text-body-md font-semibold text-ink">{offer.headline}</span>
              {offer.code ? (
                <span className="ml-xs rounded-xs bg-brand-soft px-xs py-[1px] text-label-md font-extrabold text-brand-strong">
                  {offer.code}
                </span>
              ) : null}
              {offer.description ? (
                <p className="mt-xxs text-body-sm text-muted">{offer.description}</p>
              ) : null}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
