"use client";

/** Shimmer placeholder for the order list rows */
export function OrderListSkeleton() {
  return (
    <div className="flex flex-col gap-sm">
      {Array.from({ length: 5 }).map((_, i) => (
        <OrderCardSkeleton key={i} />
      ))}
    </div>
  );
}

export function OrderCardSkeleton() {
  return (
    <div className="rounded-lg border border-hairline bg-white p-md animate-pulse">
      <div className="flex items-center justify-between mb-md">
        <div className="h-4 w-24 rounded-full bg-surface-tint" />
        <div className="h-5 w-20 rounded-full bg-surface-tint" />
      </div>
      <div className="h-3 w-40 rounded bg-surface-tint mb-xs" />
      <div className="h-3 w-32 rounded bg-surface-tint mb-sm" />
      <div className="h-px bg-hairline my-sm" />
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-xs">
          <div className="h-3 w-10 rounded bg-surface-tint" />
          <div className="h-4 w-16 rounded bg-surface-tint" />
        </div>
        <div className="h-4 w-4 rounded bg-surface-tint" />
      </div>
    </div>
  );
}

/** Shimmer for the full order detail page */
export function OrderDetailSkeleton() {
  return (
    <div className="animate-pulse">
      {/* Delivering to */}
      <div className="px-lg pt-md pb-sm">
        <div className="h-3 w-28 rounded bg-surface-tint mb-sm" />
      </div>
      <div className="flex items-start gap-sm px-lg pb-md">
        <div className="h-5 w-5 rounded bg-surface-tint mt-xs flex-shrink-0" />
        <div className="flex-1">
          <div className="h-4 w-44 rounded bg-surface-tint mb-xs" />
          <div className="h-3 w-64 rounded bg-surface-tint" />
        </div>
      </div>
      <div className="h-px bg-hairline" />
      {/* Two package sections */}
      <ShopSectionSkeleton />
      <div className="h-px bg-hairline" />
      <ShopSectionSkeleton />
      <div className="h-px bg-hairline" />
      {/* Summary */}
      <div className="px-lg pt-md pb-sm">
        <div className="h-3 w-28 rounded bg-surface-tint mb-sm" />
      </div>
      <div className="px-lg pb-md space-y-sm">
        <div className="flex justify-between">
          <div className="h-3 w-32 rounded bg-surface-tint" />
          <div className="h-3 w-20 rounded bg-surface-tint" />
        </div>
        <div className="flex justify-between">
          <div className="h-3 w-20 rounded bg-surface-tint" />
          <div className="h-3 w-12 rounded bg-surface-tint" />
        </div>
        <div className="h-px bg-hairline" />
        <div className="flex justify-between">
          <div className="h-4 w-28 rounded bg-surface-tint" />
          <div className="h-4 w-24 rounded bg-surface-tint" />
        </div>
      </div>
    </div>
  );
}

function ShopSectionSkeleton() {
  return (
    <div>
      <div className="flex items-center justify-between px-lg pt-md pb-sm">
        <div className="h-3 w-24 rounded bg-surface-tint" />
        <div className="h-5 w-20 rounded-full bg-surface-tint" />
      </div>
      <div className="h-px bg-hairline mx-lg" />
      {Array.from({ length: 2 }).map((_, i) => (
        <div key={i}>
          <div className="flex gap-md px-lg py-md">
            <div className="h-12 w-12 rounded-md bg-surface-tint flex-shrink-0" />
            <div className="flex-1 space-y-xs">
              <div className="h-4 w-40 rounded bg-surface-tint" />
              <div className="h-3 w-32 rounded bg-surface-tint" />
            </div>
            <div className="h-4 w-14 rounded bg-surface-tint" />
          </div>
          {i < 1 && <div className="h-px bg-hairline mx-lg" />}
        </div>
      ))}
    </div>
  );
}
