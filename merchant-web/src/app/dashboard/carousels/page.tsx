"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ChevronRight, GalleryHorizontalEnd, Plus } from "lucide-react";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { SelectField, TextField } from "@/shared/ui/form";
import { formatDateRange } from "@/shared/datetime";
import { createCarousel, listCarousels } from "@/features/carousels/api";
import {
  PLACEMENTS,
  PLACEMENT_LABELS,
  type Carousel,
  type Placement,
} from "@/features/carousels/schema";

export default function CarouselsPage() {
  const router = useRouter();
  const [carousels, setCarousels] = useState<Carousel[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

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
      <div className="flex flex-wrap items-start justify-between gap-md">
        <div>
          <div className="flex items-center gap-sm">
            <GalleryHorizontalEnd size={22} className="text-brand-strong" />
            <h1 className="text-headline-md text-ink">My carousels</h1>
          </div>
          <p className="mt-xs text-body-md text-muted">
            Banner carousels for your storefront — grouped by where they appear.
          </p>
        </div>
        <button
          type="button"
          onClick={() => setCreating(true)}
          className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Plus size={16} /> New carousel
        </button>
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {loading ? (
        <p className="py-xxl text-center text-body-sm text-subtle">Loading…</p>
      ) : carousels.length === 0 ? (
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <span className="flex size-12 items-center justify-center rounded-full bg-brand-soft text-brand-strong">
            <GalleryHorizontalEnd size={22} />
          </span>
          <p className="text-body-md text-muted">No carousels yet — create one to start building slides.</p>
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

      {creating ? (
        <NewCarouselModal
          onClose={() => setCreating(false)}
          onCreated={(c) => router.push(`/dashboard/carousels/${c.id}`)}
        />
      ) : null}
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

function NewCarouselModal({
  onClose,
  onCreated,
}: {
  onClose: () => void;
  onCreated: (c: Carousel) => void;
}) {
  const [name, setName] = useState("");
  const [placement, setPlacement] = useState<Placement>("HERO");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function create() {
    setError(null);
    if (!name.trim()) return setError("Give the carousel a name.");
    setBusy(true);
    try {
      const created = await createCarousel({ name: name.trim(), placement });
      onCreated(created);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not create the carousel.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="New carousel" onClose={onClose}>
      <TextField label="Name" value={name} onChange={setName} placeholder="Spring sale hero" />
      <SelectField<Placement>
        label="Placement"
        value={placement}
        onChange={setPlacement}
        options={PLACEMENTS.map((p) => ({ value: p, label: PLACEMENT_LABELS[p] }))}
        helper="Where this carousel appears on the storefront."
      />
      {error ? <p className="text-body-sm text-error">{error}</p> : null}
      <ModalActions busy={busy} confirmLabel="Create" onCancel={onClose} onConfirm={create} />
    </Modal>
  );
}
