"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ChevronRight, GalleryHorizontalEnd, Plus } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { formatDateRange } from "@/shared/datetime";
import { listCarousels } from "@/features/carousels/api";
import { PLACEMENTS, PLACEMENT_LABELS, type Carousel } from "@/features/carousels/schema";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

export default function CarouselsPage() {
  const [carousels, setCarousels] = useState<Carousel[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const rows = await listCarousels();
        if (!active) return;
        setCarousels(rows);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load carousels.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  const grouped = PLACEMENTS.map((p) => ({
    placement: p,
    rows: carousels.filter((c) => c.placement === p),
  })).filter((g) => g.rows.length > 0);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={GalleryHorizontalEnd}
        tone="brand"
        title="My carousels"
        subtitle="Banner carousels for your storefront — grouped by where they appear."
      >
        <MaybeLocked area="marketing" label="New carousel">
          <Link
            href="/dashboard/carousels/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> New carousel
          </Link>
        </MaybeLocked>
      </PageHeader>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {loading ? (
        <ListRowsSkeleton />
      ) : carousels.length === 0 ? (
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <span className="flex size-12 items-center justify-center rounded-full bg-brand-soft text-brand-strong">
            <GalleryHorizontalEnd size={22} />
          </span>
          <p className="text-body-md text-muted">No carousels yet — create one to start building slides.</p>
          <MaybeLocked area="marketing" label="New carousel">
            <Link
              href="/dashboard/carousels/new"
              className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              <Plus size={16} /> New carousel
            </Link>
          </MaybeLocked>
        </div>
      ) : (
        <div className="mt-xl flex flex-col gap-xxl">
          {grouped.map((g) => (
            <section key={g.placement}>
              <h2 className="text-label-md uppercase tracking-wide text-subtle">
                {PLACEMENT_LABELS[g.placement]}
              </h2>
              <div className="mt-sm">
                {g.rows.map((c) => (
                  <CarouselRow key={c.id} carousel={c} />
                ))}
              </div>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}

function CarouselRow({ carousel }: { carousel: Carousel }) {
  const count = carousel._count?.slides ?? 0;
  const scheduled = carousel.startAt || carousel.endAt;
  return (
    <Link
      href={`/dashboard/carousels/${carousel.id}`}
      className="flex items-center gap-md border-b border-hairline py-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className="min-w-0 flex-1">
        <span className="flex items-center gap-sm">
          <span className="truncate text-body-md text-ink">{carousel.name}</span>
          {!carousel.isActive ? (
            <span className="shrink-0 rounded-full bg-surface-tint px-sm py-px text-body-sm text-muted">Off</span>
          ) : null}
        </span>
        <span className="mt-px block text-body-sm text-muted">
          {count} {count === 1 ? "slide" : "slides"}
          {scheduled ? ` · ${formatDateRange(carousel.startAt, carousel.endAt)}` : ""}
        </span>
      </span>
      <ChevronRight size={18} className="shrink-0 text-subtle" />
    </Link>
  );
}
