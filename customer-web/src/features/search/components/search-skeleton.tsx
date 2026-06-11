/** Skeleton shimmer rows shown while the search request is in-flight. */
export function SearchSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <ul aria-label="Loading results" aria-busy="true" className="divide-y divide-hairline">
      {Array.from({ length: rows }).map((_, i) => (
        <li key={i} className="flex items-center gap-md py-md">
          {/* Thumbnail placeholder */}
          <span className="size-16 shrink-0 animate-pulse rounded-sm bg-hero-panel" />
          {/* Text lines */}
          <span className="min-w-0 flex-1 space-y-[6px]">
            <span className="block h-[13px] w-[65%] animate-pulse rounded-xs bg-hero-panel" />
            <span className="block h-[10px] w-[40%] animate-pulse rounded-xs bg-hero-panel" />
            <span className="block h-[10px] w-[25%] animate-pulse rounded-xs bg-hero-panel" />
          </span>
          {/* Price placeholder */}
          <span className="h-[15px] w-12 shrink-0 animate-pulse rounded-xs bg-hero-panel" />
        </li>
      ))}
    </ul>
  );
}
