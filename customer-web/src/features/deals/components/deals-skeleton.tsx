/**
 * Loading skeleton for the Deals page — mirrors the structure of the real
 * content so the transition from skeleton → data stays visually stable.
 * Parallels the Flutter `_DealsSkeleton` / `_FlashHeaderSkeleton` /
 * `_FlashGridSkeleton` / `_SpotlightsSkeleton` widgets.
 */

function Bone({ className = "" }: { className?: string }) {
  return (
    <span
      className={`block animate-pulse rounded-sm bg-hero-panel ${className}`}
      aria-hidden
    />
  );
}

function FlashHeaderSkeleton() {
  return (
    <div className="flex items-center gap-sm rounded-md bg-flash-from p-md">
      <Bone className="h-5 w-5 rounded-full" />
      <Bone className="h-4 w-36" />
      <Bone className="ml-auto h-6 w-20 rounded-xs" />
    </div>
  );
}

function FlashTileSkeleton() {
  return (
    <div className="overflow-hidden rounded-md bg-white shadow-floating">
      <Bone className="aspect-square w-full rounded-none" />
      <div className="p-sm">
        <Bone className="h-3 w-full" />
        <Bone className="mt-[4px] h-3 w-3/4" />
        <div className="mt-xs flex items-center gap-xs">
          <Bone className="h-[14px] w-12" />
          <Bone className="h-[10px] w-9" />
        </div>
        <Bone className="mt-sm h-[5px] w-full rounded-full" />
        <Bone className="mt-[3px] h-[10px] w-14" />
      </div>
    </div>
  );
}

function SpotlightSkeleton() {
  return <Bone className="aspect-video w-full rounded-lg" />;
}

export function DealsSkeleton() {
  return (
    <div className="flex flex-col gap-xl">
      {/* Flash section */}
      <div className="rounded-md bg-gradient-to-b from-flash-from to-flash-to p-lg">
        <FlashHeaderSkeleton />
        <div className="mt-md grid grid-cols-2 gap-md sm:grid-cols-3 lg:grid-cols-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <FlashTileSkeleton key={i} />
          ))}
        </div>
      </div>

      {/* Spotlights section */}
      <div>
        <Bone className="mb-md h-5 w-44" />
        <div className="flex flex-col gap-md">
          {Array.from({ length: 3 }).map((_, i) => (
            <SpotlightSkeleton key={i} />
          ))}
        </div>
      </div>
    </div>
  );
}
