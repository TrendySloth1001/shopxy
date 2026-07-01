"use client";

import { use, useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  ArrowLeft,
  Pencil,
  Trash2,
  PackagePlus,
  PackageMinus,
  Share2,
  Check,
  ImagePlus,
  ScrollText,
  ArrowUpRight,
  ArrowDownLeft,
  Eye,
} from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import {
  deleteProduct,
  getProduct,
  setPublished,
} from "@/features/products/api";
import type { Product } from "@/features/products/schema";
import { listInvoices, updateInvoiceStatus } from "@/features/invoices/api";
import {
  counterpartyName,
  invoiceItemCount,
  isSale,
  type Invoice,
} from "@/features/invoices/schema";
import { money, qty } from "@/features/products/format";
import { formatDateTime } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import { gstFromInclusive } from "@/features/products/gst";
import { unitLabel } from "@/features/products/units";
import { ProductThumb, mediaSrc } from "@/features/products/components/product-thumb";
import { StockBadge } from "@/features/products/components/stock-badge";
import { GstBreakdown } from "@/features/products/components/gst-breakdown";
import { ContentBlocksView } from "@/features/products/components/content-blocks-view";
import { SupplierPriceHistory } from "@/features/products/components/supplier-price-history";
import { ReviewsSummary } from "@/features/reviews/reviews-summary";
import { Stars } from "@/features/reviews/stars";
import { DetailSkeleton } from "@/shared/ui/skeleton";
import { useAuth } from "@/features/auth/auth-context";
import { canManage } from "@/features/auth/capabilities";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { StockSheet } from "@/features/stock/stock-sheet";
import { StockLedgerSheet } from "@/features/stock/stock-ledger-sheet";
import type { StockType } from "@/features/stock/schema";

