"use client";

import { useEffect, useState, useCallback, useRef, startTransition } from "react";
import { useParams, useRouter } from "next/navigation";
import { Search, AlertCircle, Package, Plus, Minus, ShoppingBag } from "lucide-react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { fetchCatalogProducts, requestQuotation } from "@/features/merchant-ledger/api";
import { SkeletonBlock, SkeletonLine, Snackbar, type SnackMsg } from "@/features/merchant-ledger/components/shared";
import type { CatalogProduct, BasketItem } from "@/features/merchant-ledger/types";
import { formatINR } from "@/shared/format";

// ─── Skeleton ─────────────────────────────────────────────────────────────────

function CatalogueSkeleton() {
  return (
    <div className="flex flex-col h-full">
      {/* Fake search bar */}
      <div className="px-lg py-sm">
        <SkeletonBlock className="h-10 w-full rounded-input" />
      </div>
      {/* Chip rail */}
      <div className="flex gap-sm overflow-hidden px-lg pb-sm">
        {["w-14", "w-18", "w-16", "w-20", "w-16"].map((wCls, i) => (
          <SkeletonBlock key={i} className={`h-7 shrink-0 rounded-full ${wCls}`} />
        ))}
      </div>
      <div className="h-px bg-hairline" />
      {/* Product rows */}
      <div className="flex-1 overflow-y-auto divide-y divide-hairline">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="flex items-center gap-md px-lg py-md">
            <SkeletonBlock className="h-12 w-12 rounded-md shrink-0" />
            <div className="flex-1 space-y-xs">
              <SkeletonLine className="h-4 w-[70%]" />
              <SkeletonLine className="h-3 w-[50%]" />
              <SkeletonLine className="h-3 w-[40%]" />
            </div>
            <SkeletonBlock className="h-8 w-14 rounded-full shrink-0" />
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Category chip ────────────────────────────────────────────────────────────

function CategoryChip({
  label,
  count,
  selected,
  onTap,
}: {
  label: string;
  count: number;
  selected: boolean;
  onTap: () => void;
}) {
  return (
    <button
      onClick={onTap}
      className={`inline-flex h-7 shrink-0 items-center gap-xs rounded-full px-md text-body-sm font-bold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
        selected
          ? "bg-ink text-white"
          : "border border-hairline bg-white text-ink hover:bg-surface-tint"
      }`}
    >
      {label}
      <span className={selected ? "text-white/70" : "text-muted"}>{count}</span>
    </button>
  );
}

// ─── Quantity stepper ────────────────────────────────────────────────────────

function Stepper({ qty, onChange }: { qty: number; onChange: (q: number) => void }) {
  return (
    <div className="flex items-center gap-xs rounded-full bg-brand-soft px-xs">
      <button
        onClick={() => onChange(qty - 1)}
        className="flex h-7 w-7 items-center justify-center rounded-full text-brand-strong hover:bg-brand/20 focus-visible:outline-none"
      >
        <Minus size={14} />
      </button>
      <span className="w-5 text-center text-body-sm font-extrabold text-brand-strong tabular-nums">
        {qty}
      </span>
      <button
        onClick={() => onChange(qty + 1)}
        className="flex h-7 w-7 items-center justify-center rounded-full text-brand-strong hover:bg-brand/20 focus-visible:outline-none"
      >
        <Plus size={14} />
      </button>
    </div>
  );
}

// ─── Product row ─────────────────────────────────────────────────────────────

function ProductRow({
  product,
  qty,
  onQtyChange,
}: {
  product: CatalogProduct;
  qty: number;
  onQtyChange: (q: number) => void;
}) {
  const imgUrl = product.images?.[0]?.url
    ? product.images[0].url.startsWith("/images/")
      ? `/api/media${product.images[0].url}`
      : product.images[0].url
    : null;

  return (
    <div
      className={`flex items-center gap-md px-lg py-md transition-colors ${
        qty > 0 ? "bg-brand-soft/30" : ""
      }`}
    >
      {/* Thumbnail */}
      {imgUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={imgUrl}
          alt={product.name}
          className="h-12 w-12 shrink-0 rounded-md object-cover bg-hero-panel"
        />
      ) : (
        <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-md bg-brand-soft">
          <Package size={20} className="text-brand" />
        </span>
      )}

      {/* Info */}
      <div className="flex-1 min-w-0">
        <p className="text-body-md font-bold text-ink leading-snug truncate">{product.name}</p>
        <div className="flex items-baseline gap-xs mt-[2px]">
          <span className="text-body-sm font-extrabold text-ink">
            {formatINR(product.sellingPrice)}
          </span>
          <span className="text-body-sm text-muted">/ {product.unit}</span>
          {product.mrp > product.sellingPrice && (
            <span className="text-body-sm text-subtle line-through">
              {formatINR(product.mrp)}
            </span>
          )}
        </div>
        {product.sku && <p className="text-body-sm text-muted mt-[1px]">SKU: {product.sku}</p>}
      </div>

      {/* Qty control */}
      {qty === 0 ? (
        <button
          onClick={() => onQtyChange(1)}
          className="inline-flex h-8 shrink-0 items-center gap-xs rounded-full border border-brand px-md text-body-sm font-bold text-brand hover:bg-brand-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
        >
          Add
        </button>
      ) : (
        <Stepper qty={qty} onChange={(q) => onQtyChange(Math.max(0, q))} />
      )}
    </div>
  );
}

// ─── Confirm sheet (inline) ──────────────────────────────────────────────────

function ConfirmPanel({
  itemCount,
  basketValue,
  onSend,
  onClose,
}: {
  itemCount: number;
  basketValue: number;
  onSend: (note: string) => Promise<void>;
  onClose: () => void;
}) {
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSend() {
    if (submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      await onSend(note.trim());
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not send request.");
      setSubmitting(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-ink/30">
      <div className="w-full max-w-lg rounded-t-bottom-sheet bg-white p-xl space-y-md shadow-floating">
        <h2 className="text-title-md font-extrabold text-ink">Send quote request</h2>
        <p className="text-body-md text-muted">
          {itemCount} item{itemCount !== 1 ? "s" : ""} ·{" "}
          <span className="font-bold">{formatINR(basketValue)} indicative</span>. The shop will
          price it and send back a quotation you can accept.
        </p>

        <div>
          <label className="block text-body-sm font-bold text-ink mb-xs" htmlFor="rq-note">
            Note (optional)
          </label>
          <textarea
            id="rq-note"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            maxLength={500}
            rows={2}
            placeholder="Anything the shop should know"
            className="w-full rounded-input border border-hairline bg-white px-md py-sm text-body-md text-ink resize-none focus:outline-none focus:ring-2 focus:ring-brand"
          />
        </div>

        {error && <p className="text-body-sm text-error">{error}</p>}

        <div className="flex gap-md pt-sm">
          <button
            onClick={onClose}
            disabled={submitting}
            className="flex-1 h-10 rounded-button border border-hairline text-label-md text-ink hover:bg-surface-tint disabled:opacity-50"
          >
            Back
          </button>
          <button
            onClick={handleSend}
            disabled={submitting}
            className="flex-[2] h-10 rounded-button bg-brand text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-60"
          >
            {submitting ? (
              <span className="flex items-center justify-center gap-sm">
                <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                Sending…
              </span>
            ) : (
              "Send request"
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

function RequestQuotePageContent() {
  const params = useParams<{ role: string; id: string }>();
  const role = params.role;
  const id = params.id;
  const router = useRouter();

  const [products, setProducts] = useState<CatalogProduct[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [categoryId, setCategoryId] = useState<number | null>(null);
  const [basket, setBasket] = useState<Map<number, { product: CatalogProduct; qty: number }>>(
    new Map(),
  );
  const [showConfirm, setShowConfirm] = useState(false);
  const [snack, setSnack] = useState<SnackMsg | null>(null);
  const snackTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Only party role supported
  useEffect(() => {
    if (role !== "party") {
      router.replace(`/merchants/${role}/${id}/invoices`);
    }
  }, [role, id, router]);

  const loadProducts = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchCatalogProducts({ limit: 100 });
      setProducts(data.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load catalogue.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    startTransition(() => { void loadProducts(); });
  }, [loadProducts]);

  function showSnack(msg: SnackMsg) {
    setSnack(msg);
    if (snackTimer.current) clearTimeout(snackTimer.current);
    snackTimer.current = setTimeout(() => setSnack(null), 5000);
  }

  // Derived: categories
  const categories = (() => {
    const byId = new Map<number, { cat: CatalogProduct["category"]; count: number }>();
    for (const p of products) {
      if (!p.category) continue;
      const existing = byId.get(p.category.id);
      byId.set(p.category.id, {
        cat: p.category,
        count: (existing?.count ?? 0) + 1,
      });
    }
    return Array.from(byId.values()).sort((a, b) =>
      (a.cat?.name ?? "").localeCompare(b.cat?.name ?? ""),
    );
  })();

  // Derived: filtered products
  const visible = products.filter((p) => {
    if (categoryId !== null && p.categoryId !== categoryId) return false;
    const q = query.trim().toLowerCase();
    if (!q) return true;
    return p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q);
  });

  function setQty(product: CatalogProduct, qty: number) {
    setBasket((prev) => {
      const next = new Map(prev);
      if (qty <= 0) {
        next.delete(product.id);
      } else {
        next.set(product.id, { product, qty });
      }
      return next;
    });
  }

  const basketItems = Array.from(basket.values());
  const itemCount = basketItems.reduce((s, e) => s + e.qty, 0);
  const basketValue = basketItems.reduce((s, e) => s + e.product.sellingPrice * e.qty, 0);

  async function handleSend(note: string) {
    const items: BasketItem[] = basketItems.map((e) => ({
      productId: e.product.id,
      name: e.product.name,
      sku: e.product.sku,
      quantity: e.qty,
      unitPrice: e.product.sellingPrice,
      taxPercent: e.product.taxPercent,
      imageUrl: e.product.images?.[0]?.url ?? null,
    }));
    await requestQuotation(id, { items, note: note || undefined });
    showSnack({ message: "Quote request sent!", tone: "success" });
    setShowConfirm(false);
    // Navigate back to quotations
    setTimeout(() => router.push(`/merchants/${role}/${id}/quotations`), 1200);
  }

  return (
    <div className="mx-auto max-w-shell px-0 sm:px-lg flex flex-col" style={{ minHeight: "80vh" }}>
      <div className="mx-auto w-full max-w-content flex flex-col flex-1">
        {/* Page header */}
        <div className="px-lg sm:px-0 pt-xxxl pb-md">
          <h1 className="text-headline-sm font-extrabold text-ink">Request a quote</h1>
          <p className="text-body-sm text-muted mt-xs">
            Select items and the shop will send back a priced quotation.
          </p>
        </div>

        {loading ? (
          <div className="flex-1">
            <CatalogueSkeleton />
          </div>
        ) : error ? (
          <div className="flex flex-col items-center gap-md py-huge text-center">
            <AlertCircle size={40} className="text-error" />
            <p className="text-body-md text-muted">{error}</p>
            <button
              onClick={loadProducts}
              className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong"
            >
              Retry
            </button>
          </div>
        ) : products.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-huge text-center">
            <Package size={48} className="text-muted" />
            <p className="text-body-md text-muted">This shop has no products to browse yet.</p>
          </div>
        ) : (
          <div className="flex flex-col flex-1">
            {/* Search */}
            <div className="px-lg sm:px-0 pb-sm">
              <div className="relative">
                <Search
                  size={16}
                  className="absolute left-md top-1/2 -translate-y-1/2 text-muted pointer-events-none"
                />
                <input
                  type="search"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Search this shop's catalogue"
                  className="w-full rounded-input border border-hairline bg-white py-sm pl-[36px] pr-md text-body-md text-ink focus:outline-none focus:ring-2 focus:ring-brand focus:border-brand"
                />
              </div>
            </div>

            {/* Category chips */}
            {categories.length > 0 && (
              <div className="flex gap-sm overflow-x-auto pb-sm px-lg sm:px-0 no-scrollbar">
                <CategoryChip
                  label="All"
                  count={products.length}
                  selected={categoryId === null}
                  onTap={() => setCategoryId(null)}
                />
                {categories.map(({ cat, count }) =>
                  cat ? (
                    <CategoryChip
                      key={cat.id}
                      label={cat.name}
                      count={count}
                      selected={categoryId === cat.id}
                      onTap={() => setCategoryId(cat.id)}
                    />
                  ) : null,
                )}
              </div>
            )}

            <div className="h-px bg-hairline" />

            {/* Product list */}
            {visible.length === 0 ? (
              <p className="py-xxl text-center text-body-md text-muted">
                No products match. Try another category or search term.
              </p>
            ) : (
              <div className="divide-y divide-hairline pb-[120px]">
                {visible.map((p) => (
                  <ProductRow
                    key={p.id}
                    product={p}
                    qty={basket.get(p.id)?.qty ?? 0}
                    onQtyChange={(q) => setQty(p, q)}
                  />
                ))}
              </div>
            )}
          </div>
        )}

        {/* Bottom bar */}
        {!loading && !error && (
          <div className="fixed bottom-0 left-0 right-0 border-t border-hairline bg-white px-lg py-md shadow-floating sm:relative sm:bottom-auto sm:shadow-none sm:border-0 sm:mt-md">
            <div className="mx-auto max-w-content">
              {itemCount > 0 && (
                <div className="flex items-center justify-between mb-sm">
                  <p className="text-body-md font-bold text-ink">
                    {itemCount} item{itemCount !== 1 ? "s" : ""} selected
                  </p>
                  <p className="text-body-sm text-muted">{formatINR(basketValue)} indicative</p>
                </div>
              )}
              <button
                disabled={itemCount === 0}
                onClick={() => setShowConfirm(true)}
                className="flex w-full h-11 items-center justify-center gap-sm rounded-button bg-brand text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:bg-hairline disabled:text-disabled"
              >
                <ShoppingBag size={16} />
                {itemCount > 0 ? "Request quote" : "Add items to request a quote"}
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Confirm sheet */}
      {showConfirm && (
        <ConfirmPanel
          itemCount={itemCount}
          basketValue={basketValue}
          onSend={handleSend}
          onClose={() => setShowConfirm(false)}
        />
      )}

      <Snackbar snack={snack} />
    </div>
  );
}

export default function RequestQuotePage() {
  return (
    <RequireAuth>
      <AppHeader />
      <RequestQuotePageContent />
    </RequireAuth>
  );
}
