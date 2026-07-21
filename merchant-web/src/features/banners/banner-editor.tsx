"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { ImageOff, Plus, Trash2 } from "@/shared/icons";
import { BackLink } from "@/shared/ui/page-header";
import { DateTimeField, SelectField, TextField, ToggleField } from "@/shared/ui/form";
import { ImageUploadField } from "@/shared/ui/image-upload";
import { PickerModal } from "@/shared/ui/picker-modal";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { listProducts } from "@/features/products/api";
import type { Product } from "@/features/products/schema";
import {
  createBanner,
  listBannerProducts,
  replaceBannerProducts,
  updateBanner,
  type BannerInput,
} from "./api";
import {
  DISCOUNT_TYPES,
  PLACEMENTS,
  type Banner,
  type DiscountType,
  type Placement,
} from "./schema";

const BACK = "/dashboard/banners";

/** A pinned product being edited in the form. */
type PinnedRow = {
  productId: number;
  name: string;
  sku: string | null;
  imageUrl: string | null;
  sellingPrice: number;
  discountType: DiscountType;
  discountValue: string;
};

const loadProducts = (s: string) => listProducts({ search: s, limit: "20" }).then((r) => r.data);

function rupee(n: number): string {
  return `₹${Math.round(n).toLocaleString("en-IN")}`;
}

/** Effective sale price preview, mirroring the backend clamp. */
function salePreview(sellingPrice: number, type: DiscountType, raw: string): number {
  const v = Number.parseFloat(raw);
  if (!Number.isFinite(v) || v <= 0) return sellingPrice;
  const perUnit =
    type === "PERCENT"
      ? (sellingPrice * Math.min(90, v)) / 100
      : Math.min(v, Math.max(0, sellingPrice - 0.01));
  return Math.max(0, +(sellingPrice - perUnit).toFixed(2));
}

