"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, ChevronRight, Plus, Trash2 } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import {
  DateTimeField,
  HexColorField,
  SelectField,
  TextAreaField,
  TextField,
  ToggleField,
} from "@/shared/ui/form";
import { ImageUploadField } from "@/shared/ui/image-upload";
import { CtaTargetField } from "@/shared/ui/cta-target-field";
import { ProductThumb } from "@/features/products/components/product-thumb";
import { buildCtaTarget, parseCtaTarget, type CtaKind } from "@/shared/cta-target";
import {
  createSlide,
  deleteCarousel,
  deleteSlide,
  listSlides,
  updateCarousel,
  updateSlide,
  type CarouselUpdate,
  type SlideWrite,
} from "@/features/carousels/api";
import {
  IMAGE_FITS,
  IMAGE_FIT_LABELS,
  PLACEMENTS,
  PLACEMENT_LABELS,
  TEMPLATES,
  TEMPLATE_DESCRIPTIONS,
  TEMPLATE_LABELS,
  templateSupportsColors,
  templateSupportsSubtitle,
  templateSupportsText,
  carouselSchema,
  type Carousel,
  type ImageFit,
  type Placement,
  type Slide,
  type Template,
} from "@/features/carousels/schema";
import { isHex } from "@/features/carousels/color";
import { HeroSlidePreview, type SlidePreviewData } from "@/features/carousels/preview";

