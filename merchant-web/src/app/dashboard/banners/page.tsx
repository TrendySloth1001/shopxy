"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { Images, ImageOff, Pencil, Plus, RefreshCw, Trash2 } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { formatDateRange } from "@/shared/datetime";
import { deleteBanner, listBanners } from "@/features/banners/api";
import type { Banner } from "@/features/banners/schema";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

export default function BannersPage() {
  const t = useTranslations("banners");
  const [items, setItems] = useState<Banner[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const rows = await listBanners();
        if (!active) return;
        setItems(rows);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("errors.load"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, t]);

  async function onDelete(id: number) {
    try {
      await deleteBanner(id);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("errors.delete"));
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Images}
        tone="indigo"
        title={t("list.title")}
        subtitle={t("list.subtitle")}
      >
        <button
          type="button"
          onClick={reload}
          disabled={loading}
          aria-label={t("actions.refresh")}
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <MaybeLocked area="marketing" label={t("actions.new")}>
          <Link
            href="/dashboard/banners/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> {t("actions.new")}
          </Link>
        </MaybeLocked>
      </PageHeader>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <Divider className="my-xl" />

      {loading ? (
        <ListRowsSkeleton />
      ) : items.length === 0 ? (
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <span className="flex size-12 items-center justify-center rounded-full bg-accent-indigo-soft text-accent-indigo">
            <Images size={22} />
          </span>
          <p className="text-body-md text-muted">{t("list.empty")}</p>
          <MaybeLocked area="marketing" label={t("actions.new")}>
            <Link
              href="/dashboard/banners/new"
              className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              <Plus size={16} /> {t("actions.new")}
            </Link>
          </MaybeLocked>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-lg sm:grid-cols-2 xl:grid-cols-3">
          {items.map((b) => (
            <BannerCard key={b.id} banner={b} onDelete={() => onDelete(b.id)} />
          ))}
        </div>
      )}
    </div>
  );
}

function BannerCard({ banner, onDelete }: { banner: Banner; onDelete: () => void }) {
  const t = useTranslations("banners");
  const src = mediaSrc(banner.imageUrl);
  return (
    <div className="overflow-hidden rounded-lg border border-hairline">
      <div className="relative aspect-[16/9] w-full bg-hero-panel">
        {src ? (
          <Image src={src} alt="" fill unoptimized className="object-cover" sizes="(min-width:1280px) 33vw, 50vw" />
        ) : (
          <div className="flex size-full items-center justify-center text-subtle">
            <ImageOff size={24} />
          </div>
        )}
        {!banner.isActive ? (
          <span className="absolute left-sm top-sm rounded-full bg-surface/85 px-sm py-px text-body-sm font-semibold text-muted">
            {t("card.off")}
          </span>
        ) : null}
      </div>
      <div className="flex items-center justify-between gap-md p-md">
        <div className="min-w-0">
          <p className="truncate text-title-sm font-bold text-ink">{t(`placement.${banner.placement}`)}</p>
          <p className="truncate text-body-sm text-muted">
            {banner.productCount > 0
              ? banner.productCount === 1
                ? t("card.productCountOne", { count: banner.productCount })
                : t("card.productCountOther", { count: banner.productCount })
              : banner.linkUrl
                ? banner.linkUrl
                : t("card.noLink")}
            {banner.startAt || banner.endAt ? ` · ${formatDateRange(banner.startAt, banner.endAt)}` : ""}
          </p>
        </div>
        <div className="flex shrink-0 items-center gap-xs">
          <Link
            href={`/dashboard/banners/${banner.id}`}
            aria-label={t("actions.edit")}
            className="inline-flex size-9 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint"
          >
            <Pencil size={15} />
          </Link>
          <button
            type="button"
            onClick={onDelete}
            aria-label={t("actions.delete")}
            className="inline-flex size-9 items-center justify-center rounded-button border border-hairline text-muted transition-colors hover:text-error"
          >
            <Trash2 size={15} />
          </button>
        </div>
      </div>
    </div>
  );
}
