"use client";

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Plus, Search } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import {
  listCategories,
  listProducts,
  setPublished,
} from "@/features/products/api";
import type { Category, Product, ProductList } from "@/features/products/schema";
import { money } from "@/features/products/format";
import { ProductThumb } from "@/features/products/components/product-thumb";
import { StockBadge } from "@/features/products/components/stock-badge";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { useCanManage } from "@/features/auth/use-can";

const PAGE_SIZE = 20;

const SORTS: Array<{ label: string; sortBy: string; sortOrder: string }> = [
  { label: "Recently updated", sortBy: "updatedAt", sortOrder: "desc" },
  { label: "Name A–Z", sortBy: "name", sortOrder: "asc" },
  { label: "Price low–high", sortBy: "sellingPrice", sortOrder: "asc" },
  { label: "Price high–low", sortBy: "sellingPrice", sortOrder: "desc" },
  { label: "Newest", sortBy: "createdAt", sortOrder: "desc" },
];

export default function ProductsListPage() {
  // useSearchParams needs a Suspense boundary during prerender.
  return (
    <Suspense fallback={null}>
      <ProductsListInner />
    </Suspense>
  );
}

function clampSortIdx(raw: string | null): number {
  const n = Number(raw);
  return Number.isInteger(n) && n >= 0 && n < SORTS.length ? n : 0;
}