export default function CarouselEditorPage() {
  const params = useParams<{ id: string }>();
  const carouselId = Number(params.id);
  const router = useRouter();

  const [carousel, setCarousel] = useState<Carousel | null>(null);
  const [slides, setSlides] = useState<Slide[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [savingMeta, setSavingMeta] = useState(false);
  const [editingSlide, setEditingSlide] = useState<Slide | "new" | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleteBusy, setDeleteBusy] = useState(false);

  const loadSlides = useCallback(async () => {
    setSlides(await listSlides(carouselId));
  }, [carouselId]);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      if (!Number.isInteger(carouselId)) {
        setError("Invalid carousel.");
        setLoading(false);
        return;
      }
      try {
        const res = await fetch(`/api/carousels/${carouselId}`, { cache: "no-store" });
        if (!res.ok) throw new Error("Could not load the carousel.");
        const c = carouselSchema.parse(await res.json());
        const rows = await listSlides(carouselId);
        if (!active) return;
        setCarousel(c);
        setSlides(rows);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the carousel.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [carouselId]);

  async function patchMeta(patch: CarouselUpdate) {
    setSavingMeta(true);
    setError(null);
    try {
      const updated = await updateCarousel(carouselId, patch);
      setCarousel(updated);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save the carousel.");
    } finally {
      setSavingMeta(false);
    }
  }

  async function onDeleteCarousel() {
    setDeleteBusy(true);
    try {
      await deleteCarousel(carouselId);
      router.push("/dashboard/carousels");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not delete the carousel.");
      setDeleteBusy(false);
    }
  }

  if (loading) {
    return <p className="w-full px-lg py-xxl text-body-sm text-subtle md:px-xxl">Loading…</p>;
  }
  if (error && !carousel) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      </div>
    );
  }
  if (!carousel) return null;

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink />

      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div>
          <h1 className="text-headline-md text-ink">{carousel.name}</h1>
          <p className="mt-xs text-body-md text-muted">
            {PLACEMENT_LABELS[carousel.placement]} · {savingMeta ? "Saving…" : "Changes save automatically"}
          </p>
        </div>
        <button
          type="button"
          onClick={() => setConfirmDelete(true)}
          className="inline-flex h-10 items-center gap-sm rounded-button px-md text-label-md text-muted transition-colors hover:bg-error-soft hover:text-error"
        >
          <Trash2 size={16} /> Delete
        </button>
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <MetaCard carousel={carousel} busy={savingMeta} onPatch={patchMeta} />

      <Divider className="my-xl" />

      <div className="flex items-center justify-between gap-md">
        <h2 className="text-title-md text-ink">
          Slides <span className="text-muted">· {slides.length}</span>
        </h2>
        <button
          type="button"
          onClick={() => setEditingSlide("new")}
          className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Plus size={16} /> Add slide
        </button>
      </div>

      <div className="mt-md">
        {slides.length === 0 ? (
          <p className="rounded-md bg-surface-tint px-md py-lg text-center text-body-sm text-muted">
            No slides yet — tap &ldquo;Add slide&rdquo; to design your first one.
          </p>
        ) : (
          slides.map((s) => (
            <SlideRow key={s.id} slide={s} onClick={() => setEditingSlide(s)} />
          ))
        )}
      </div>

      {editingSlide ? (
        <SlideEditor
          carouselId={carouselId}
          existing={editingSlide === "new" ? null : editingSlide}
          onClose={() => setEditingSlide(null)}
          onSaved={async () => {
            setEditingSlide(null);
            await loadSlides();
          }}
        />
      ) : null}

      {confirmDelete ? (
        <Modal title="Delete carousel?" onClose={() => setConfirmDelete(false)}>
          <p className="text-body-md text-muted">
            Every slide inside it will be removed too. This cannot be undone.
          </p>
          <ModalActions
            busy={deleteBusy}
            danger
            confirmLabel="Delete"
            onCancel={() => setConfirmDelete(false)}
            onConfirm={onDeleteCarousel}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function BackLink() {
  return (
    <Link
      href="/dashboard/carousels"
      className="inline-flex items-center gap-xs text-label-md text-muted transition-colors hover:text-ink"
    >
      <ArrowLeft size={16} /> My carousels
    </Link>
  );
}

function MetaCard({
  carousel,
  busy,
  onPatch,
}: {
  carousel: Carousel;
  busy: boolean;
  onPatch: (patch: CarouselUpdate) => void;
}) {
  const [name, setName] = useState(carousel.name);

  return (
    <div className="mt-lg max-w-content rounded-lg border border-hairline p-lg">
      <div className="flex flex-col gap-lg">
        <TextField
          label="Name"
          value={name}
          onChange={setName}
          helper="Edit, then Save name below."
        />
        <SelectField<Placement>
          label="Placement"
          value={carousel.placement}
          onChange={(p) => onPatch({ placement: p })}
          options={PLACEMENTS.map((p) => ({ value: p, label: PLACEMENT_LABELS[p] }))}
          disabled={busy}
        />
        <div className="grid grid-cols-1 gap-lg sm:grid-cols-2">
          <DateTimeField
            label="Starts at"
            value={carousel.startAt ?? null}
            onChange={(iso) => onPatch({ startAt: iso })}
            helper="Optional"
          />
          <DateTimeField
            label="Ends at"
            value={carousel.endAt ?? null}
            onChange={(iso) => onPatch({ endAt: iso })}
            helper="Optional"
          />
        </div>
        <ToggleField
          label="Active"
          description="When off, every slide in this carousel is hidden regardless of its own settings."
          checked={carousel.isActive}
          onChange={(v) => onPatch({ isActive: v })}
          disabled={busy}
        />
        <div className="flex">
          <button
            type="button"
            disabled={busy || !name.trim() || name.trim() === carousel.name}
            onClick={() => onPatch({ name: name.trim() })}
            className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            Save name
          </button>
        </div>
      </div>
    </div>
  );
}

function SlideRow({ slide, onClick }: { slide: Slide; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center gap-md border-b border-hairline py-sm text-left transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <ProductThumb url={slide.imageUrl} alt={slide.title} size={56} />
      <span className="min-w-0 flex-1">
        <span className="block truncate text-body-md text-ink">{slide.title}</span>
        <span className="mt-px flex items-center gap-sm text-body-sm text-muted">
          {TEMPLATE_LABELS[slide.template]}
          {!slide.isActive ? <span className="text-subtle">· Off</span> : null}
        </span>
      </span>
      <ChevronRight size={18} className="shrink-0 text-subtle" />
    </button>
  );
}

// ── Slide editor ──────────────────────────────────────────────────────────

function SlideEditor({
  carouselId,
  existing,
  onClose,
  onSaved,
}: {
  carouselId: number;
  existing: Slide | null;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const isEdit = existing != null;
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
      // Text-bearing fields only carry through when the template uses them; on
      // image-only we null them out so a switched-away value doesn't linger.
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
      await onSaved();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save the slide.");
    } finally {
      setBusy(false);
    }
  }

  async function onDelete() {
    if (!isEdit) return;
    setDeleting(true);
    try {
      await deleteSlide(carouselId, existing.id);
      await onSaved();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not delete the slide.");
      setDeleting(false);
    }
  }

  return (
    <Modal title={isEdit ? "Edit slide" : "New slide"} onClose={onClose} wide>
      {/* Live preview */}
      <HeroSlidePreview data={preview} />

      {/* Slide design */}
      <SelectField<Template>
        label="Slide design"
        value={template}
        onChange={setTemplate}
        options={TEMPLATES.map((t) => ({ value: t, label: TEMPLATE_LABELS[t] }))}
        helper={TEMPLATE_DESCRIPTIONS[template]}
      />

      {/* Background image */}
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
        <>
          {/* Brand */}
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
        </>
      ) : null}

      {/* Copy */}
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

      {/* Colours */}
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

      {/* CTA */}
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

      {/* Display */}
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

      {error ? <p className="text-body-sm text-error">{error}</p> : null}

      <div className="mt-sm flex items-center justify-between gap-md">
        {isEdit ? (
          <button
            type="button"
            onClick={onDelete}
            disabled={deleting || busy}
            className="inline-flex h-10 items-center gap-sm rounded-button px-md text-label-md text-muted transition-colors hover:text-error disabled:text-disabled"
          >
            <Trash2 size={16} /> {deleting ? "Deleting…" : "Delete"}
          </button>
        ) : (
          <span />
        )}
        <div className="flex items-center gap-md">
          <button
            type="button"
            onClick={onClose}
            disabled={busy}
            className="inline-flex h-10 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink disabled:text-disabled"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={save}
            disabled={busy}
            className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
          >
            {busy ? "Saving…" : isEdit ? "Save slide" : "Create slide"}
          </button>
        </div>
      </div>
    </Modal>
  );
}
