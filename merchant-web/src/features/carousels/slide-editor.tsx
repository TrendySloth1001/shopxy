"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft, ArrowDown, ArrowUp, Check, Plus, Tag, Trash2, X } from "lucide-react";
import {
  HexColorField,
  SelectField,
  TextAreaField,
  TextField,
  ToggleField,
} from "@/shared/ui/form";
import { ImageUploadField } from "@/shared/ui/image-upload";
import { CtaTargetField } from "@/shared/ui/cta-target-field";
import { buildCtaTarget, parseCtaTarget, type CtaKind } from "@/shared/cta-target";
import { ProductThumb } from "@/features/products/components/product-thumb";
import {
  ProductPicker,
  type PickedProduct,
} from "@/features/products/components/product-picker";
import { money } from "@/features/products/format";
import {
  createSlide,
  deleteSlide,
  listSlideProducts,
  replaceSlideProducts,
  updateSlide,
  type SlideWrite,
} from "./api";
import { isHex } from "./color";
import { HeroSlidePreview, type SlidePreviewData } from "./preview";
import {
  DISCOUNT_TYPES,
  DISCOUNT_TYPE_LABELS,
  IMAGE_FITS,
  IMAGE_FIT_LABELS,
  TEMPLATES,
  TEMPLATE_DESCRIPTIONS,
  TEMPLATE_LABELS,
  templateSupportsColors,
  templateSupportsSubtitle,
  templateSupportsText,
  type DiscountType,
  type ImageFit,
  type Slide,
  type Template,
} from "./schema";

/**
 * Full-page slide editor: a sticky live preview beside the form so the merchant
 * sees the slide build up as they type. Used by the create + edit routes under
 * `/dashboard/carousels/[id]/slides/…`.
 */
