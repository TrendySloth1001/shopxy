"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { Grid3X3 } from "lucide-react";
import { fetchCategoryTree } from "@/features/catalog/api";
import type { CategoryNode } from "@/features/catalog/types";
import { ImageBox } from "@/features/home/components/image-box";
import { resolveImageUrl } from "@/features/home/format";

/**
 * All-categories grid page — port of the Flutter CategoriesPage.
 * Fetches `/api/categories/tree` and renders a 3-column image grid.
 * Tapping a category navigates to `/c/[slug]`.
 */
export function CategoriesGrid() {
  const [tree, setTree] = useState<CategoryNode[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const booted = useRef(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchCategoryTree();
      setTree(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Something went wrong.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (booted.current) return;
    booted.current = true;
    void load();
  }, [load]);

  return (
    <div className="mx-auto max-w-shell px-lg py-lg">
      <h1 className="mb-lg text-headline-sm text-ink">All Categories</h1>

      {/* Skeleton */}
      {loading ? (
        <div className="grid grid-cols-3 gap-md sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6">
          {Array.from({ length: 12 }).map((_, i) => (
            <CategoryTileSkeleton key={i} />
          ))}
        </div>
      ) : error ? (
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <Grid3X3 size={40} className="text-disabled" />
          <p className="text-title-sm text-muted">Could not load categories</p>
          <p className="text-body-sm text-muted">{error}</p>
          <button
            type="button"
            onClick={() => void load()}
            className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-lg text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            Try again
          </button>
        </div>
      ) : tree.length === 0 ? (
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <Grid3X3 size={40} className="text-disabled" />
          <p className="text-title-sm text-muted">No categories yet</p>
        </div>
      ) : (
        <div className="grid grid-cols-3 gap-md sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6">
          {tree.map((node) => (
            <CategoryTile key={node.id} node={node} />
          ))}
        </div>
      )}
    </div>
  );
}

// ── Category tile ─────────────────────────────────────────────────────────────

function CategoryTile({ node }: { node: CategoryNode }) {
  const imageUrl = resolveImageUrl(node.imageUrl);
  const initials = node.name.trim()[0]?.toUpperCase() ?? "?";
  const subCount = node.children.length;

  return (
    <Link
      href={`/c/${node.slug}`}
      className="group flex flex-col items-start gap-sm focus-visible:outline-none"
    >
      {/* Thumbnail */}
      <div className="aspect-square w-full overflow-hidden rounded-button border border-hairline bg-hero-panel transition-shadow group-hover:shadow-floating group-focus-visible:ring-2 group-focus-visible:ring-brand-soft">
        {imageUrl ? (
          <ImageBox url={imageUrl} alt={node.name} fit="cover" />
        ) : (
          <div className="flex size-full items-center justify-center bg-brand-soft">
            <span className="text-title-md text-brand">{initials}</span>
          </div>
        )}
      </div>

      {/* Name */}
      <p className="line-clamp-2 text-body-sm font-semibold leading-tight text-ink">
        {node.name}
      </p>
      {subCount > 0 ? (
        <p className="text-[11px] text-muted">
          {subCount} subcategor{subCount === 1 ? "y" : "ies"}
        </p>
      ) : node._count.products > 0 ? (
        <p className="text-[11px] text-muted">{node._count.products} products</p>
      ) : null}
    </Link>
  );
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

function CategoryTileSkeleton() {
  return (
    <div className="flex flex-col gap-sm">
      <div className="aspect-square w-full animate-pulse rounded-button bg-hero-panel" />
      <div className="h-3 w-[90%] animate-pulse rounded-xs bg-hero-panel" />
      <div className="h-3 w-[60%] animate-pulse rounded-xs bg-hero-panel" />
      <div className="h-[11px] w-[45%] animate-pulse rounded-xs bg-hero-panel" />
    </div>
  );
}