export default function ProductDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const productId = Number(id);
  const router = useRouter();
  const { user } = useAuth();
  const t = useTranslations("products");
  const canStock = canManage(user, "stock");
  const canConfirmDraft = canManage(user, "invoices");

  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [busy, setBusy] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [stockSheet, setStockSheet] = useState<StockType | null>(null);
  const [ledgerOpen, setLedgerOpen] = useState(false);
  // The just-created draft (this session) — used to highlight + scroll its row.
  const [draftId, setDraftId] = useState<number | null>(null);
  // All unconfirmed drafts touching this product. Server-backed, so they
  // persist across reloads instead of vanishing with the in-session banner.
  const [drafts, setDrafts] = useState<Invoice[]>([]);
  const [copied, setCopied] = useState(false);
  const draftRef = useRef<HTMLDivElement>(null);

  // Pending DRAFT invoices that include this product. Re-fetched on `nonce` so a
  // fresh stock-in draft shows up immediately and a confirmed one drops off.
  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const list = await listInvoices({ status: "DRAFT", productId });
        if (active) setDrafts(list);
      } catch {
        // Non-fatal — the rest of the page works without the drafts panel.
        if (active) setDrafts([]);
      }
    })();
    return () => {
      active = false;
    };
  }, [productId, nonce]);

  // When a draft invoice is created, pull the panel into view (once its row has
  // loaded) so the merchant can't miss the "confirm to post stock" step — they
  // may be scrolled down the detail page after stocking in.
  useEffect(() => {
    if (draftId != null && draftRef.current) {
      draftRef.current.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }, [draftId, drafts]);

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
        if (active) setError(e instanceof Error ? e.message : t("detail.loadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [productId, nonce, t]);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  async function onShare() {
    try {
      await navigator.clipboard.writeText(window.location.href);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // clipboard blocked — no-op; the URL is already in the address bar.
    }
  }

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
      setError(e instanceof Error ? e.message : t("detail.deleteError"));
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
            {t("detail.skuPrefix")} {product.sku}
            {product.category?.name ? ` · ${product.category.name}` : ""}
          </p>
          {product.ratingCount > 0 ? (
            <div className="mt-xs flex items-center gap-sm">
              <Stars
                value={product.ratingAvg ?? 0}
                size={15}
                label={t("detail.ratingOutOf", { value: (product.ratingAvg ?? 0).toFixed(1) })}
              />
              <span className="text-body-sm text-muted">
                {(product.ratingAvg ?? 0).toFixed(1)} ·{" "}
                {product.ratingCount === 1
                  ? t("detail.ratingCountOne", { count: product.ratingCount })
                  : t("detail.ratingCountOther", { count: product.ratingCount })}
              </span>
            </div>
          ) : null}
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
            {product.isPublished ? t("detail.published") : t("detail.publish")}
          </button>
          <button
            type="button"
            onClick={onShare}
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            {copied ? <Check size={16} /> : <Share2 size={16} />}
            {copied ? t("detail.copied") : t("detail.share")}
          </button>
          <Link
            href={`/dashboard/products/${product.id}/edit`}
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Pencil size={16} /> {t("detail.edit")}
          </Link>
          {confirmDelete ? (
            <>
              <button
                type="button"
                onClick={onDelete}
                disabled={busy}
                className="inline-flex h-10 items-center gap-sm rounded-button bg-error px-md text-label-md text-white transition-colors hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error-soft disabled:bg-disabled"
              >
                <Trash2 size={16} /> {t("detail.confirmDelete")}
              </button>
              <button
                type="button"
                onClick={() => setConfirmDelete(false)}
                className="h-10 rounded-button px-md text-label-md text-muted hover:text-ink"
              >
                {t("detail.cancel")}
              </button>
            </>
          ) : (
            <button
              type="button"
              onClick={() => setConfirmDelete(true)}
              className="inline-flex h-10 items-center gap-sm rounded-button border border-error px-md text-label-md text-error transition-colors hover:bg-error-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error-soft"
            >
              <Trash2 size={16} /> {t("detail.delete")}
            </button>
          )}
        </div>
      </div>

      {error ? <p className="mt-md text-body-sm text-error">{error}</p> : null}

      {drafts.length > 0 ? (
        <section
          ref={draftRef}
          aria-label={t("detail.drafts.ariaLabel")}
          className="mt-md overflow-hidden rounded-lg border border-hairline bg-surface shadow-floating"
        >
          <div className="flex items-start gap-md border-b border-hairline bg-brand-soft px-lg py-md">
            <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-surface text-brand-strong">
              <ScrollText size={20} />
            </span>
            <div className="min-w-0">
              <p className="text-title-sm text-brand-strong">
                {drafts.length === 1
                  ? t("detail.drafts.countOne", { count: drafts.length })
                  : t("detail.drafts.countOther", { count: drafts.length })}
              </p>
              <p className="mt-xs text-body-sm text-ink">
                {t("detail.drafts.hint")}
              </p>
            </div>
          </div>
          <ul>
            {drafts.map((d) => (
              <li key={d.id}>
                <DraftRow
                  draft={d}
                  highlight={d.id === draftId}
                  canConfirm={canConfirmDraft}
                  onConfirmed={reload}
                />
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {stockSheet && canStock ? (
        <StockSheet
          product={product}
          initialType={stockSheet}
          onClose={() => setStockSheet(null)}
          onDone={(id) => {
            setStockSheet(null);
            setDraftId(id);
            reload();
          }}
        />
      ) : null}

      {ledgerOpen ? (
        <StockLedgerSheet
          productId={product.id}
          productName={product.name}
          productUnit={product.unit}
          onClose={() => setLedgerOpen(false)}
        />
      ) : null}

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
          <div className="flex flex-wrap items-center gap-sm">
            <MaybeLocked area="stock" label={t("detail.stockIn")}>
              <button
                type="button"
                onClick={() => setStockSheet("STOCK_IN")}
                className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                <PackagePlus size={16} /> {t("detail.stockIn")}
              </button>
            </MaybeLocked>
            <MaybeLocked area="stock" label={t("detail.stockOut")}>
              <button
                type="button"
                onClick={() => setStockSheet("STOCK_OUT")}
                className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                <PackageMinus size={16} /> {t("detail.stockOut")}
              </button>
            </MaybeLocked>
            <button
              type="button"
              onClick={() => setLedgerOpen(true)}
              className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
            >
              <ScrollText size={16} /> {t("detail.stockLedger")}
            </button>
          </div>
          <Divider />
          <Facts
            rows={[
              [t("detail.facts.purchasePrice"), money(product.purchasePrice)],
              [t("detail.facts.profitPerUnit"), money(product.sellingPrice - product.purchasePrice)],
              [
                t("detail.facts.margin"),
                product.sellingPrice > 0
                  ? `${Math.round(((product.sellingPrice - product.purchasePrice) / product.sellingPrice) * 100)}%`
                  : "—",
              ],
              [
                t("detail.facts.gst"),
                product.taxPercent > 0
                  ? `${product.taxPercent}% · ${money(gstFromInclusive(product.sellingPrice, product.taxPercent).gst)}`
                  : t("detail.facts.none"),
              ],
              [t("detail.facts.stock"), `${qty(product.stockQuantity)} ${unitLabel(product.unit)}`],
              [t("detail.facts.lowStockAt"), `${qty(product.lowStockThreshold)} ${unitLabel(product.unit)}`],
              [t("detail.facts.hsn"), product.hsnCode || "—"],
              [t("detail.facts.barcode"), product.barcode || "—"],
            ]}
          />
          <Divider />
          <div>
            <h2 className="text-title-sm text-ink">{t("detail.gstBreakdownHeading")}</h2>
            <div className="mt-md">
              <GstBreakdown
                sellingPrice={product.sellingPrice}
                taxPercent={product.taxPercent}
              />
            </div>
          </div>
        </div>
      </div>

      <Section title={t("detail.sections.supplierPriceHistory")}>
        <SupplierPriceHistory productId={product.id} unit={product.unit} />
      </Section>

      {product.description ? (
        <Section title={t("detail.sections.description")}>
          <p className="max-w-content whitespace-pre-line text-body-md text-ink">
            {product.description}
          </p>
        </Section>
      ) : null}

      {product.tags.length > 0 ? (
        <Section title={t("detail.sections.tags")}>
          <Chips items={product.tags} />
        </Section>
      ) : null}

      {product.highlights.length > 0 ? (
        <Section title={t("detail.sections.highlights")}>
          <ul className="list-disc space-y-xs pl-lg text-body-md text-ink">
            {product.highlights.map((h, i) => (
              <li key={i}>{h}</li>
            ))}
          </ul>
        </Section>
      ) : null}

      {product.specs.length > 0 ? (
        <Section title={t("detail.sections.specifications")}>
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
        <Section title={t("detail.sections.offers")}>
          <ul className="flex flex-col gap-sm">
            {product.offers.map((o, i) => (
              <li key={i} className="flex flex-wrap items-baseline gap-sm border-t border-hairline py-sm">
                <span className="rounded-full bg-accent-amber-soft px-sm py-px text-body-sm text-accent-amber">
                  {o.kind}
                </span>
                <span className="text-body-md text-ink">{o.headline}</span>
                {o.code ? <span className="text-body-sm text-muted">{t("detail.offerCode", { code: o.code })}</span> : null}
              </li>
            ))}
          </ul>
        </Section>
      ) : null}

      {product.variants.length > 1 ? (
        <Section title={t("detail.sections.variants", { count: product.variants.length })}>
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
        <Section title={t("detail.sections.aplusContent")}>
          <ContentBlocksView
            blocks={product.contentBlocks as Array<Record<string, unknown>>}
          />
        </Section>
      ) : null}

      <Section title={t("detail.sections.reviews")}>
        <ReviewsSummary productId={product.id} />
      </Section>
    </div>
  );
}

function BackLink() {
  const t = useTranslations("products");
  return (
    <Link
      href="/dashboard/products"
      className="inline-flex items-center gap-sm text-body-md text-muted transition-colors hover:text-ink"
    >
      <ArrowLeft size={16} /> {t("detail.backToProducts")}
    </Link>
  );
}

/** One pending-draft row inside the product detail's drafts panel. Mirrors the
 *  invoices-list row, with two actions: View (open the invoice) and Confirm
 *  (post the stock for this draft right here). */
function DraftRow({
  draft,
  highlight,
  canConfirm,
  onConfirmed,
}: {
  draft: Invoice;
  highlight: boolean;
  canConfirm: boolean;
  onConfirmed: () => void;
}) {
  const t = useTranslations("products");
  const sale = isSale(draft);
  const items = invoiceItemCount(draft);
  const label = draft.invoiceNo?.trim()
    ? draft.invoiceNo
    : t("detail.drafts.fallbackLabel", { id: draft.id });
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onConfirm() {
    setConfirming(true);
    setError(null);
    try {
      await updateInvoiceStatus(draft.id, "CONFIRMED");
      // Posting succeeded — refresh the product + drafts; this row drops off.
      onConfirmed();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("detail.drafts.confirmError"));
      setConfirming(false);
    }
  }

  return (
    <div
      className={`border-b border-hairline px-lg py-md last:border-b-0 ${
        highlight ? "bg-brand-soft" : ""
      }`}
    >
      <div className="flex flex-col gap-sm sm:flex-row sm:items-center sm:gap-md">
        <div className="flex min-w-0 flex-1 items-center gap-md">
          <span
            className={`flex size-10 shrink-0 items-center justify-center rounded-full ${
              sale ? "bg-success-soft text-success" : "bg-accent-indigo-soft text-accent-indigo"
            }`}
          >
            {sale ? <ArrowUpRight size={18} /> : <ArrowDownLeft size={18} />}
          </span>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-sm">
              <span className="truncate text-body-md text-ink">{label}</span>
              <span className="inline-flex items-center rounded-full bg-accent-amber-soft px-sm py-px text-body-sm font-semibold text-accent-amber">
                {t("detail.drafts.badge")}
              </span>
              {highlight ? (
                <span className="inline-flex items-center rounded-full bg-brand-soft px-sm py-px text-body-sm font-semibold text-brand-strong">
                  {t("detail.drafts.justCreated")}
                </span>
              ) : null}
            </div>
            <p className="truncate text-body-sm text-muted">{counterpartyName(draft)}</p>
            <p className="text-body-sm text-subtle">
              {formatDateTime(draft.invoiceDate)} ·{" "}
              {items === 1
                ? t("detail.drafts.itemCountOne", { count: items })
                : t("detail.drafts.itemCountOther", { count: items })}
            </p>
          </div>
        </div>
        <div className="flex shrink-0 flex-wrap items-center gap-sm sm:justify-end">
          <span className="mr-xs text-body-md font-semibold text-ink">
            {formatINR2(draft.total)}
          </span>
          <Link
            href={`/dashboard/invoices/${draft.id}`}
            className="inline-flex h-9 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Eye size={16} /> {t("detail.drafts.view")}
          </Link>
          {canConfirm ? (
            <button
              type="button"
              onClick={onConfirm}
              disabled={confirming}
              className="inline-flex h-9 items-center gap-xs rounded-button bg-brand-strong px-md text-label-md text-white transition-colors hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
            >
              <Check size={16} /> {confirming ? t("detail.drafts.confirming") : t("detail.drafts.confirm")}
            </button>
          ) : null}
        </div>
      </div>
      {error ? <p className="mt-sm text-body-sm text-error">{error}</p> : null}
    </div>
  );
}

function Gallery({ product }: { product: Product }) {
  const t = useTranslations("products");
  const [active, setActive] = useState(0);
  const images = product.images;
  if (images.length === 0) {
    return (
      <Link
        href={`/dashboard/products/${product.id}/edit`}
        className="group flex aspect-square w-full flex-col items-center justify-center gap-sm rounded-lg border border-dashed border-hairline text-muted transition-colors hover:border-brand hover:text-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        <ImagePlus size={32} />
        <span className="text-label-md">{t("detail.gallery.addPhotos")}</span>
        <span className="text-body-sm text-subtle">{t("detail.gallery.noImageYet")}</span>
      </Link>
    );
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
              aria-label={t("detail.gallery.imageLabel", { index: i + 1 })}
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
