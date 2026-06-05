"use client";

import { useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { ImageOff } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { DateTimeField, HexColorField, TextAreaField, TextField } from "@/shared/ui/form";
import { ImageUploadField } from "@/shared/ui/image-upload";
import { CtaTargetField } from "@/shared/ui/cta-target-field";
import { buildCtaTarget, type CtaKind } from "@/shared/cta-target";
import { isoFromNow, nowIso } from "@/shared/datetime";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { autoFg, isHex, withAlpha } from "@/features/carousels/color";
import { submitSpotlight } from "./api";

const BACK = "/dashboard/spotlight";

/** Full-page brand-spotlight request with a live customer-card preview. */
export function SpotlightEditor() {
  const router = useRouter();
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
    if (!isHex(bgColor)) return setError("Background colour must be a hex value like #EFE4D6.");
    if (accentColor.trim() && !isHex(accentColor)) {
      return setError("Accent colour must be a hex value like #B23A2E.");
    }
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
      router.push(BACK);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Submit failed.");
      setBusy(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Brand spotlight" />
      <h1 className="mt-md text-headline-md text-ink">Request brand spotlight</h1>
      <p className="mt-xs text-body-md text-muted">
        Pitch a featured slot. A platform admin reviews each request — the preview shows the home card.
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl grid gap-xl lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[440px_minmax(0,1fr)]">
        {/* Preview */}
        <div className="lg:sticky lg:top-lg lg:self-start">
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">Preview</p>
          <SpotlightPreview
            dealLabel={dealLabel}
            subtitle={subtitle}
            heroImageUrl={heroImageUrl}
            bgColor={isHex(bgColor) ? bgColor : "#EFE4D6"}
            accentColor={isHex(accentColor) ? accentColor : "#B23A2E"}
            hasCta={ctaKind !== "none"}
          />
        </div>

        {/* Form */}
        <div className="flex max-w-content flex-col gap-lg">
          <ImageUploadField
            label="Hero image"
            aspect="banner"
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
          {busy ? "Submitting…" : "Submit for review"}
        </button>
      </div>
    </div>
  );
}

function SpotlightPreview({
  dealLabel,
  subtitle,
  heroImageUrl,
  bgColor,
  accentColor,
  hasCta,
}: {
  dealLabel: string;
  subtitle: string;
  heroImageUrl: string | null;
  bgColor: string;
  accentColor: string;
  hasCta: boolean;
}) {
  const src = mediaSrc(heroImageUrl);
  const fg = autoFg(bgColor);
  return (
    <div className="overflow-hidden rounded-lg shadow-floating" style={{ backgroundColor: bgColor }}>
      <div className="relative aspect-[16/9]" style={{ backgroundColor: withAlpha(fg, 0.08) }}>
        {src ? (
          <Image src={src} alt="" fill unoptimized sizes="440px" className="object-cover" />
        ) : (
          <span className="flex size-full items-center justify-center" style={{ color: withAlpha(fg, 0.5) }}>
            <ImageOff size={28} />
          </span>
        )}
      </div>
      <div className="p-lg" style={{ color: fg }}>
        <p className="text-title-md font-bold">{dealLabel || "Your deal label"}</p>
        {subtitle ? <p className="mt-xs text-body-md opacity-80">{subtitle}</p> : null}
        {hasCta ? (
          <span
            className="mt-md inline-block rounded-full px-md py-xs text-body-sm font-bold text-white"
            style={{ backgroundColor: accentColor }}
          >
            Shop now
          </span>
        ) : null}
      </div>
    </div>
  );
}
