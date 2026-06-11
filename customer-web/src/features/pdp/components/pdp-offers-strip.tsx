"use client";

import { Tag, CreditCard } from "lucide-react";
import type { ProductOffer, BankOffer } from "../types";

interface Props {
  offers: ProductOffer[];
  bankOffers: BankOffer[];
}

export function PdpOffersStrip({ offers, bankOffers }: Props) {
  const allOffers = [
    ...offers.filter((o) => o.kind !== "COUPON"),
    ...bankOffers.map((b) => ({
      kind: "BANK",
      headline: b.headline,
      code: null,
      description: b.description ?? null,
    })),
  ];

  if (allOffers.length === 0) return null;

  return (
    <div className="border-t border-hairline px-lg py-md">
      <p className="mb-sm text-label-md font-extrabold text-ink">Available offers</p>
      <div className="flex flex-col gap-sm">
        {allOffers.slice(0, 4).map((offer, i) => (
          <div key={i} className="flex items-start gap-sm">
            {offer.kind === "BANK" ? (
              <CreditCard size={14} className="mt-[2px] shrink-0 text-info" aria-hidden />
            ) : (
              <Tag size={14} className="mt-[2px] shrink-0 text-success" aria-hidden />
            )}
            <div className="flex-1">
              <span className="text-body-md font-semibold text-ink">{offer.headline}</span>
              {offer.code ? (
                <span className="ml-xs rounded-xs bg-brand-soft px-xs py-[1px] text-label-md font-extrabold text-brand-strong">
                  {offer.code}
                </span>
              ) : null}
              {offer.description ? (
                <p className="mt-[2px] text-body-sm text-muted">{offer.description}</p>
              ) : null}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
