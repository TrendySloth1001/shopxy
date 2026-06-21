import Link from "next/link";
import { Store } from "lucide-react";
import type { ShopSummary } from "../types";

/**
 * Seller identity disclosure (CP E-Commerce Rules r.5(3)/r.6(5)).
 *
 * A marketplace must let the buyer know WHO they are contracting with before
 * they purchase: the seller's legal name, principal geographic address, GSTIN
 * and a customer-care contact. We render whatever the shop payload carries and
 * mark the statutory fields that are not yet surfaced as "Not provided" rather
 * than hiding the block — so the disclosure is always present and visibly
 * incomplete until the backend payload is extended (tracked: LDC-7 follow-up).
 */
export function PdpSellerInfo({ shop }: { shop: ShopSummary }) {
  const location =
    shop.locationCity && shop.locationState
      ? `${shop.locationCity}, ${shop.locationState}`
      : shop.locationCity || shop.locationState || null;

  const rows: { label: string; value: string | null }[] = [
    { label: "Legal name", value: shop.legalName ?? shop.name },
    { label: "Registered address", value: shop.address ?? location },
    { label: "GSTIN", value: shop.gstin ?? null },
    {
      label: "Customer care",
      value: shop.supportEmail ?? shop.supportPhone ?? null,
    },
  ];

  return (
    <section className="mx-lg mb-md rounded-md border border-hairline bg-white p-md lg:mx-0">
      <div className="mb-sm flex items-center gap-sm">
        <Store size={14} className="text-brand" aria-hidden />
        <h2 className="text-label-md font-extrabold uppercase tracking-wide text-muted">
          Seller information
        </h2>
      </div>
      <dl className="grid grid-cols-[auto_1fr] gap-x-md gap-y-xs">
        {rows.map((r) => (
          <div key={r.label} className="contents">
            <dt className="text-label-md text-muted">{r.label}</dt>
            <dd
              className={
                r.value
                  ? "text-label-md font-semibold text-ink"
                  : "text-label-md italic text-subtle"
              }
            >
              {r.value ?? "Not provided"}
            </dd>
          </div>
        ))}
      </dl>
      <Link
        href={`/shop/${shop.slug}`}
        className="mt-sm inline-flex text-label-md font-bold text-brand-strong hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
      >
        View shop & policies
      </Link>
    </section>
  );
}
