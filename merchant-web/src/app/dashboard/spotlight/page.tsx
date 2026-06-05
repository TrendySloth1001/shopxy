"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { Plus, RefreshCw, Sparkles, Star, X } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { formatDateRange } from "@/shared/datetime";
import { autoFg } from "@/features/carousels/color";
import { cancelSpotlight, listSpotlights } from "@/features/spotlight/api";
import {
  SPOTLIGHT_STATUS_LABELS,
  type Spotlight,
  type SpotlightStatus,
} from "@/features/spotlight/schema";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

export default function SpotlightPage() {
  const [items, setItems] = useState<Spotlight[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const rows = await listSpotlights();
        if (!active) return;
        setItems(rows);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load spotlight requests.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce]);

  async function onCancel(id: number) {
    try {
      await cancelSpotlight(id);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not cancel the request.");
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Star}
        tone="amber"
        title="Brand spotlight"
        subtitle="Pitch your shop for a featured “brand of the day” slot on the customer home."
      >
        <button
          type="button"
          onClick={reload}
          disabled={loading}
          aria-label="Refresh"
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <MaybeLocked area="marketing" label="Request slot">
          <Link
            href="/dashboard/spotlight/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> Request slot
          </Link>
        </MaybeLocked>
      </PageHeader>

      {/* Explainer */}
      <div className="mt-xl flex items-start gap-md rounded-lg bg-hero-panel p-lg">
        <Sparkles size={20} className="mt-px shrink-0 text-ink" />
        <p className="text-body-md text-ink">
          A platform admin reviews each request — typically same-day. Approved spotlights run for the
          window you choose and link to the action you set.
        </p>
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <Divider className="my-xl" />

      {loading ? (
        <ListRowsSkeleton />
      ) : items.length === 0 ? (
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <span className="flex size-12 items-center justify-center rounded-full bg-accent-amber-soft text-accent-amber">
            <Star size={22} />
          </span>
          <p className="text-body-md text-muted">No spotlight requests yet.</p>
          <MaybeLocked area="marketing" label="Request slot">
            <Link
              href="/dashboard/spotlight/new"
              className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              <Plus size={16} /> Request slot
            </Link>
          </MaybeLocked>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-lg lg:grid-cols-2">
          {items.map((s) => (
            <SpotlightCard key={s.id} spotlight={s} onCancel={() => onCancel(s.id)} />
          ))}
        </div>
      )}
    </div>
  );
}

function statusClasses(status: SpotlightStatus): string {
  switch (status) {
    case "APPROVED":
      return "bg-success-soft text-success";
    case "REJECTED":
      return "bg-error-soft text-error";
    default:
      return "bg-white/80 text-ink";
  }
}

function SpotlightCard({ spotlight, onCancel }: { spotlight: Spotlight; onCancel: () => void }) {
  const src = mediaSrc(spotlight.heroImageUrl);
  const fg = autoFg(spotlight.bgColor);
  return (
    <div className="overflow-hidden rounded-lg border border-hairline">
      <div className="flex items-center gap-md p-lg" style={{ backgroundColor: spotlight.bgColor }}>
        <div className="relative size-16 shrink-0 overflow-hidden rounded-md border border-white/20 bg-white/30">
          {src ? (
            <Image src={src} alt={spotlight.dealLabel} fill unoptimized className="object-cover" sizes="64px" />
          ) : null}
        </div>
        <div className="min-w-0 flex-1" style={{ color: fg }}>
          <p className="truncate text-title-sm font-bold">{spotlight.dealLabel}</p>
          {spotlight.subtitle ? (
            <p className="truncate text-body-sm opacity-80">{spotlight.subtitle}</p>
          ) : null}
        </div>
        <span
          className={`inline-flex shrink-0 items-center rounded-full px-sm py-px text-body-sm font-semibold ${statusClasses(
            spotlight.status,
          )}`}
        >
          {SPOTLIGHT_STATUS_LABELS[spotlight.status]}
        </span>
      </div>

      <div className="p-lg">
        <p className="text-body-sm text-muted">{formatDateRange(spotlight.startAt, spotlight.endAt)}</p>

        {spotlight.status === "REJECTED" && spotlight.rejectionReason ? (
          <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
            Reason: {spotlight.rejectionReason}
          </p>
        ) : null}

        {spotlight.status === "PENDING" ? (
          <div className="mt-md flex justify-end">
            <button
              type="button"
              onClick={onCancel}
              className="inline-flex h-9 items-center gap-sm rounded-button px-md text-label-md text-muted transition-colors hover:text-error"
            >
              <X size={16} /> Cancel request
            </button>
          </div>
        ) : null}
      </div>
    </div>
  );
}
