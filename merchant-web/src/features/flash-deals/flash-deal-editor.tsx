"use client";

import { useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { Zap } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { DateTimeField, TextField } from "@/shared/ui/form";
import { isoFromNow, nowIso } from "@/shared/datetime";
import { mediaSrc } from "@/features/products/components/product-thumb";
import {
  ProductPicker,
  type PickedProduct,
} from "@/features/products/components/product-picker";
import { createFlashDeal, updateFlashDeal } from "./api";
import { discountPct, money, soldPct } from "./format";
import type { FlashSale } from "./schema";

const BACK = "/dashboard/flash-deals";

/** Full-page flash-deal editor with a live customer-card preview. */
export function FlashDealEditor({ existing }: { existing: FlashSale | null }) {
  const router = useRouter();
  const isEdit = existing != null;

  const [picked, setPicked] = useState<PickedProduct | null>(
    existing?.product
      ? {
          id: existing.product.id,
          name: existing.product.name,
          sku: existing.product.sku ?? "",
          mrp: existing.product.mrp,
          sellingPrice: existing.product.sellingPrice,
          imageUrl: existing.product.images[0]?.url ?? null,
        }
      : null,
  );
  const [pickerOpen, setPickerOpen] = useState(false);
  const [flashPrice, setFlashPrice] = useState(existing ? String(existing.flashPrice) : "");
  const [stockLimit, setStockLimit] = useState(existing ? String(existing.stockLimit) : "50");
  const [startAt, setStartAt] = useState<string | null>(existing?.startAt ?? nowIso());
  const [endAt, setEndAt] = useState<string | null>(
    existing?.endAt ?? isoFromNow(4 * 60 * 60 * 1000),
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const priceNum = Number(flashPrice);
  const stockNum = Number(stockLimit);
  const mrp = picked?.mrp ?? 0;
  const off = picked ? discountPct(mrp, priceNum || 0) : 0;
  const priceError =
    flashPrice && mrp > 0 && priceNum >= mrp ? `Must be below MRP (${money(mrp)})` : null;

  function onPickProduct(p: PickedProduct) {
    setPicked(p);
    setPickerOpen(false);
    if (!flashPrice && p.sellingPrice > 0) setFlashPrice((p.sellingPrice * 0.8).toFixed(2));
  }

  async function save() {
    setError(null);
    if (!isEdit && !picked) return setError("Pick a product first.");
    if (!flashPrice || Number.isNaN(priceNum) || priceNum < 0) {
      return setError("Enter a valid flash price.");
    }
    if (mrp > 0 && priceNum >= mrp) return setError("Flash price must be below MRP.");
    if (!stockLimit || !Number.isInteger(stockNum) || stockNum <= 0) {
      return setError("Enter a positive stock cap.");
    }
    if (!startAt || !endAt || new Date(endAt) <= new Date(startAt)) {
      return setError("End time must be after the start time.");
    }
    setBusy(true);
    try {
      if (isEdit) {
        await updateFlashDeal(existing.id, { flashPrice: priceNum, stockLimit: stockNum, startAt, endAt });
      } else {
        await createFlashDeal({
          productId: picked!.id,
          flashPrice: priceNum,
          stockLimit: stockNum,
          startAt,
          endAt,
        });
      }
      router.push(BACK);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Save failed.");
      setBusy(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Flash deals" />
      <h1 className="mt-md text-headline-md text-ink">{isEdit ? "Edit flash deal" : "New flash deal"}</h1>
      <p className="mt-xs text-body-md text-muted">
        Set a discounted price and a hard stock cap — the preview shows the customer card.
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl grid gap-xl lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[420px_minmax(0,1fr)]">
        {/* Preview */}
        <div className="lg:sticky lg:top-lg lg:self-start">
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">Preview</p>
          <FlashCardPreview
            product={picked}
            flashPrice={Number.isFinite(priceNum) ? priceNum : 0}
            off={off}
            sold={existing?.soldCount ?? 0}
            stockLimit={Number.isInteger(stockNum) && stockNum > 0 ? stockNum : 0}
          />
        </div>

        {/* Form */}
        <div className="flex max-w-content flex-col gap-lg">
          {isEdit ? (
            <div className="rounded-md bg-hero-panel px-md py-sm">
              <span className="text-body-md text-ink">{picked?.name}</span>
              <span className="ml-sm text-body-sm text-muted">
                SKU {picked?.sku || "—"} · MRP {money(mrp)} · product is fixed
              </span>
            </div>
          ) : picked ? (
            <div className="flex items-center gap-md rounded-md bg-hero-panel px-md py-sm">
              <span className="min-w-0 flex-1 truncate text-body-md text-ink">
                {picked.name} · MRP {money(picked.mrp)}
              </span>
              <button
                type="button"
                onClick={() => setPickerOpen(true)}
                className="text-label-md text-brand-strong transition-colors hover:text-brand"
              >
                Change
              </button>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => setPickerOpen(true)}
              className="inline-flex h-10 items-center justify-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              Pick a product
            </button>
          )}

          <div className="grid grid-cols-2 gap-md">
            <TextField
              label="Flash price (₹)"
              value={flashPrice}
              onChange={setFlashPrice}
              inputMode="decimal"
              helper={!priceError && off > 0 ? `${off}% off MRP` : undefined}
              error={priceError}
            />
            <TextField
              label="Stock cap"
              value={stockLimit}
              onChange={setStockLimit}
              inputMode="numeric"
              helper="Sells out and stops here"
            />
          </div>

          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <DateTimeField label="Starts" value={startAt} onChange={setStartAt} />
            <DateTimeField label="Ends" value={endAt} onChange={setEndAt} />
          </div>
        </div>
      </div>

      {/* Sticky action bar */}
      <div className="sticky bottom-0 mt-xxl -mx-lg flex items-center justify-end gap-md border-t border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
        <Link
          href={BACK}
          className="inline-flex h-11 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink"
        >
          Cancel
        </Link>
        <button
          type="button"
          onClick={save}
          disabled={busy}
          className="inline-flex h-11 items-center rounded-button bg-brand px-xl text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {busy ? "Saving…" : isEdit ? "Save changes" : "Create flash deal"}
        </button>
      </div>

      {pickerOpen ? <ProductPicker onPick={onPickProduct} onClose={() => setPickerOpen(false)} /> : null}
    </div>
  );
}

export function FlashCardPreview({
  product,
  flashPrice,
  off,
  sold,
  stockLimit,
}: {
  product: PickedProduct | null;
  flashPrice: number;
  off: number;
  sold: number;
  stockLimit: number;
}) {
  const src = mediaSrc(product?.imageUrl);
  const pct = soldPct({ soldCount: sold, stockLimit });
  return (
    <div className="overflow-hidden rounded-lg border border-hairline bg-white shadow-floating">
      <div className="relative aspect-[4/3] bg-surface-tint">
        {src ? <Image src={src} alt="" fill unoptimized sizes="420px" className="object-cover" /> : null}
        {off > 0 ? (
          <span className="absolute left-md top-md rounded-md bg-flash-deal px-sm py-px text-body-sm font-extrabold text-white shadow-floating">
            -{off}%
          </span>
        ) : null}
        <span className="absolute right-md top-md inline-flex items-center gap-xs rounded-full bg-white/90 px-sm py-px text-body-sm font-bold text-flash-deal">
          <Zap size={13} /> Flash
        </span>
      </div>
      <div className="p-lg">
        <p className="truncate text-body-md text-ink">
          {product?.name ?? "Pick a product to preview"}
        </p>
        <p className="mt-xs flex items-baseline gap-sm">
          <span className="text-title-lg font-bold text-flash-deal">{money(flashPrice)}</span>
          {product && product.mrp > 0 ? (
            <span className="text-body-md text-muted line-through">{money(product.mrp)}</span>
          ) : null}
        </p>
        <div className="mt-md">
          <div className="h-2 w-full overflow-hidden rounded-full bg-flash-deal-soft">
            <div className="h-full rounded-full bg-flash-deal" style={{ width: `${pct * 100}%` }} />
          </div>
          <p className="mt-xs text-body-sm font-semibold text-flash-deal">
            {stockLimit > 0 ? `${sold} / ${stockLimit} claimed` : "Set a stock cap"}
          </p>
        </div>
      </div>
    </div>
  );
}
