"use client";

import { useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { ImageOff } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { DateTimeField, SelectField, TextField, ToggleField } from "@/shared/ui/form";
import { ImageUploadField } from "@/shared/ui/image-upload";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { createBanner, updateBanner, type BannerInput } from "./api";
import { PLACEMENTS, PLACEMENT_LABELS, type Banner, type Placement } from "./schema";

const BACK = "/dashboard/banners";

const PLACEMENT_OPTIONS = PLACEMENTS.map((p) => ({ value: p, label: PLACEMENT_LABELS[p] }));

/** Create / edit a single image banner. Pass `banner` to edit an existing row. */
export function BannerEditor({ banner }: { banner?: Banner }) {
  const router = useRouter();
  const editing = banner != null;

  const [placement, setPlacement] = useState<Placement>(banner?.placement ?? "HERO");
  const [imageUrl, setImageUrl] = useState<string | null>(banner?.imageUrl ?? null);
  const [linkUrl, setLinkUrl] = useState(banner?.linkUrl ?? "");
  const [sortOrder, setSortOrder] = useState(String(banner?.sortOrder ?? 0));
  const [isActive, setIsActive] = useState(banner?.isActive ?? true);
  const [startAt, setStartAt] = useState<string | null>(banner?.startAt ?? null);
  const [endAt, setEndAt] = useState<string | null>(banner?.endAt ?? null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save() {
    setError(null);
    if (!imageUrl) return setError("A banner image is required.");
    const link = linkUrl.trim();
    if (link && !/^https?:\/\//i.test(link) && !link.startsWith("/")) {
      return setError("Link must be an absolute URL or a path starting with /.");
    }
    if (startAt && endAt && new Date(endAt) <= new Date(startAt)) {
      return setError("End time must be after the start time.");
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
      if (editing) await updateBanner(banner.id, payload);
      else await createBanner(payload);
      router.push(BACK);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Save failed.");
      setBusy(false);
    }
  }

  const previewSrc = mediaSrc(imageUrl);

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Banners" />
      <h1 className="mt-md text-headline-md text-ink">{editing ? "Edit banner" : "New banner"}</h1>
      <p className="mt-xs text-body-md text-muted">
        Upload an image, choose where it shows, and where a tap takes the shopper. The image is the
        whole banner — design any text into the artwork itself.
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl grid gap-xl lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[440px_minmax(0,1fr)]">
        {/* Preview */}
        <div className="lg:sticky lg:top-lg lg:self-start">
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">Preview</p>
          <div className="relative aspect-[16/10] w-full overflow-hidden rounded-lg border border-hairline bg-hero-panel">
            {previewSrc ? (
              <Image src={previewSrc} alt="" fill unoptimized className="object-cover" sizes="440px" />
            ) : (
              <div className="flex size-full flex-col items-center justify-center gap-sm text-subtle">
                <ImageOff size={28} />
                <span className="text-body-sm">No image yet</span>
              </div>
            )}
          </div>
        </div>

        {/* Form */}
        <div className="flex max-w-content flex-col gap-lg">
          <ImageUploadField
            label="Banner image"
            aspect="banner"
            url={imageUrl}
            onChange={setImageUrl}
            helper="Shown edge-to-edge on the customer home. Use ready-made artwork."
          />
          <SelectField
            label="Placement"
            value={placement}
            onChange={setPlacement}
            options={PLACEMENT_OPTIONS}
            helper="Which home slot this banner appears in."
          />
          <TextField
            label="Link (optional)"
            value={linkUrl}
            onChange={setLinkUrl}
            placeholder="/shop/my-store or https://…"
            helper="Where a tap takes the shopper. Leave blank for a non-tappable banner."
          />
          <TextField
            label="Sort order"
            value={sortOrder}
            onChange={setSortOrder}
            inputMode="numeric"
            helper="Lower numbers show first within the placement."
          />
          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <DateTimeField label="Starts (optional)" value={startAt} onChange={setStartAt} />
            <DateTimeField label="Ends (optional)" value={endAt} onChange={setEndAt} />
          </div>
          <ToggleField
            label="Active"
            description="Inactive banners are hidden from the storefront."
            checked={isActive}
            onChange={setIsActive}
          />
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
          {busy ? "Saving…" : editing ? "Save changes" : "Create banner"}
        </button>
      </div>
    </div>
  );
}
