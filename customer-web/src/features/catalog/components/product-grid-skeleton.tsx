/**
 * Skeleton shimmer for the 2-column product grid used on shop and category
 * pages. Mirrors the real CatalogProductCard layout while loading.
 */
export function ProductGridSkeleton({ count = 8 }: { count?: number }) {
  return (
    <div className="grid grid-cols-2 gap-md sm:grid-cols-3 lg:grid-cols-4">
      {Array.from({ length: count }).map((_, i) => (
        <div
          key={i}
          className="flex flex-col overflow-hidden rounded-md border border-hairline bg-white"
        >
          <div className="aspect-square w-full animate-pulse bg-hero-panel" />
          <div className="flex flex-col gap-xs p-sm">
            <div className="h-3 w-[90%] animate-pulse rounded-xs bg-hero-panel" />
            <div className="h-3 w-[65%] animate-pulse rounded-xs bg-hero-panel" />
            <div className="mt-xs h-4 w-[45%] animate-pulse rounded-xs bg-hero-panel" />
          </div>
        </div>
      ))}
    </div>
  );
}
