"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { FolderTree, RefreshCw } from "@/shared/icons";
import { PageHeader } from "@/shared/ui/page-header";
import { getCategoryTree } from "@/features/categories/api";
import { CategoryCard } from "@/features/categories/category-card";
import type { CategoryNode } from "@/features/categories/schema";

export default function CategoriesPage() {
  const t = useTranslations("categories");
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
        if (active) setError(e instanceof Error ? e.message : t("list.loadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, t]);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={FolderTree}
        tone="teal"
        title={t("list.title")}
        subtitle={t("list.subtitle")}
      >
        <button
          type="button"
          onClick={() => setNonce((n) => n + 1)}
          disabled={loading}
          aria-label={t("actions.refresh")}
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
            <p className="text-body-md text-muted">{t("list.empty")}</p>
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
