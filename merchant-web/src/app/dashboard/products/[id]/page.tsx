"use client";

import { use, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft, Pencil, Trash2 } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import {
  deleteProduct,
  getProduct,
  setPublished,
} from "@/features/products/api";
import type { Product } from "@/features/products/schema";
import { money, qty } from "@/features/products/format";
import { unitLabel } from "@/features/products/units";
import { ProductThumb, mediaSrc } from "@/features/products/components/product-thumb";
import { StockBadge } from "@/features/products/components/stock-badge";
import { ContentBlocksView } from "@/features/products/components/content-blocks-view";
import { DetailSkeleton } from "@/shared/ui/skeleton";

export default function ProductDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const productId = Number(id);
  const router = useRouter();

  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [busy, setBusy] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const p = await getProduct(productId);
        if (active) {
          setProduct(p);
          setError(null);
        }
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the product.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [productId, nonce]);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  async function onTogglePublish() {
    if (!product) return;
    setBusy(true);
    try {
      const updated = await setPublished(product.id, !product.isPublished);
      setProduct(updated);
    } catch {
      reload();
    } finally {
      setBusy(false);
    }
  }

  async function onDelete() {
    if (!product) return;
    setBusy(true);
    try {
      await deleteProduct(product.id);
      router.replace("/dashboard/products");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not delete the product.");
      setBusy(false);
    }
  }

  if (loading) {
    return <DetailSkeleton />;
  }
  if (error && !product) {
    return (
      <div className="px-lg py-xxl md:px-xxl">
        <BackLink />
        <p className="mt-lg text-body-md text-muted">{error}</p>
      </div>
    );
  }
  if (!product) return null;

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <BackLink />

      {/* Header */}
      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="min-w-0">
          {product.brand ? (
            <p className="text-label-md uppercase tracking-wide text-muted">
              {product.brand}
            </p>
          ) : null}
          <h1 className="text-headline-md text-ink">{product.name}</h1>
          <p className="mt-xs text-body-md text-muted">
            SKU {product.sku}
            {product.category?.name ? ` · ${product.category.name}` : ""}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-sm">
          <button
            type="button"
            onClick={onTogglePublish}
            disabled={busy}
            className={`h-10 rounded-button px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled ${
              product.isPublished
                ? "bg-brand-soft text-brand-strong"
                : "border border-hairline text-ink hover:bg-surface-tint"
            }`}
          >
            {product.isPublished ? "Published" : "Publish"}
          </button>
          <Link
            href={`/dashboard/products/${product.id}/edit`}
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Pencil size={16} /> Edit
          </Link>
          {confirmDelete ? (
            <>
              <button
                type="button"
                onClick={onDelete}
                disabled={busy}
                className="inline-flex h-10 items-center gap-sm rounded-button bg-error px-md text-label-md text-white transition-colors hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error-soft disabled:bg-disabled"
              >
                <Trash2 size={16} /> Confirm delete
              </button>
              <button
                type="button"
                onClick={() => setConfirmDelete(false)}
                className="h-10 rounded-button px-md text-label-md text-muted hover:text-ink"
              >
                Cancel
              </button>
            </>
          ) : (
            <button
              type="button"
              onClick={() => setConfirmDelete(true)}
              className="inline-flex h-10 items-center gap-sm rounded-button border border-error px-md text-label-md text-error transition-colors hover:bg-error-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error-soft"
            >
              <Trash2 size={16} /> Delete
            </button>
          )}
        </div>
      </div>

      {error ? <p className="mt-md text-body-sm text-error">{error}</p> : null}

      <Divider className="my-xxl" />

      {/* Gallery + key facts */}
      <div className="grid gap-xxl lg:grid-cols-[2fr_3fr]">
        <Gallery product={product} />
        <div className="flex flex-col gap-lg">
          <div className="flex items-end gap-md">
            <span className="text-display-sm tabular-nums text-ink">
              {money(product.sellingPrice)}
            </span>
            {product.mrp > product.sellingPrice ? (
              <span className="pb-xs text-body-lg tabular-nums text-subtle line-through">
                {money(product.mrp)}
              </span>
            ) : null}
          </div>
          <StockBadge product={product} />
          <Divider />
          <Facts
            rows={[
              ["Purchase price", money(product.purchasePrice)],
              ["Profit / unit", money(product.sellingPrice - product.purchasePrice)],
              [
                "Margin",
                product.sellingPrice > 0
                  ? `${Math.round(((product.sellingPrice - product.purchasePrice) / product.sellingPrice) * 100)}%`
                  : "—",
              ],
              ["Tax", `${product.taxPercent}%`],
              ["Stock", `${qty(product.stockQuantity)} ${unitLabel(product.unit)}`],
              ["Low-stock at", `${qty(product.lowStockThreshold)} ${unitLabel(product.unit)}`],
              ["HSN", product.hsnCode || "—"],
              ["Barcode", product.barcode || "—"],
            ]}
          />
        </div>
      </div>

      {product.description ? (
        <Section title="Description">
          <p className="max-w-content whitespace-pre-line text-body-md text-ink">
            {product.description}
          </p>
        </Section>
      ) : null}

      {product.tags.length > 0 ? (
        <Section title="Tags">
          <Chips items={product.tags} />
        </Section>
      ) : null}

      {product.highlights.length > 0 ? (
        <Section title="Highlights">
          <ul className="list-disc space-y-xs pl-lg text-body-md text-ink">
            {product.highlights.map((h, i) => (
              <li key={i}>{h}</li>
            ))}
          </ul>
        </Section>
      ) : null}

      {product.specs.length > 0 ? (
        <Section title="Specifications">
          <div className="flex flex-col gap-lg">
            {product.specs.map((g, gi) => (
              <div key={gi}>
                <p className="text-title-sm text-ink">{g.title}</p>
                <dl className="mt-sm grid gap-x-xxl gap-y-xs sm:grid-cols-2">
                  {g.rows.map((r, ri) => (
                    <div key={ri} className="flex justify-between gap-md border-b border-hairline py-xs">
                      <dt className="text-body-sm text-muted">{r.label}</dt>
                      <dd className="text-body-sm text-ink">{r.value}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            ))}
          </div>
        </Section>
      ) : null}

      {product.offers.length > 0 ? (
        <Section title="Offers">
          <ul className="flex flex-col gap-sm">
            {product.offers.map((o, i) => (
              <li key={i} className="flex flex-wrap items-baseline gap-sm border-t border-hairline py-sm">
                <span className="rounded-full bg-accent-amber-soft px-sm py-px text-body-sm text-accent-amber">
                  {o.kind}
                </span>
                <span className="text-body-md text-ink">{o.headline}</span>
                {o.code ? <span className="text-body-sm text-muted">Code: {o.code}</span> : null}
              </li>
            ))}
          </ul>
        </Section>
      ) : null}

      {product.variants.length > 1 ? (
        <Section title={`Variants (${product.variants.length})`}>
          <ul>
            {product.variants.map((v) => (
              <li key={v.id ?? v.sku} className="flex items-center gap-md border-t border-hairline py-sm">
                <span className="min-w-0 flex-1 truncate text-body-md text-ink">
                  {Object.values(v.attributes).join(" / ") || v.sku}
                </span>
                <span className="text-body-sm text-muted">{v.sku}</span>
                <span className="w-24 text-right text-body-md tabular-nums text-ink">
                  {money(v.sellingPrice)}
                </span>
                <span className="w-16 text-right text-body-sm tabular-nums text-muted">
                  {qty(v.stockQuantity)}
                </span>
              </li>
            ))}
          </ul>
        </Section>
      ) : null}

      {product.contentBlocks.length > 0 ? (
        <Section title="A+ content">
          <ContentBlocksView
            blocks={product.contentBlocks as Array<Record<string, unknown>>}
          />
        </Section>
      ) : null}
    </div>
  );
}

function BackLink() {
  return (
    <Link
      href="/dashboard/products"
      className="inline-flex items-center gap-sm text-body-md text-muted transition-colors hover:text-ink"
    >
      <ArrowLeft size={16} /> Products
    </Link>
  );
}

function Gallery({ product }: { product: Product }) {
  const [active, setActive] = useState(0);
  const images = product.images;
  if (images.length === 0) {
    return <ProductThumb url={null} alt={product.name} size={320} />;
  }
  const main = images[active] ?? images[0];
  return (
    <div className="flex flex-col gap-md">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={mediaSrc(main.url) ?? ""}
        alt={product.name}
        className="aspect-square w-full rounded-lg border border-hairline object-cover"
      />
      {images.length > 1 ? (
        <div className="flex flex-wrap gap-sm">
          {images.map((img, i) => (
            <button
              key={img.id}
              type="button"
              onClick={() => setActive(i)}
              aria-label={`Image ${i + 1}`}
              className={`rounded-md ${i === active ? "ring-2 ring-brand" : ""}`}
            >
              <ProductThumb url={img.url} alt={product.name} size={56} />
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function Facts({ rows }: { rows: Array<[string, string]> }) {
  return (
    <dl className="grid grid-cols-2 gap-x-xxl gap-y-md">
      {rows.map(([label, value]) => (
        <div key={label} className="flex flex-col gap-px">
          <dt className="text-label-md text-subtle">{label}</dt>
          <dd className="text-body-md tabular-nums text-ink">{value}</dd>
        </div>
      ))}
    </dl>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="py-xl">
      <Divider className="mb-xl" />
      <h2 className="text-title-md text-ink">{title}</h2>
      <div className="mt-md">{children}</div>
    </section>
  );
}

function Chips({ items }: { items: string[] }) {
  return (
    <div className="flex flex-wrap gap-sm">
      {items.map((t, i) => (
        <span key={i} className="rounded-full bg-surface-tint px-md py-px text-body-sm text-ink">
          {t}
        </span>
      ))}
    </div>
  );
}
