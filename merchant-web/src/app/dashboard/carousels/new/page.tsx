"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { BackLink } from "@/shared/ui/page-header";
import { SelectField, TextField } from "@/shared/ui/form";
import { createCarousel } from "@/features/carousels/api";
import { PLACEMENTS, PLACEMENT_LABELS, type Placement } from "@/features/carousels/schema";

const BACK = "/dashboard/carousels";

export default function NewCarouselPage() {
  const router = useRouter();
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
      router.push(`/dashboard/carousels/${created.id}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not create the carousel.");
      setBusy(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="My carousels" />
      <h1 className="mt-md text-headline-md text-ink">New carousel</h1>
      <p className="mt-xs text-body-md text-muted">
        Name it and choose where it appears — you&rsquo;ll add slides next.
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl flex max-w-content flex-col gap-lg">
        <TextField label="Name" value={name} onChange={setName} placeholder="Spring sale hero" />
        <SelectField<Placement>
          label="Placement"
          value={placement}
          onChange={setPlacement}
          options={PLACEMENTS.map((p) => ({ value: p, label: PLACEMENT_LABELS[p] }))}
          helper="Where this carousel appears on the storefront."
        />
      </div>

      <div className="sticky bottom-0 mt-xxl -mx-lg flex items-center justify-end gap-md border-t border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
        <Link
          href={BACK}
          className="inline-flex h-11 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink"
        >
          Cancel
        </Link>
        <button
          type="button"
          onClick={create}
          disabled={busy}
          className="inline-flex h-11 items-center rounded-button bg-brand px-xl text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {busy ? "Creating…" : "Create carousel"}
        </button>
      </div>
    </div>
  );
}
