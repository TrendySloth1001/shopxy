import type { Metadata } from "next";
import { Suspense } from "react";
import { SearchPageClient } from "@/features/search/components/search-page-client";

export const metadata: Metadata = {
  title: "Search — ShopXY",
  description: "Search millions of products on ShopXY.",
};

export default async function SearchPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const { q } = await searchParams;
  const initialQuery = typeof q === "string" ? q.trim() : "";

  return (
    <Suspense fallback={<SearchPageShell />}>
      <SearchPageClient initialQuery={initialQuery} />
    </Suspense>
  );
}

function SearchPageShell() {
  return (
    <div className="min-h-screen bg-canvas">
      <div className="sticky top-0 z-40 border-b border-hairline bg-white/95">
        <div className="mx-auto flex max-w-shell items-center gap-sm px-lg py-sm">
          <span className="size-9 animate-pulse rounded-sm bg-hero-panel" />
          <span className="h-10 flex-1 animate-pulse rounded-md bg-hero-panel" />
        </div>
      </div>
    </div>
  );
}