function ProductsListInner() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const canEdit = useCanManage("products");

  // Initialise filter state from the URL so the view deep-links and survives refresh.
  const [searchInput, setSearchInput] = useState(() => searchParams.get("q") ?? "");
  const [search, setSearch] = useState(() => searchParams.get("q") ?? "");
  const [categoryId, setCategoryId] = useState<string>(() => searchParams.get("category") ?? "");
  const [lowStock, setLowStock] = useState(() => searchParams.get("low") === "1");
  const [outOfStock, setOutOfStock] = useState(() => searchParams.get("out") === "1");
  const [sortIdx, setSortIdx] = useState(() => clampSortIdx(searchParams.get("sort")));
  const [page, setPage] = useState(() => {
    const p = Number(searchParams.get("page"));
    return Number.isInteger(p) && p > 0 ? p : 1;
  });

  const [data, setData] = useState<ProductList | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [categories, setCategories] = useState<Category[]>([]);
  const [togglingId, setTogglingId] = useState<number | null>(null);
  const [toggleError, setToggleError] = useState<string | null>(null);

  // Debounce the search box (setState in a timeout — not synchronous).
  useEffect(() => {
    const t = setTimeout(() => {
      setSearch(searchInput.trim());
      setPage(1);
    }, 300);
    return () => clearTimeout(t);
  }, [searchInput]);

  // Mirror the active filters into the URL (replace, no history spam).
  useEffect(() => {
    const qs = new URLSearchParams();
    if (search) qs.set("q", search);
    if (categoryId) qs.set("category", categoryId);
    if (lowStock) qs.set("low", "1");
    if (outOfStock) qs.set("out", "1");
    if (sortIdx > 0) qs.set("sort", String(sortIdx));
    if (page > 1) qs.set("page", String(page));
    const next = qs.toString();
    const current = searchParams.toString();
    if (next !== current) router.replace(next ? `${pathname}?${next}` : pathname, { scroll: false });
  }, [search, categoryId, lowStock, outOfStock, sortIdx, page, pathname, router, searchParams]);

  // Load categories once.
  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const cats = await listCategories();
        if (active) setCategories(cats);
      } catch {
        /* filter just won't populate */
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  const sort = SORTS[sortIdx] ?? SORTS[0];
  const queryKey = `${search}|${categoryId}|${lowStock}|${outOfStock}|${sortIdx}|${page}|${nonce}`;

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const query: Record<string, string> = {
          page: String(page),
          limit: String(PAGE_SIZE),
          sortBy: sort.sortBy,
          sortOrder: sort.sortOrder,
        };
        if (search) query.search = search;
        if (categoryId) query.categoryId = categoryId;
        if (lowStock) query.lowStock = "true";
        if (outOfStock) query.outOfStock = "true";
        const result = await listProducts(query);
        if (!active) return;
        setData(result);
        setError(null);
      } catch (e) {
        if (!active) return;
        setError(e instanceof Error ? e.message : "Could not load products.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [queryKey]);

  const reload = useCallback(() => {
    setLoading(true);
    setNonce((n) => n + 1);
  }, []);

  const categoryName = useMemo(() => {
    const map = new Map(categories.map((c) => [c.id, c.name]));
    return (p: Product) => p.category?.name ?? (p.categoryId ? map.get(p.categoryId) : null) ?? "—";
  }, [categories]);

  async function togglePublish(p: Product) {
    if (togglingId != null) return;
    setTogglingId(p.id);
    setToggleError(null);
    try {
      await setPublished(p.id, !p.isPublished);
    } catch (e) {
      setToggleError(
        e instanceof Error ? e.message : `Could not update "${p.name}".`,
      );
    } finally {
      setTogglingId(null);
      reload(); // refetch either way so the row reflects server truth
    }
  }

  const total = data?.pagination.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const products = data?.data ?? [];

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <div className="flex flex-wrap items-center justify-between gap-md">
        <div>
          <h1 className="text-headline-md text-ink">Products</h1>
          <p className="mt-xs text-body-md text-muted">
            {total} {total === 1 ? "product" : "products"} in your catalogue.
          </p>
        </div>
        <MaybeLocked area="products" label="New product">
          <Link
            href="/dashboard/products/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={18} /> New product
          </Link>
        </MaybeLocked>
      </div>

      {/* Toolbar */}
      <div className="mt-xl flex flex-wrap items-center gap-md">
        <div className="relative min-w-[220px] flex-1">
          <Search
            size={18}
            className="pointer-events-none absolute left-md top-1/2 -translate-y-1/2 text-subtle"
          />
          <input
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Search by name, SKU or barcode"
            className="h-10 w-full rounded-input border border-hairline bg-white pl-massive pr-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
          />
        </div>
        <select
          value={categoryId}
          onChange={(e) => {
            setCategoryId(e.target.value);
            setPage(1);
          }}
          className="h-10 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <option value="">All categories</option>
          {categories.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
        <select
          value={sortIdx}
          onChange={(e) => setSortIdx(Number(e.target.value))}
          className="h-10 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          {SORTS.map((s, i) => (
            <option key={s.label} value={i}>
              {s.label}
            </option>
          ))}
        </select>
        <FilterChip
          active={lowStock}
          onClick={() => {
            setLowStock((v) => !v);
            setPage(1);
          }}
        >
          Low stock
        </FilterChip>
        <FilterChip
          active={outOfStock}
          onClick={() => {
            setOutOfStock((v) => !v);
            setPage(1);
          }}
        >
          Out of stock
        </FilterChip>
      </div>

      <Divider className="mt-lg" />

      {toggleError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {toggleError}
        </p>
      ) : null}

      {/* List */}
      {loading && !data ? (
        <ListSkeleton />
      ) : error && !data ? (
        <div className="flex flex-col items-start gap-md py-xxxl">
          <p className="text-body-md text-muted">{error}</p>
          <button
            type="button"
            onClick={reload}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            Try again
          </button>
        </div>
      ) : products.length === 0 ? (
        <p className="py-xxxl text-body-md text-muted">
          No products match your filters.
        </p>
      ) : (
        <ul>
          {products.map((p) => (
            <ProductRow
              key={p.id}
              product={p}
              categoryName={categoryName(p)}
              canEdit={canEdit}
              toggling={togglingId === p.id}
              onTogglePublish={() => togglePublish(p)}
            />
          ))}
        </ul>
      )}

      {/* Pagination */}
      {total > PAGE_SIZE ? (
        <div className="mt-lg flex items-center justify-between">
          <p className="text-body-sm text-muted">
            Page {page} of {totalPages}
          </p>
          <div className="flex gap-sm">
            <PagerButton disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
              Previous
            </PagerButton>
            <PagerButton
              disabled={page >= totalPages}
              onClick={() => setPage((p) => p + 1)}
            >
              Next
            </PagerButton>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function FilterChip({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={`h-10 rounded-button border px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
        active
          ? "border-brand bg-brand-soft text-brand-strong"
          : "border-hairline text-muted hover:bg-surface-tint hover:text-ink"
      }`}
    >
      {children}
    </button>
  );
}

function PagerButton({
  disabled,
  onClick,
  children,
}: {
  disabled: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled disabled:hover:bg-transparent"
    >
      {children}
    </button>
  );
}

function ProductRow({
  product,
  categoryName,
  canEdit,
  toggling,
  onTogglePublish,
}: {
  product: Product;
  categoryName: string;
  canEdit: boolean;
  toggling: boolean;
  onTogglePublish: () => void;
}) {
  const showStrike = product.mrp > product.sellingPrice;
  return (
    <li className="flex items-center gap-md border-t border-hairline py-md">
      <Link
        href={`/dashboard/products/${product.id}`}
        className="flex min-w-0 flex-1 items-center gap-md focus-visible:outline-none"
      >
        <ProductThumb url={product.images[0]?.url} alt={product.name} size={48} />
        <div className="min-w-0 flex-1">
          <p className="truncate text-body-md text-ink">{product.name}</p>
          <p className="truncate text-body-sm text-muted">
            {product.sku} · {categoryName}
          </p>
        </div>
        <div className="hidden w-32 shrink-0 text-right sm:block">
          <p className="text-body-md tabular-nums text-ink">
            {money(product.sellingPrice)}
          </p>
          {showStrike ? (
            <p className="text-body-sm tabular-nums text-subtle line-through">
              {money(product.mrp)}
            </p>
          ) : null}
        </div>
        <div className="hidden w-28 shrink-0 sm:flex sm:justify-end">
          <StockBadge product={product} />
        </div>
      </Link>
      <button
        type="button"
        onClick={onTogglePublish}
        disabled={!canEdit || toggling}
        aria-busy={toggling || undefined}
        aria-pressed={product.isPublished}
        title={
          canEdit
            ? product.isPublished
              ? "Published — click to unpublish"
              : "Unpublished — click to publish"
            : "You don't have access. Ask the shop owner."
        }
        className={`shrink-0 rounded-full px-sm py-px text-body-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled disabled:hover:bg-transparent ${
          toggling ? "opacity-60" : ""
        } ${
          product.isPublished
            ? "bg-brand-soft text-brand-strong"
            : "bg-surface-tint text-muted hover:text-ink"
        }`}
      >
        {toggling ? "Saving…" : product.isPublished ? "Published" : "Draft"}
      </button>
    </li>
  );
}

function ListSkeleton() {
  return (
    <ul className="animate-pulse">
      {Array.from({ length: 8 }).map((_, i) => (
        <li key={i} className="flex items-center gap-md border-t border-hairline py-md">
          <div className="size-12 rounded-md bg-hairline" />
          <div className="flex-1">
            <div className="h-3 w-48 rounded-xs bg-hairline" />
            <div className="mt-sm h-3 w-32 rounded-xs bg-hairline" />
          </div>
          <div className="h-3 w-16 rounded-xs bg-hairline" />
        </li>
      ))}
    </ul>
  );
}