export function SlideEditor({
  carouselId,
  carouselName,
  existing,
}: {
  carouselId: number;
  carouselName: string;
  existing: Slide | null;
}) {
  const router = useRouter();
  const isEdit = existing != null;
  const backHref = `/dashboard/carousels/${carouselId}`;
  const initialCta = parseCtaTarget(existing?.ctaTarget);

  const [template, setTemplate] = useState<Template>(existing?.template ?? "CLASSIC");
  const [imageFit, setImageFit] = useState<ImageFit>(existing?.imageFit ?? "COVER");
  const [imageUrl, setImageUrl] = useState<string | null>(existing?.imageUrl ?? null);
  const [brandLabel, setBrandLabel] = useState(existing?.brandLabel ?? "");
  const [brandImageUrl, setBrandImageUrl] = useState<string | null>(existing?.brandImageUrl ?? null);
  const [brandImageFit, setBrandImageFit] = useState<ImageFit>(existing?.brandImageFit ?? "COVER");
  const [title, setTitle] = useState(existing?.title ?? "");
  const [subtitle, setSubtitle] = useState(existing?.subtitle ?? "");
  const [eyebrow, setEyebrow] = useState(existing?.eyebrow ?? "");
  const [ctaText, setCtaText] = useState(existing?.ctaText ?? "");
  const [bgColor, setBgColor] = useState(existing?.bgColor ?? "#1F2430");
  const [accentColor, setAccentColor] = useState(existing?.accentColor ?? "#E0533D");
  const [ctaKind, setCtaKind] = useState<CtaKind>(initialCta.kind);
  const [ctaValue, setCtaValue] = useState(initialCta.value);
  const [ctaError, setCtaError] = useState<string | null>(null);
  const [sortOrder, setSortOrder] = useState(String(existing?.sortOrder ?? 0));
  const [isActive, setIsActive] = useState(existing?.isActive ?? true);
  const [busy, setBusy] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const supportsText = templateSupportsText(template);
  const supportsSubtitle = templateSupportsSubtitle(template);
  const supportsColors = templateSupportsColors(template);

  const preview: SlidePreviewData = {
    template,
    imageFit,
    title,
    subtitle,
    eyebrow,
    brandLabel,
    brandImageUrl,
    brandImageFit,
    ctaText,
    imageUrl,
    bgColor: isHex(bgColor) ? bgColor : "#1F2430",
    accentColor: isHex(accentColor) ? accentColor : isHex(bgColor) ? bgColor : "#E0533D",
  };

  async function save() {
    setError(null);
    setCtaError(null);
    if (!imageUrl) return setError("A background image is required.");
    if (!title.trim()) return setError("A title is required.");
    if (!isHex(bgColor)) return setError("Background colour must be a hex value like #1F2430.");
    if (supportsColors && accentColor.trim() && !isHex(accentColor)) {
      return setError("Accent colour must be a hex value like #E0533D.");
    }
    const cta = buildCtaTarget(ctaKind, ctaValue);
    if (cta.error) {
      setCtaError(cta.error);
      return;
    }
    const sort = Number(sortOrder);

    const payload: SlideWrite = {
      template,
      imageFit,
      imageUrl,
      title: title.trim(),
      bgColor: bgColor.trim(),
      sortOrder: Number.isInteger(sort) ? sort : 0,
      isActive,
      subtitle: supportsSubtitle ? subtitle.trim() || null : null,
      eyebrow: supportsText ? eyebrow.trim() || null : null,
      ctaText: supportsText ? ctaText.trim() || null : null,
      ctaTarget: cta.target,
      brandLabel: supportsText ? brandLabel.trim() || null : null,
      brandImageUrl: supportsText ? brandImageUrl : null,
      brandImageFit,
      accentColor: supportsColors ? accentColor.trim() || null : null,
    };

    setBusy(true);
    try {
      if (isEdit) {
        await updateSlide(carouselId, existing.id, payload);
      } else {
        await createSlide(carouselId, payload);
      }
      router.push(backHref);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save the slide.");
      setBusy(false);
    }
  }

  async function onDelete() {
    if (!isEdit) return;
    setDeleting(true);
    try {
      await deleteSlide(carouselId, existing.id);
      router.push(backHref);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not delete the slide.");
      setDeleting(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <Link
        href={backHref}
        className="inline-flex items-center gap-xs text-label-md text-muted transition-colors hover:text-ink"
      >
        <ArrowLeft size={16} /> {carouselName}
      </Link>
      <h1 className="mt-md text-headline-md text-ink">{isEdit ? "Edit slide" : "New slide"}</h1>
      <p className="mt-xs text-body-md text-muted">
        Design the slide on the right — the preview updates as you type.
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl grid gap-xl lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[520px_minmax(0,1fr)]">
        {/* Preview — sticky on desktop so it stays visible while scrolling the form */}
        <div className="lg:sticky lg:top-lg lg:self-start">
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">Preview</p>
          <HeroSlidePreview data={preview} />
          <p className="mt-sm text-body-sm text-subtle">{TEMPLATE_DESCRIPTIONS[template]}</p>
        </div>

        {/* Form */}
        <div className="flex max-w-content flex-col gap-lg">
          <SelectField<Template>
            label="Slide design"
            value={template}
            onChange={setTemplate}
            options={TEMPLATES.map((t) => ({ value: t, label: TEMPLATE_LABELS[t] }))}
          />

          <ImageUploadField
            label="Background image"
            aspect="banner"
            url={imageUrl}
            onChange={setImageUrl}
          />
          <SelectField<ImageFit>
            label="Image fit"
            value={imageFit}
            onChange={setImageFit}
            options={IMAGE_FITS.map((f) => ({ value: f, label: IMAGE_FIT_LABELS[f] }))}
          />

          {supportsText ? (
            <div className="rounded-lg border border-hairline p-md">
              <p className="text-label-md text-muted">Brand</p>
              <p className="mt-px text-body-sm text-subtle">
                Logo and label render together on the slide; either is optional.
              </p>
              <div className="mt-md flex flex-col gap-md">
                <ImageUploadField
                  label="Brand logo"
                  aspect="round"
                  url={brandImageUrl}
                  onChange={setBrandImageUrl}
                />
                {brandImageUrl ? (
                  <SelectField<ImageFit>
                    label="Logo fit"
                    value={brandImageFit}
                    onChange={setBrandImageFit}
                    options={IMAGE_FITS.map((f) => ({ value: f, label: IMAGE_FIT_LABELS[f] }))}
                  />
                ) : null}
                <TextField label="Brand label" value={brandLabel} onChange={setBrandLabel} />
              </div>
            </div>
          ) : null}

          <TextField label="Title" value={title} onChange={setTitle} placeholder="Your slide title" />
          {supportsSubtitle ? (
            <TextAreaField label="Subtitle" value={subtitle} onChange={setSubtitle} rows={2} />
          ) : null}
          {supportsText ? (
            <>
              <TextField
                label="Eyebrow"
                value={eyebrow}
                onChange={setEyebrow}
                helper="Tiny copy above the title."
              />
              <TextField
                label="Button label"
                value={ctaText}
                onChange={setCtaText}
                helper='Defaults to "Shop now".'
              />
            </>
          ) : null}

          {supportsColors ? (
            <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
              <HexColorField label="Background" value={bgColor} onChange={setBgColor} />
              <HexColorField label="Accent" value={accentColor} onChange={setAccentColor} />
            </div>
          ) : (
            <HexColorField
              label="Background / letterbox colour"
              value={bgColor}
              onChange={setBgColor}
            />
          )}

          {supportsText ? (
            <CtaTargetField
              kind={ctaKind}
              value={ctaValue}
              onKindChange={(k) => {
                setCtaKind(k);
                setCtaError(null);
              }}
              onValueChange={(v) => {
                setCtaValue(v);
                setCtaError(null);
              }}
              error={ctaError}
            />
          ) : null}

          <div className="grid grid-cols-1 gap-md sm:grid-cols-2 sm:items-center">
            <TextField
              label="Sort order"
              value={sortOrder}
              onChange={setSortOrder}
              inputMode="numeric"
              helper="Lower numbers appear first."
            />
            <ToggleField label="Active" checked={isActive} onChange={setIsActive} />
          </div>
        </div>
      </div>

      {/* Discounted products — needs a persisted slide id to attach to */}
      <div className="mt-xl max-w-content">
        <div className="flex items-center gap-sm">
          <Tag size={18} className="text-brand-strong" />
          <h2 className="text-title-md text-ink">Discounted products</h2>
        </div>
        <p className="mt-xs text-body-sm text-muted">
          Pin products to this slide with an offer. Shown on the slide&rsquo;s tap-through with the
          sale price — checkout still charges the product&rsquo;s normal price.
        </p>
        {isEdit ? (
          <SlideProductsEditor slideId={existing.id} />
        ) : (
          <p className="mt-md rounded-md bg-surface-tint px-md py-md text-body-sm text-muted">
            Save the slide first, then reopen it to attach products.
          </p>
        )}
      </div>

      {/* Sticky action bar */}
      <div className="sticky bottom-0 mt-xxl -mx-lg flex items-center justify-between gap-md border-t border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
        {isEdit ? (
          <button
            type="button"
            onClick={onDelete}
            disabled={deleting || busy}
            className="inline-flex h-10 items-center gap-sm rounded-button px-md text-label-md text-muted transition-colors hover:text-error disabled:text-disabled"
          >
            <Trash2 size={16} /> {deleting ? "Deleting…" : "Delete slide"}
          </button>
        ) : (
          <span />
        )}
        <div className="flex items-center gap-md">
          <Link
            href={backHref}
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
            {busy ? "Saving…" : isEdit ? "Save slide" : "Create slide"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Discounted products section ─────────────────────────────────────────────

type DraftProduct = {
  productId: number;
  name: string;
  sku: string;
  mrp: number;
  sellingPrice: number;
  imageUrl: string | null;
  discountType: DiscountType;
  /** Kept as a string for free editing; parsed on preview/save. */
  discountValue: string;
};

/** Local sale-price preview (the backend clamps + recomputes on save). */
function previewSalePrice(d: DraftProduct): number {
  const v = Number(d.discountValue) || 0;
  const sale = d.discountType === "PERCENT" ? d.sellingPrice * (1 - v / 100) : d.sellingPrice - v;
  return Math.max(0, sale);
}

function SlideProductsEditor({ slideId }: { slideId: number }) {
  const [items, setItems] = useState<DraftProduct[]>([]);
  const [loading, setLoading] = useState(true);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const rows = await listSlideProducts(slideId);
        if (!active) return;
        setItems(
          rows.map((r) => ({
            productId: r.productId,
            name: r.product.name,
            sku: r.product.sku ?? "",
            mrp: r.product.mrp,
            sellingPrice: r.product.sellingPrice,
            imageUrl: r.product.images[0]?.url ?? null,
            discountType: r.discountType,
            discountValue: String(r.discountValue),
          })),
        );
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load slide products.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [slideId]);

  function patch(index: number, change: Partial<DraftProduct>) {
    setItems((prev) => prev.map((it, i) => (i === index ? { ...it, ...change } : it)));
    setSaved(false);
  }

  function move(index: number, dir: -1 | 1) {
    setItems((prev) => {
      const next = [...prev];
      const target = index + dir;
      if (target < 0 || target >= next.length) return prev;
      [next[index], next[target]] = [next[target], next[index]];
      return next;
    });
    setSaved(false);
  }

  function remove(index: number) {
    setItems((prev) => prev.filter((_, i) => i !== index));
    setSaved(false);
  }

  function onPick(p: PickedProduct) {
    setPickerOpen(false);
    setItems((prev) => {
      if (prev.some((it) => it.productId === p.id)) return prev;
      return [
        ...prev,
        {
          productId: p.id,
          name: p.name,
          sku: p.sku,
          mrp: p.mrp,
          sellingPrice: p.sellingPrice,
          imageUrl: p.imageUrl,
          discountType: "PERCENT",
          discountValue: "10",
        },
      ];
    });
    setSaved(false);
  }

  async function save() {
    setSaving(true);
    setSaved(false);
    setError(null);
    try {
      const rows = await replaceSlideProducts(
        slideId,
        items.map((it, idx) => ({
          productId: it.productId,
          discountType: it.discountType,
          discountValue: Number(it.discountValue) || 0,
          position: idx,
        })),
      );
      // Re-sync from the server so clamped values + computed prices show.
      setItems(
        rows.map((r) => ({
          productId: r.productId,
          name: r.product.name,
          sku: r.product.sku ?? "",
          mrp: r.product.mrp,
          sellingPrice: r.product.sellingPrice,
          imageUrl: r.product.images[0]?.url ?? null,
          discountType: r.discountType,
          discountValue: String(r.discountValue),
        })),
      );
      setSaved(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save slide products.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="mt-md">
      {error ? (
        <p className="mb-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {loading ? (
        <p className="py-lg text-body-sm text-subtle">Loading…</p>
      ) : items.length === 0 ? (
        <p className="rounded-md bg-surface-tint px-md py-lg text-center text-body-sm text-muted">
          No products pinned yet.
        </p>
      ) : (
        <div>
          {items.map((it, i) => (
            <ProductOfferRow
              key={it.productId}
              item={it}
              isFirst={i === 0}
              isLast={i === items.length - 1}
              onChange={(c) => patch(i, c)}
              onUp={() => move(i, -1)}
              onDown={() => move(i, 1)}
              onRemove={() => remove(i)}
            />
          ))}
        </div>
      )}

      <div className="mt-md flex flex-wrap items-center gap-md">
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
        >
          <Plus size={16} /> Add product
        </button>
        <button
          type="button"
          onClick={save}
          disabled={saving}
          className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {saving ? "Saving…" : "Save products"}
        </button>
        {saved ? (
          <span className="inline-flex items-center gap-xs text-body-sm text-success">
            <Check size={16} /> Saved
          </span>
        ) : null}
      </div>

      {pickerOpen ? <ProductPicker onPick={onPick} onClose={() => setPickerOpen(false)} /> : null}
    </div>
  );
}

function ProductOfferRow({
  item,
  isFirst,
  isLast,
  onChange,
  onUp,
  onDown,
  onRemove,
}: {
  item: DraftProduct;
  isFirst: boolean;
  isLast: boolean;
  onChange: (change: Partial<DraftProduct>) => void;
  onUp: () => void;
  onDown: () => void;
  onRemove: () => void;
}) {
  const sale = previewSalePrice(item);
  return (
    <div className="flex flex-wrap items-center gap-md border-b border-hairline py-md">
      <ProductThumb url={item.imageUrl} alt={item.name} size={48} />
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{item.name}</p>
        <p className="mt-px flex flex-wrap items-baseline gap-sm text-body-sm">
          <span className="font-semibold text-brand-strong">{money(sale)}</span>
          <span className="text-muted line-through">{money(item.sellingPrice)}</span>
          {item.sku ? <span className="text-subtle">SKU {item.sku}</span> : null}
        </p>
      </div>

      <div className="flex items-center gap-sm">
        <select
          aria-label="Offer type"
          value={item.discountType}
          onChange={(e) => onChange({ discountType: e.target.value as DiscountType })}
          className="h-9 rounded-input border border-hairline bg-white px-sm text-body-sm text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          {DISCOUNT_TYPES.map((t) => (
            <option key={t} value={t}>
              {DISCOUNT_TYPE_LABELS[t]}
            </option>
          ))}
        </select>
        <input
          aria-label="Offer value"
          inputMode="decimal"
          value={item.discountValue}
          onChange={(e) => onChange({ discountValue: e.target.value })}
          className="h-9 w-20 rounded-input border border-hairline bg-white px-sm text-body-sm text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </div>

      <div className="flex items-center">
        <button
          type="button"
          onClick={onUp}
          disabled={isFirst}
          aria-label="Move up"
          className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <ArrowUp size={16} />
        </button>
        <button
          type="button"
          onClick={onDown}
          disabled={isLast}
          aria-label="Move down"
          className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <ArrowDown size={16} />
        </button>
        <button
          type="button"
          onClick={onRemove}
          aria-label="Remove"
          className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-error-soft hover:text-error"
        >
          <X size={16} />
        </button>
      </div>
    </div>
  );
}
