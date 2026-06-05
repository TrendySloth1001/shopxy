"use client";

import { useCallback, useEffect, useState } from "react";
import Image from "next/image";
import { Plus, RefreshCw, Sparkles, Star, X } from "lucide-react";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { Divider } from "@/shared/ui/divider";
import { DateTimeField, HexColorField, TextAreaField, TextField } from "@/shared/ui/form";
import { ImageUploadField } from "@/shared/ui/image-upload";
import { CtaTargetField } from "@/shared/ui/cta-target-field";
import { buildCtaTarget, type CtaKind } from "@/shared/cta-target";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { formatDateRange, isoFromNow, nowIso } from "@/shared/datetime";
import { autoFg } from "@/features/carousels/color";
import { cancelSpotlight, listSpotlights, submitSpotlight } from "@/features/spotlight/api";
import {
  SPOTLIGHT_STATUS_LABELS,
  type Spotlight,
  type SpotlightStatus,
} from "@/features/spotlight/schema";

export default function SpotlightPage() {
  const [items, setItems] = useState<Spotlight[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [submitting, setSubmitting] = useState(false);

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
      <div className="flex flex-wrap items-start justify-between gap-md">
        <div>
          <div className="flex items-center gap-sm">
            <Star size={22} className="text-accent-amber" />
            <h1 className="text-headline-md text-ink">Brand spotlight</h1>
          </div>
          <p className="mt-xs text-body-md text-muted">
            Pitch your shop for a featured &ldquo;brand of the day&rdquo; slot on the customer home.
          </p>
        </div>
        <div className="flex items-center gap-sm">
          <button
            type="button"
            onClick={reload}
            disabled={loading}
            aria-label="Refresh"
            className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            <RefreshCw size={16} />
          </button>
          <button
            type="button"
            onClick={() => setSubmitting(true)}
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> Request slot
          </button>
        </div>
      </div>

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
        <p className="py-xxl text-center text-body-sm text-subtle">Loading…</p>
      ) : items.length === 0 ? (
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <span className="flex size-12 items-center justify-center rounded-full bg-accent-amber-soft text-accent-amber">
            <Star size={22} />
          </span>
          <p className="text-body-md text-muted">No spotlight requests yet.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-lg lg:grid-cols-2">
          {items.map((s) => (
            <SpotlightCard key={s.id} spotlight={s} onCancel={() => onCancel(s.id)} />
          ))}
        </div>
      )}

      {submitting ? (
        <SpotlightSubmit
          onClose={() => setSubmitting(false)}
          onSubmitted={() => {
            setSubmitting(false);
            reload();
          }}
        />
      ) : null}
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
      {/* Coloured header */}
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

      {/* Footer */}
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

// ── Submit ────────────────────────────────────────────────────────────

function SpotlightSubmit({ onClose, onSubmitted }: { onClose: () => void; onSubmitted: () => void }) {
  const [dealLabel, setDealLabel] = useState("");
  const [subtitle, setSubtitle] = useState("");
  const [heroImageUrl, setHeroImageUrl] = useState<string | null>(null);
  const [bgColor, setBgColor] = useState("#EFE4D6");
  const [accentColor, setAccentColor] = useState("#B23A2E");
  const [ctaKind, setCtaKind] = useState<CtaKind>("none");
  const [ctaValue, setCtaValue] = useState("");
  const [ctaError, setCtaError] = useState<string | null>(null);
  const [startAt, setStartAt] = useState<string | null>(nowIso());
  const [endAt, setEndAt] = useState<string | null>(isoFromNow(24 * 60 * 60 * 1000));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save() {
    setError(null);
    setCtaError(null);
    if (!dealLabel.trim()) return setError("A deal label is required.");
    if (!heroImageUrl) return setError("A hero image is required.");
    if (!startAt || !endAt || new Date(endAt) <= new Date(startAt)) {
      return setError("End time must be after the start time.");
    }
    const cta = buildCtaTarget(ctaKind, ctaValue);
    if (cta.error) {
      setCtaError(cta.error);
      return;
    }
    setBusy(true);
    try {
      await submitSpotlight({
        dealLabel: dealLabel.trim(),
        subtitle: subtitle.trim() || null,
        heroImageUrl,
        bgColor: bgColor.trim(),
        accentColor: accentColor.trim() || null,
        ctaTarget: cta.target,
        startAt,
        endAt,
      });
      onSubmitted();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Submit failed.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="Request brand spotlight" onClose={onClose} wide>
      <ImageUploadField
        label="Hero image"
        aspect="square"
        url={heroImageUrl}
        onChange={setHeroImageUrl}
        helper="Shown on the customer home strip."
      />

      <TextField
        label="Deal label"
        value={dealLabel}
        onChange={setDealLabel}
        placeholder="Festive Kurta Sets — Up to 40% off"
      />
      <TextAreaField label="Subtitle" value={subtitle} onChange={setSubtitle} rows={2} />

      <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
        <HexColorField label="Background colour" value={bgColor} onChange={setBgColor} />
        <HexColorField label="Accent colour" value={accentColor} onChange={setAccentColor} />
      </div>

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

      <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
        <DateTimeField label="Starts" value={startAt} onChange={setStartAt} />
        <DateTimeField label="Ends" value={endAt} onChange={setEndAt} />
      </div>

      {error ? <p className="text-body-sm text-error">{error}</p> : null}

      <ModalActions busy={busy} confirmLabel="Submit for review" onCancel={onClose} onConfirm={save} />
    </Modal>
  );
}
