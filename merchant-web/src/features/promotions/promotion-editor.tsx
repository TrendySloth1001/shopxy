"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Eye, Megaphone } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { DateTimeField, TextField } from "@/shared/ui/form";
import { isoFromNow, nowIso } from "@/shared/datetime";
import {
  ProductPicker,
  type PickedProduct,
} from "@/features/products/components/product-picker";
import { createPromotion, updatePromotion } from "./api";
import { rupees } from "./format";
import type { Promotion } from "./schema";

const BACK = "/dashboard/promotions";

/** Rupee string → integer paise, or null when not a positive number. */
function toPaise(rupeeValue: string): number | null {
  const n = Number(rupeeValue);
  if (!Number.isFinite(n) || n <= 0) return null;
  return Math.round(n * 100);
}

/** Full-page promotion editor with a live projected-reach estimate. */
export function PromotionEditor({ existing }: { existing: Promotion | null }) {
  const router = useRouter();
  const isEdit = existing != null;

  const [picked, setPicked] = useState<PickedProduct | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [budget, setBudget] = useState(existing ? String(existing.budgetPaise / 100) : "1000");
  const [dailyCap, setDailyCap] = useState(existing ? String(existing.dailyCapPaise / 100) : "200");
  const [cpm, setCpm] = useState(existing ? String(existing.cpmPaise / 100) : "10");
  const [startAt, setStartAt] = useState<string | null>(existing?.startAt ?? nowIso());
  const [endAt, setEndAt] = useState<string | null>(
    existing?.endAt ?? isoFromNow(7 * 24 * 60 * 60 * 1000),
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const budgetPaise = toPaise(budget);
  const dailyPaise = toPaise(dailyCap);
  const cpmPaise = toPaise(cpm);
  const dailyError =
    budgetPaise != null && dailyPaise != null && dailyPaise > budgetPaise
      ? "Cannot exceed the total budget."
      : null;

  const productName = isEdit
    ? (existing.product?.name ?? `Product #${existing.productId}`)
    : (picked?.name ?? null);

  async function save() {
    setError(null);
    if (!isEdit && !picked) return setError("Pick a product first.");
    if (budgetPaise == null || dailyPaise == null || cpmPaise == null) {
      return setError("Enter numeric budget, daily cap and CPM.");
    }
    if (dailyPaise > budgetPaise) return setError("Daily cap cannot exceed the total budget.");
    if (!startAt || !endAt || new Date(endAt) <= new Date(startAt)) {
      return setError("End time must be after the start time.");
    }
    setBusy(true);
    try {
      if (isEdit) {
        await updatePromotion(existing.id, {
          budgetPaise,
          dailyCapPaise: dailyPaise,
          cpmPaise,
          startAt,
          endAt,
        });
      } else {
        await createPromotion({
          productId: picked!.id,
          budgetPaise,
          dailyCapPaise: dailyPaise,
          cpmPaise,
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
      <BackLink href={BACK} label="Promotions" />
      <h1 className="mt-md text-headline-md text-ink">{isEdit ? "Edit promotion" : "New promotion"}</h1>
      <p className="mt-xs text-body-md text-muted">
        Sponsored, pay-per-impression placement. We auto-pause when the budget or daily cap is hit.
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl grid gap-xl lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[380px_minmax(0,1fr)]">
        {/* Reach estimate */}
        <div className="lg:sticky lg:top-lg lg:self-start">
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">Estimated reach</p>
          <ReachPreview
            productName={productName}
            budgetPaise={budgetPaise}
            dailyPaise={dailyPaise}
            cpmPaise={cpmPaise}
          />
        </div>

        {/* Form */}
        <div className="flex max-w-content flex-col gap-lg">
          {isEdit ? (
            <div className="rounded-md bg-hero-panel px-md py-sm">
              <span className="text-body-md text-ink">{productName}</span>
              <span className="ml-sm text-body-sm text-muted">Product is fixed for an existing promo.</span>
            </div>
          ) : picked ? (
            <div className="flex items-center gap-md rounded-md bg-hero-panel px-md py-sm">
              <span className="min-w-0 flex-1 truncate text-body-md text-ink">{picked.name}</span>
              <button
                type="button"
                onClick={() => setPicked(null)}
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

          <div className="grid grid-cols-1 gap-md sm:grid-cols-3">
            <TextField
              label="Total budget (₹)"
              value={budget}
              onChange={setBudget}
              inputMode="numeric"
              helper="Lifetime cap"
            />
            <TextField
              label="Daily cap (₹)"
              value={dailyCap}
              onChange={setDailyCap}
              inputMode="numeric"
              helper={dailyError ? undefined : "Auto-pause when reached"}
              error={dailyError}
            />
            <TextField
              label="CPM (₹ / 1k)"
              value={cpm}
              onChange={setCpm}
              inputMode="numeric"
              helper="Per 1000 impressions"
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
          {busy ? "Saving…" : isEdit ? "Save changes" : "Create promotion"}
        </button>
      </div>

      {pickerOpen ? (
        <ProductPicker
          onPick={(p) => {
            setPicked(p);
            setPickerOpen(false);
          }}
          onClose={() => setPickerOpen(false)}
        />
      ) : null}
    </div>
  );
}

function ReachPreview({
  productName,
  budgetPaise,
  dailyPaise,
  cpmPaise,
}: {
  productName: string | null;
  budgetPaise: number | null;
  dailyPaise: number | null;
  cpmPaise: number | null;
}) {
  const impressions = (paise: number | null) =>
    paise != null && cpmPaise != null && cpmPaise > 0
      ? Math.floor((paise / cpmPaise) * 1000)
      : null;
  const total = impressions(budgetPaise);
  const daily = impressions(dailyPaise);
  const fmt = (n: number | null) => (n == null ? "—" : `~${n.toLocaleString("en-IN")}`);

  return (
    <div className="rounded-lg border border-hairline p-lg">
      <span className="flex size-10 items-center justify-center rounded-lg bg-accent-indigo-soft text-accent-indigo">
        <Megaphone size={20} />
      </span>
      <p className="mt-md truncate text-title-sm text-ink">{productName ?? "Pick a product"}</p>
      <p className="text-body-sm text-muted">Sponsored placement</p>

      <div className="mt-lg flex flex-col gap-md">
        <ReachRow label="Total impressions" value={fmt(total)} hint="over the whole budget" />
        <ReachRow label="Per day" value={fmt(daily)} hint="at the daily cap" />
      </div>

      <p className="mt-lg flex items-center gap-xs border-t border-hairline pt-md text-body-sm text-muted">
        <Eye size={14} />
        {cpmPaise ? `${rupees(cpmPaise)} per 1,000 impressions` : "Set a CPM to estimate reach"}
      </p>
    </div>
  );
}

function ReachRow({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div className="flex items-baseline justify-between gap-md">
      <div>
        <p className="text-body-md text-ink">{label}</p>
        <p className="text-body-sm text-subtle">{hint}</p>
      </div>
      <p className="text-title-md font-bold text-accent-indigo">{value}</p>
    </div>
  );
}