/** Create / edit a single image banner + its pinned products. */
export function BannerEditor({ banner }: { banner?: Banner }) {
  const router = useRouter();
  const t = useTranslations("banners");
  const editing = banner != null;

  const placementOptions = PLACEMENTS.map((p) => ({ value: p, label: t(`placement.${p}`) }));
  const discountOptions = DISCOUNT_TYPES.map((d) => ({
    value: d,
    label: d === "PERCENT" ? t("form.discountPercent") : t("form.discountAmount"),
  }));

  const [placement, setPlacement] = useState<Placement>(banner?.placement ?? "HERO");
  const [imageUrl, setImageUrl] = useState<string | null>(banner?.imageUrl ?? null);
  const [linkUrl, setLinkUrl] = useState(banner?.linkUrl ?? "");
  const [sortOrder, setSortOrder] = useState(String(banner?.sortOrder ?? 0));
  const [isActive, setIsActive] = useState(banner?.isActive ?? true);
  const [startAt, setStartAt] = useState<string | null>(banner?.startAt ?? null);
  const [endAt, setEndAt] = useState<string | null>(banner?.endAt ?? null);
  const [products, setProducts] = useState<PinnedRow[]>([]);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Load existing pinned products when editing.
  useEffect(() => {
    if (!banner) return;
    let active = true;
    void listBannerProducts(banner.id)
      .then((rows) => {
        if (!active) return;
        setProducts(
          rows.map((r) => ({
            productId: r.productId,
            name: r.product.name,
            sku: r.product.sku ?? null,
            imageUrl: r.product.images[0]?.url ?? null,
            sellingPrice: r.product.sellingPrice,
            discountType: r.discountType,
            discountValue: r.discountValue > 0 ? String(r.discountValue) : "",
          })),
        );
      })
      .catch(() => {});
    return () => {
      active = false;
    };
  }, [banner]);

  function addProduct(p: Product) {
    setProducts((prev) =>
      prev.some((r) => r.productId === p.id)
        ? prev
        : [
            ...prev,
            {
              productId: p.id,
              name: p.name,
              sku: p.sku ?? null,
              imageUrl: p.images?.[0]?.url ?? null,
              sellingPrice: p.sellingPrice,
              discountType: "PERCENT",
              discountValue: "",
            },
          ],
    );
    setPickerOpen(false);
  }

  function patchRow(productId: number, patch: Partial<PinnedRow>) {
    setProducts((prev) => prev.map((r) => (r.productId === productId ? { ...r, ...patch } : r)));
  }

  function removeRow(productId: number) {
    setProducts((prev) => prev.filter((r) => r.productId !== productId));
  }

  async function save() {
    setError(null);
    if (!imageUrl) return setError(t("form.errors.imageRequired"));
    const link = linkUrl.trim();
    if (link && !/^https?:\/\//i.test(link) && !link.startsWith("/")) {
      return setError(t("form.errors.invalidLink"));
    }
    if (startAt && endAt && new Date(endAt) <= new Date(startAt)) {
      return setError(t("form.errors.endBeforeStart"));
    }
    const order = Number.parseInt(sortOrder, 10);
    const payload: BannerInput = {
      placement,
      imageUrl,
      linkUrl: link || null,
      sortOrder: Number.isFinite(order) ? order : 0,
      isActive,
      startAt,
      endAt,
    };
    setBusy(true);
    try {
      const saved = editing ? await updateBanner(banner.id, payload) : await createBanner(payload);
      await replaceBannerProducts(
        saved.id,
        products.map((r, i) => ({
          productId: r.productId,
          discountType: r.discountType,
          discountValue: Number.parseFloat(r.discountValue) || 0,
          position: i,
        })),
      );
      router.push(BACK);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("form.errors.saveFailed"));
      setBusy(false);
    }
  }

  const previewSrc = mediaSrc(imageUrl);

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label={t("list.title")} />
      <h1 className="mt-md text-headline-md text-ink">{editing ? t("form.editTitle") : t("form.newTitle")}</h1>
      <p className="mt-xs text-body-md text-muted">
        {t("form.subtitle")}
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl grid gap-xl lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[440px_minmax(0,1fr)]">
        {/* Preview */}
        <div className="lg:sticky lg:top-lg lg:self-start">
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">{t("form.preview")}</p>
          <div className="relative aspect-[16/10] w-full overflow-hidden rounded-lg border border-hairline bg-hero-panel">
            {previewSrc ? (
              <Image src={previewSrc} alt="" fill unoptimized className="object-cover" sizes="440px" />
            ) : (
              <div className="flex size-full flex-col items-center justify-center gap-sm text-subtle">
                <ImageOff size={28} />
                <span className="text-body-sm">{t("form.noImageYet")}</span>
              </div>
            )}
          </div>
        </div>

        {/* Form */}
        <div className="flex max-w-content flex-col gap-lg">
          <ImageUploadField
            label={t("form.imageLabel")}
            aspect="banner"
            url={imageUrl}
            onChange={setImageUrl}
            helper={t("form.imageHelper")}
          />
          <SelectField
            label={t("form.placementLabel")}
            value={placement}
            onChange={setPlacement}
            options={placementOptions}
            helper={t("form.placementHelper")}
          />
          <TextField
            label={t("form.linkLabel")}
            value={linkUrl}
            onChange={setLinkUrl}
            placeholder={t("form.linkPlaceholder")}
            helper={t("form.linkHelper")}
          />
          <TextField
            label={t("form.sortOrderLabel")}
            value={sortOrder}
            onChange={setSortOrder}
            inputMode="numeric"
            helper={t("form.sortOrderHelper")}
          />
          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <DateTimeField label={t("form.startsLabel")} value={startAt} onChange={setStartAt} />
            <DateTimeField label={t("form.endsLabel")} value={endAt} onChange={setEndAt} />
          </div>
          <ToggleField
            label={t("form.activeLabel")}
            description={t("form.activeDescription")}
            checked={isActive}
            onChange={setIsActive}
          />

          {/* Pinned products */}
          <div className="flex flex-col gap-sm">
            <div className="flex items-center justify-between">
              <span className="text-label-md text-muted">{t("products.title")}</span>
              <button
                type="button"
                onClick={() => setPickerOpen(true)}
                className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
              >
                <Plus size={15} /> {t("products.add")}
              </button>
            </div>
            {products.length === 0 ? (
              <p className="rounded-md bg-surface-tint px-md py-sm text-body-sm text-muted">
                {t("products.empty")}
              </p>
            ) : (
              <div className="flex flex-col gap-sm">
                {products.map((r) => {
                  const sale = salePreview(r.sellingPrice, r.discountType, r.discountValue);
                  const thumb = mediaSrc(r.imageUrl);
                  return (
                    <div
                      key={r.productId}
                      className="flex items-center gap-md rounded-md border border-hairline p-sm"
                    >
                      <span className="relative size-12 shrink-0 overflow-hidden rounded-md bg-hero-panel">
                        {thumb ? (
                          <Image src={thumb} alt="" fill unoptimized className="object-cover" sizes="48px" />
                        ) : null}
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-body-md text-ink">{r.name}</p>
                        <p className="text-body-sm text-muted">
                          {rupee(r.sellingPrice)}
                          {sale < r.sellingPrice ? ` → ${rupee(sale)}` : ""}
                        </p>
                      </div>
                      <div className="w-[110px] shrink-0">
                        <SelectField
                          label=""
                          value={r.discountType}
                          onChange={(v) => patchRow(r.productId, { discountType: v })}
                          options={discountOptions}
                        />
                      </div>
                      <div className="w-[88px] shrink-0">
                        <TextField
                          label=""
                          value={r.discountValue}
                          onChange={(v) => patchRow(r.productId, { discountValue: v })}
                          inputMode="decimal"
                          placeholder="0"
                        />
                      </div>
                      <button
                        type="button"
                        onClick={() => removeRow(r.productId)}
                        aria-label={t("products.remove")}
                        className="inline-flex size-9 shrink-0 items-center justify-center rounded-button border border-hairline text-muted transition-colors hover:text-error"
                      >
                        <Trash2 size={15} />
                      </button>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Sticky action bar */}
      <div className="sticky bottom-0 mt-xxl -mx-lg flex items-center justify-end gap-md border-t border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
        <Link
          href={BACK}
          className="inline-flex h-11 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink"
        >
          {t("actions.cancel")}
        </Link>
        <button
          type="button"
          onClick={save}
          disabled={busy}
          className="inline-flex h-11 items-center rounded-button bg-brand px-xl text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {busy ? t("actions.saving") : editing ? t("actions.saveChanges") : t("actions.create")}
        </button>
      </div>

      {pickerOpen ? (
        <PickerModal<Product>
          title={t("products.add")}
          placeholder={t("picker.searchPlaceholder")}
          load={loadProducts}
          rowOf={(p) => ({
            title: p.name,
            subtitle: p.sku ?? undefined,
            meta: rupee(p.sellingPrice),
          })}
          onPick={addProduct}
          onClose={() => setPickerOpen(false)}
          emptyHint={t("picker.empty")}
        />
      ) : null}
    </div>
  );
}
