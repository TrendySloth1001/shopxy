import Link from "next/link";
import { Store } from "@/shared/icons";
import type { ShopSummary } from "../types";

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
