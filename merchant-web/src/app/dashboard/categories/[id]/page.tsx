"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Search } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { ProductThumb } from "@/features/products/components/product-thumb";
import { getCategory } from "@/features/categories/api";
import { CategoryIcon } from "@/features/categories/category-icon";
import { categoryProductCount, type CategoryBase } from "@/features/categories/schema";
import { listProducts } from "@/features/products/api";
import { money } from "@/features/products/format";
import type { Product } from "@/features/products/schema";

const BACK = "/dashboard/categories";
const PAGE_SIZE = 20;

export default function CategoryProductsPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [category, setCategory] = useState<CategoryBase | null>(null);
  const [products, setProducts] = useState<Product[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load the category header once.
  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const c = await getCategory(id);
        if (active) setCategory(c);
      } catch {
        /* header is best-effort; the product list carries its own error */
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  // Debounce the search box; reset to page 1 on a new term.
  useEffect(() => {
    const t = setTimeout(() => {
      setSearch(searchInput.trim());
      setPage(1);
    }, 300);
    return () => clearTimeout(t);
  }, [searchInput]);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const query: Record<string, string> = {
          categoryId: String(id),
          page: String(page),
          limit: String(PAGE_SIZE),
        };
        if (search) query.search = search;
        const result = await listProducts(query);
        if (!active) return;
        setProducts(result.data);
        setTotal(result.pagination.total);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load products.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id, page, search]);

  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const headerCount = useMemo(
    () => (category ? categoryProductCount(category) : total),
    [category, total],
  );

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <BackLink href={BACK} label="Categories" />

      <div className="mt-md flex items-start gap-md">
        <span className="flex size-12 shrink-0 items-center justify-center rounded-lg bg-accent-teal-soft text-accent-teal">
          <CategoryIcon name={category?.iconName} size={24} />
        </span>
        <div className="min-w-0">
          <h1 className="text-headline-md text-ink">{category?.name ?? "Category"}</h1>
          {category?.description ? (
            <p className="mt-xs max-w-content text-body-md text-muted">{category.description}</p>
          ) : null}
          <p className="mt-xs text-body-sm text-subtle">
            {headerCount} {headerCount === 1 ? "product" : "products"}
          </p>
        </div>
      </div>

      {/* Search */}
      <div className="mt-xl flex items-center gap-sm rounded-input border border-hairline bg-white px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
        <Search size={16} className="shrink-0 text-subtle" />
        <input
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          placeholder="Search products in this category"
          className="h-10 w-full bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
        />
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-lg">
        {loading ? (
          <p className="py-xxl text-center text-body-sm text-subtle">Loading…</p>
        ) : products.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-surface-tint text-subtle">
              <CategoryIcon name={category?.iconName} size={22} />
            </span>
            <p className="text-body-md text-muted">
              {search ? `No products match “${search}”.` : "No products in this category yet."}
            </p>
          </div>
        ) : (
          products.map((p) => <ProductRow key={p.id} product={p} />)
        )}
      </div>

      {pageCount > 1 && !loading ? (
        <div className="mt-xl flex items-center justify-center gap-md">
          <button
            type="button"
            onClick={() => setPage((n) => Math.max(1, n - 1))}
            disabled={page <= 1}
            className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            Previous
          </button>
          <span className="text-body-sm text-muted">
            Page {page} of {pageCount}
          </span>
          <button
            type="button"
            onClick={() => setPage((n) => Math.min(pageCount, n + 1))}
            disabled={page >= pageCount}
            className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            Next
          </button>
        </div>
      ) : null}
    </div>
  );
}

function ProductRow({ product }: { product: Product }) {
  return (
    <Link
      href={`/dashboard/products/${product.id}`}
      className="flex items-center gap-md border-b border-hairline py-md transition-colors hover:bg-surface-tint"
    >
      <ProductThumb url={product.images[0]?.url} alt={product.name} size={48} />
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{product.name}</p>
        <p className="text-body-sm text-subtle">SKU {product.sku}</p>
      </div>
      <div className="shrink-0 text-right">
        <p className="text-body-md font-semibold text-ink">{money(product.sellingPrice)}</p>
        {product.mrp > product.sellingPrice ? (
          <p className="text-body-sm text-muted line-through">{money(product.mrp)}</p>
        ) : null}
      </div>
    </Link>
  );
}
