"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { FolderTree, RefreshCw } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { getCategoryTree } from "@/features/categories/api";
import { CategoryIcon } from "@/features/categories/category-icon";
import { categoryProductCount, type CategoryNode } from "@/features/categories/schema";

export default function CategoriesPage() {
  const [nodes, setNodes] = useState<CategoryNode[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const tree = await getCategoryTree();
        if (!active) return;
        setNodes(tree);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load categories.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce]);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={FolderTree}
        tone="teal"
        title="Categories"
        subtitle="Browse the storefront taxonomy and drill into the products filed under each category. The catalogue itself is platform-managed."
      >
        <button
          type="button"
          onClick={() => setNonce((n) => n + 1)}
          disabled={loading}
          aria-label="Refresh"
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
      </PageHeader>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl">
        {loading ? (
          <div className="grid grid-cols-2 gap-lg sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6">
            {Array.from({ length: 12 }).map((_, i) => (
              <div key={i} className="flex flex-col gap-sm">
                <div className="aspect-square w-full animate-pulse rounded-lg bg-surface-tint" />
                <div className="h-3 w-3/4 animate-pulse rounded-full bg-surface-tint" />
              </div>
            ))}
          </div>
        ) : nodes.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-accent-teal-soft text-accent-teal">
              <FolderTree size={22} />
            </span>
            <p className="text-body-md text-muted">No categories in the taxonomy yet.</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-lg sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6">
            {nodes.map((node) => (
              <CategoryCard key={node.id} node={node} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function CategoryCard({ node }: { node: CategoryNode }) {
  const src = mediaSrc(node.imageUrl);
  const count = categoryProductCount(node);
  const childCount = node.children?.length ?? 0;
  return (
    <Link href={`/dashboard/categories/${node.id}`} className="group flex flex-col gap-sm">
      <div className="relative aspect-square w-full overflow-hidden rounded-lg border border-hairline bg-surface-tint">
        {src ? (
          <Image
            src={src}
            alt={node.name}
            fill
            unoptimized
            sizes="(max-width: 640px) 50vw, (max-width: 1280px) 25vw, 16vw"
            className="object-cover transition-transform group-hover:scale-105"
          />
        ) : (
          <span className="flex size-full items-center justify-center bg-accent-teal-soft text-accent-teal">
            <CategoryIcon name={node.iconName} size={32} />
          </span>
        )}
      </div>
      <div>
        <p className="truncate text-body-md text-ink group-hover:text-brand-strong">{node.name}</p>
        <p className="text-body-sm text-subtle">
          {count} {count === 1 ? "product" : "products"}
          {childCount > 0 ? ` · ${childCount} sub` : ""}
        </p>
      </div>
    </Link>
  );
}
