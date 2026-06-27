"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { ChevronRight, FolderTree, Package, Search } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { ProductThumb } from "@/features/products/components/product-thumb";
import { getCategory, getCategoryTree } from "@/features/categories/api";
import { CategoryCard } from "@/features/categories/category-card";
import { CategoryIcon } from "@/features/categories/category-icon";
import {
  categoryProductCount,
  findCategoryPath,
  type CategoryBase,
  type CategoryNode,
} from "@/features/categories/schema";
import { listProducts } from "@/features/products/api";
import { money } from "@/features/products/format";
import type { Product } from "@/features/products/schema";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

const BACK = "/dashboard/categories";
const PAGE_SIZE = 20;

export default function CategoryProductsPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [node, setNode] = useState<CategoryNode | null>(null);
  const [ancestors, setAncestors] = useState<CategoryNode[]>([]);
  const [fallback, setFallback] = useState<CategoryBase | null>(null);
  const [products, setProducts] = useState<Product[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Resolve this category within the tree → its children + breadcrumb path.
  // Falls back to the flat detail endpoint if it isn't in the active tree.
  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const tree = await getCategoryTree();
        if (!active) return;
        const path = findCategoryPath(tree, id);
        if (path) {
          setNode(path[path.length - 1]);
          setAncestors(path.slice(0, -1));
          setFallback(null);
        } else {
          const c = await getCategory(id).catch(() => null);
          if (active) setFallback(c);
        }
      } catch {
        const c = await getCategory(id).catch(() => null);
        if (active) setFallback(c);
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

  const header = node ?? fallback;
  const children = node?.children ?? [];
  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const headerCount = useMemo(
    () => (header ? categoryProductCount(header) : total),
    [header, total],
  );

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <BackLink href={BACK} label="Categories" />

      {/* Breadcrumb of ancestor categories */}
      {ancestors.length > 0 ? (
        <nav className="mt-sm flex flex-wrap items-center gap-xs text-body-sm text-muted">
          {ancestors.map((a) => (
            <span key={a.id} className="flex items-center gap-xs">
              <Link href={`/dashboard/categories/${a.id}`} className="transition-colors hover:text-ink">
                {a.name}
              </Link>
              <ChevronRight size={13} className="text-subtle" />
            </span>
          ))}
          <span className="text-ink">{header?.name ?? "Category"}</span>
        </nav>
      ) : null}

      {/* Header */}
      <div className="mt-md flex items-start gap-md">
        <span className="flex size-12 shrink-0 items-center justify-center rounded-lg bg-accent-teal-soft text-accent-teal">
          <CategoryIcon name={header?.iconName} size={24} />
        </span>
        <div className="min-w-0">
          <h1 className="text-headline-md text-ink">{header?.name ?? "Category"}</h1>
          {header?.description ? (
            <p className="mt-xs max-w-content text-body-md text-muted">{header.description}</p>
          ) : null}
          <p className="mt-xs text-body-sm text-subtle">
            {headerCount} {headerCount === 1 ? "product" : "products"}
            {children.length > 0
              ? ` · ${children.length} ${children.length === 1 ? "subcategory" : "subcategories"}`
              : ""}
          </p>
        </div>
      </div>

      {/* Subcategories */}
      {children.length > 0 ? (
        <>
          <h2 className="mt-xl mb-md flex items-center gap-sm text-title-md text-ink">
            <FolderTree size={18} className="text-subtle" /> Subcategories
          </h2>
          <div className="grid grid-cols-2 gap-lg sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6">
            {children.map((c) => (
              <CategoryCard key={c.id} node={c} />
            ))}
          </div>
          <Divider className="my-xl" />
        </>
      ) : null}

      {/* Products */}
      <h2 className="mt-xl mb-md flex items-center gap-sm text-title-md text-ink">
        <Package size={18} className="text-subtle" /> Products
      </h2>

      <div className="flex items-center gap-sm rounded-input border border-hairline bg-surface px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
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
          <ListRowsSkeleton />
        ) : products.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-surface-tint text-subtle">
              <Package size={22} />
            </span>
            <p className="text-body-md text-muted">
              {search
                ? `No products match “${search}”.`
                : children.length > 0
                  ? "No products filed directly here — check the subcategories above."
                  : "No products in this category yet."}
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
