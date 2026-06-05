"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, ChevronRight, Plus, Trash2 } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { DateTimeField, SelectField, TextField, ToggleField } from "@/shared/ui/form";
import { ProductThumb } from "@/features/products/components/product-thumb";
import {
  deleteCarousel,
  listSlides,
  updateCarousel,
  type CarouselUpdate,
} from "@/features/carousels/api";
import {
  carouselSchema,
  PLACEMENTS,
  PLACEMENT_LABELS,
  TEMPLATE_LABELS,
  type Carousel,
  type Placement,
  type Slide,
} from "@/features/carousels/schema";
import { DetailSkeleton } from "@/shared/ui/skeleton";

export default function CarouselEditorPage() {
  const params = useParams<{ id: string }>();
  const carouselId = Number(params.id);
  const router = useRouter();

  const [carousel, setCarousel] = useState<Carousel | null>(null);
  const [slides, setSlides] = useState<Slide[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [savingMeta, setSavingMeta] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleteBusy, setDeleteBusy] = useState(false);

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
    return <DetailSkeleton />;
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
        <Link
          href={`/dashboard/carousels/${carouselId}/slides/new`}
          className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Plus size={16} /> Add slide
        </Link>
      </div>

      <div className="mt-md">
        {slides.length === 0 ? (
          <p className="rounded-md bg-surface-tint px-md py-lg text-center text-body-sm text-muted">
            No slides yet — tap &ldquo;Add slide&rdquo; to design your first one.
          </p>
        ) : (
          slides.map((s) => (
            <SlideRow key={s.id} slide={s} carouselId={carouselId} />
          ))
        )}
      </div>

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
        <TextField label="Name" value={name} onChange={setName} helper="Edit, then Save name below." />
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

function SlideRow({ slide, carouselId }: { slide: Slide; carouselId: number }) {
  return (
    <Link
      href={`/dashboard/carousels/${carouselId}/slides/${slide.id}`}
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
    </Link>
  );
}
