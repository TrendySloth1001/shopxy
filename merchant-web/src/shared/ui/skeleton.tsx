/**
 * Shimmer placeholders shown while a screen loads. Built from the house
 * convention — `animate-pulse` over `bg-hairline` blocks at token radii — so a
 * skeleton matches the geometry of the real content it stands in for. Apply
 * `animate-pulse` to the outer container, not every block.
 */

/** A single pulsing block. Pass width/height/radius via `className`. */
export function Skeleton({ className = "" }: { className?: string }) {
  return <div className={`rounded-xs bg-hairline ${className}`} />;
}

/**
 * List rows matching the standard `border-b border-hairline py-md` row: an
 * optional leading puck, one or two text lines, an optional trailing chip.
 * Drop this into a list page's loading branch (the PageHeader is already shown).
 */
export function ListRowsSkeleton({
  rows = 8,
  leading = true,
  lines = 2,
  trailing = true,
}: {
  rows?: number;
  leading?: boolean;
  lines?: number;
  trailing?: boolean;
}) {
  const widths = ["w-48", "w-64", "w-40"];
  return (
    <div className="animate-pulse">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex items-center gap-md border-b border-hairline py-md">
          {leading ? <Skeleton className="size-10 shrink-0 rounded-full" /> : null}
          <div className="min-w-0 flex-1 space-y-sm">
            {Array.from({ length: lines }).map((_, j) => (
              <Skeleton key={j} className={`h-3 ${widths[j % widths.length]} max-w-full`} />
            ))}
          </div>
          {trailing ? <Skeleton className="h-3 w-16 shrink-0" /> : null}
        </div>
      ))}
    </div>
  );
}

/** A responsive tile grid skeleton (categories, settings, KPI strips). */
export function CardsSkeleton({ count = 6 }: { count?: number }) {
  return (
    <div className="grid animate-pulse grid-cols-1 gap-md sm:grid-cols-2 xl:grid-cols-3">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="space-y-sm">
          <Skeleton className="h-4 w-24" />
          <Skeleton className="h-6 w-32" />
        </div>
      ))}
    </div>
  );
}

/**
 * Full-page skeleton for a detail screen: a back-link bar, a header (puck +
 * title + subtitle), then a couple of sections of rows. Generic enough for the
 * invoice / quotation / challan / return / adjustment / party / vendor details.
 */
export function DetailSkeleton() {
  return (
    <div className="w-full animate-pulse px-lg py-xxl md:px-xxl">
      <Skeleton className="h-3 w-24" />
      <div className="mt-md flex items-start gap-md">
        <Skeleton className="size-12 shrink-0 rounded-lg" />
        <div className="flex-1 space-y-sm">
          <Skeleton className="h-5 w-56 max-w-full" />
          <Skeleton className="h-3 w-40 max-w-full" />
        </div>
      </div>

      <Skeleton className="mt-xl h-px w-full" />

      <div className="mt-lg space-y-md">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="flex items-center gap-md">
            <div className="min-w-0 flex-1 space-y-sm">
              <Skeleton className="h-3 w-48 max-w-full" />
              <Skeleton className="h-3 w-32 max-w-full" />
            </div>
            <Skeleton className="h-3 w-16 shrink-0" />
          </div>
        ))}
      </div>
    </div>
  );
}

/** Full-page skeleton for a focused form / editor (edit pages, settings forms). */
export function FormSkeleton() {
  return (
    <div className="w-full animate-pulse px-lg py-xxl md:px-xxl">
      <Skeleton className="h-3 w-24" />
      <Skeleton className="mt-md h-6 w-48" />
      <div className="mt-xl max-w-form space-y-lg">
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} className="space-y-sm">
            <Skeleton className="h-3 w-24" />
            <Skeleton className="h-10 w-full rounded-input" />
          </div>
        ))}
        <Skeleton className="h-11 w-40 rounded-button" />
      </div>
    </div>
  );
}
