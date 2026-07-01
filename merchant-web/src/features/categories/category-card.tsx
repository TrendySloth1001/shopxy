"use client";

import Link from "next/link";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { CategoryIcon } from "./category-icon";
import { categoryProductCount, type CategoryNode } from "./schema";

/** Square taxonomy tile — image (or icon fallback) + name + counts. Shared by
 *  the browse grid and the subcategories section on a category page. */
export function CategoryCard({ node }: { node: CategoryNode }) {
  const t = useTranslations("categories");
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
          {t("card.productCount", { count })}
          {childCount > 0 ? ` · ${t("card.subCount", { count: childCount })}` : ""}
        </p>
      </div>
    </Link>
  );
}
