/**
 * Loading skeleton for the Banner detail page — mirrors the Flutter
 * `_SlideSkeleton`: a tall hero block, a deal-strip row, then a 2-col product grid.
 */

function Bone({ className = "" }: { className?: string }) {
  return (
    <span
      className={`block animate-pulse rounded-sm bg-hero-panel ${className}`}
      aria-hidden
    />
  );
}

export function BannerSkeleton() {
  return (
    <div>
      {/* Hero placeholder */}
      <Bone className="h-[300px] w-full rounded-none sm:h-[360px]" />

      {/* Deal strip */}
      <div className="flex items-center gap-sm px-lg py-md">
        <Bone className="h-8 w-36 rounded-full" />
        <div className="ml-auto flex gap-sm">
          <Bone className="h-6 w-20 rounded-full" />
          <Bone className="h-6 w-16 rounded-full" />
        </div>
      </div>

      {/* Product grid */}
      <div className="grid grid-cols-2 gap-lg px-lg pb-huge sm:grid-cols-3 lg:grid-cols-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="overflow-hidden rounded-md bg-white shadow-floating">
            <Bone className="aspect-square w-full rounded-none" />
            <div className="p-sm">
              <Bone className="h-3 w-full" />
              <Bone className="mt-[4px] h-3 w-3/4" />
              <Bone className="mt-sm h-[14px] w-16" />
              <Bone className="mt-[3px] h-[11px] w-12" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
