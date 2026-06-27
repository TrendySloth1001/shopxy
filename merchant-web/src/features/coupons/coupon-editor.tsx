"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Ticket } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { DateTimeField, SelectField, TextAreaField, TextField, ToggleField } from "@/shared/ui/form";
import { Divider } from "@/shared/ui/divider";
import { formatDateTime, isoFromNow, nowIso } from "@/shared/datetime";
import { createCoupon, updateCoupon, type CouponWrite } from "./api";
import { discountLabel, rupees } from "./format";
import { DISCOUNT_TYPE_LABELS, DISCOUNT_TYPES, type Coupon, type DiscountType } from "./schema";

const BACK = "/dashboard/coupons";

/** Strip to the characters the Flutter editor allows and force upper-case. */
function canonCode(raw: string): string {
  return raw.replace(/[^A-Za-z0-9_-]/g, "").toUpperCase().slice(0, 40);
}

/** Parse an integer field where blank/invalid means 0 (unlimited). */
function toInt(v: string): number {
  const n = Number(v);
  return Number.isInteger(n) && n >= 0 ? n : 0;
}

/** Full-page coupon editor with a live customer-card preview. */
export function CouponEditor({ existing }: { existing: Coupon | null }) {
  const router = useRouter();
  const isEdit = existing != null;

  const [code, setCode] = useState(existing?.code ?? "");
  const [title, setTitle] = useState(existing?.title ?? "");
  const [description, setDescription] = useState(existing?.description ?? "");
  const [discountType, setDiscountType] = useState<DiscountType>(existing?.discountType ?? "PERCENT");
  const [discountValue, setDiscountValue] = useState(
    existing ? String(existing.discountValue) : "",
  );
  const [maxDiscount, setMaxDiscount] = useState(
    existing?.maxDiscount != null ? String(existing.maxDiscount) : "",
  );
  const [minOrder, setMinOrder] = useState(existing ? String(existing.minOrderAmount) : "0");
  const [perUserLimit, setPerUserLimit] = useState(existing ? String(existing.perUserLimit) : "1");
  const [totalCap, setTotalCap] = useState(existing ? String(existing.totalCap) : "0");
  const [validFrom, setValidFrom] = useState<string | null>(existing?.validFrom ?? nowIso());
  const [validUntil, setValidUntil] = useState<string | null>(
    existing?.validUntil ?? isoFromNow(30 * 24 * 60 * 60 * 1000),
  );
  const [isPublic, setIsPublic] = useState(existing?.isPublic ?? false);
  const [firstOrderOnly, setFirstOrderOnly] = useState(existing?.firstOrderOnly ?? false);
  const [isActive, setIsActive] = useState(existing?.isActive ?? true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const valueNum = Number(discountValue);
  const percentTooHigh = discountType === "PERCENT" && discountValue !== "" && valueNum > 100;
  const valueError =
    discountValue !== "" && (!Number.isFinite(valueNum) || valueNum <= 0)
      ? "Enter a value above 0."
      : percentTooHigh
        ? "Percent off can't exceed 100."
        : null;

  async function save() {
    setError(null);
    const cleanCode = canonCode(code);
    if (cleanCode.length < 2) return setError("Code must be at least 2 characters.");
    if (!title.trim()) return setError("Give the coupon a title.");
    if (!Number.isFinite(valueNum) || valueNum <= 0) return setError("Enter a discount value above 0.");
    if (discountType === "PERCENT" && valueNum > 100) return setError("Percent off can't exceed 100.");
    if (!validFrom || !validUntil || new Date(validUntil) <= new Date(validFrom)) {
      return setError("Valid-until must be after valid-from.");
    }

    const maxNum = maxDiscount.trim() === "" ? null : Number(maxDiscount);
    const payload: CouponWrite = {
      code: cleanCode,
      title: title.trim(),
      description: description.trim() ? description.trim() : null,
      discountType,
      discountValue: valueNum,
      maxDiscount: discountType === "PERCENT" && maxNum != null && maxNum > 0 ? maxNum : null,
      minOrderAmount: Math.max(0, Number(minOrder) || 0),
      validFrom,
      validUntil,
      perUserLimit: toInt(perUserLimit),
      totalCap: toInt(totalCap),
      isPublic,
      firstOrderOnly,
      isActive,
    };

    setBusy(true);
    try {
      if (isEdit) {
        await updateCoupon(existing.id, payload);
      } else {
        await createCoupon(payload);
      }
      router.push(BACK);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Save failed.");
      setBusy(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Coupons" />
      <h1 className="mt-md text-headline-md text-ink">{isEdit ? "Edit coupon" : "New coupon"}</h1>
      <p className="mt-xs text-body-md text-muted">
        A discount code your customers redeem at checkout — the preview shows the card they&rsquo;ll see.
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl grid gap-xl lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[380px_minmax(0,1fr)]">
        {/* Preview */}
        <div className="lg:sticky lg:top-lg lg:self-start">
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">Preview</p>
          <CouponPreview
            code={canonCode(code)}
            title={title}
            description={description}
            discountType={discountType}
            discountValue={Number.isFinite(valueNum) ? valueNum : 0}
            minOrder={Math.max(0, Number(minOrder) || 0)}
            validUntil={validUntil}
            isPublic={isPublic}
            firstOrderOnly={firstOrderOnly}
          />
        </div>

        {/* Form */}
        <div className="flex max-w-content flex-col gap-lg">
          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <TextField
              label="Code"
              value={code}
              onChange={(v) => setCode(canonCode(v))}
              placeholder="WELCOME10"
              helper="Letters, numbers, - and _ · auto-uppercased"
            />
            <TextField
              label="Title"
              value={title}
              onChange={setTitle}
              placeholder="New user offer"
            />
          </div>

          <TextAreaField
            label="Description (optional)"
            value={description ?? ""}
            onChange={setDescription}
            rows={2}
            placeholder="Shown on the customer's coupon card."
          />

          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <SelectField<DiscountType>
              label="Type"
              value={discountType}
              onChange={setDiscountType}
              options={DISCOUNT_TYPES.map((t) => ({ value: t, label: DISCOUNT_TYPE_LABELS[t] }))}
            />
            <TextField
              label={discountType === "PERCENT" ? "% off" : "₹ off"}
              value={discountValue}
              onChange={setDiscountValue}
              inputMode="decimal"
              error={valueError}
            />
          </div>

          {discountType === "PERCENT" ? (
            <TextField
              label="Max discount (₹) — optional"
              value={maxDiscount}
              onChange={setMaxDiscount}
              inputMode="decimal"
              helper="Caps the % off. Leave blank for no ceiling."
            />
          ) : null}

          <TextField
            label="Minimum order (₹)"
            value={minOrder}
            onChange={setMinOrder}
            inputMode="decimal"
            helper="0 = applies to any cart"
          />

          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <DateTimeField label="Valid from" value={validFrom} onChange={setValidFrom} />
            <DateTimeField label="Valid until" value={validUntil} onChange={setValidUntil} />
          </div>

          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <TextField
              label="Per-user limit"
              value={perUserLimit}
              onChange={setPerUserLimit}
              inputMode="numeric"
              helper="0 = unlimited"
            />
            <TextField
              label="Total cap"
              value={totalCap}
              onChange={setTotalCap}
              inputMode="numeric"
              helper="0 = unlimited"
            />
          </div>

          <Divider className="my-xs" />

          <div className="flex flex-col gap-lg">
            <ToggleField
              label="Public — auto-applies"
              description="Anyone can see and use it; it auto-applies at checkout when the cart matches — no code typing. Keep off for private codes shared with specific people."
              checked={isPublic}
              onChange={setIsPublic}
            />
            <ToggleField
              label="First-order only"
              description="Restricts redemption to customers with no prior confirmed orders. Pair with a per-user limit of 1 for a single-shot welcome offer."
              checked={firstOrderOnly}
              onChange={setFirstOrderOnly}
            />
            <ToggleField
              label="Active"
              description="When off, buyers won't see this coupon and can't redeem it."
              checked={isActive}
              onChange={setIsActive}
            />
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
          {busy ? "Saving…" : isEdit ? "Save changes" : "Create coupon"}
        </button>
      </div>
    </div>
  );
}

/** A customer-facing coupon ticket — what the buyer sees on their carousel. */
function CouponPreview({
  code,
  title,
  description,
  discountType,
  discountValue,
  minOrder,
  validUntil,
  isPublic,
  firstOrderOnly,
}: {
  code: string;
  title: string;
  description?: string | null;
  discountType: DiscountType;
  discountValue: number;
  minOrder: number;
  validUntil: string | null;
  isPublic: boolean;
  firstOrderOnly: boolean;
}) {
  const headline = discountValue > 0 ? discountLabel({ discountType, discountValue }).toUpperCase() : "—";
  return (
    <div className="overflow-hidden rounded-lg border border-hairline bg-surface shadow-floating">
      <div className="flex items-stretch">
        {/* Discount stub */}
        <div className="flex w-1/3 shrink-0 flex-col items-center justify-center gap-xs bg-brand-soft px-md py-lg text-center">
          <Ticket size={20} className="text-brand-strong" />
          <span className="text-title-sm font-extrabold leading-tight text-brand-strong">{headline}</span>
        </div>
        {/* Detail */}
        <div className="min-w-0 flex-1 border-l border-dashed border-hairline p-lg">
          <p className="truncate text-body-md font-bold text-ink">{title || "Coupon title"}</p>
          <span className="mt-xs inline-flex items-center rounded-md bg-surface-tint px-sm py-px text-body-sm font-semibold tracking-wide text-ink">
            {code || "CODE"}
          </span>
          {description ? (
            <p className="mt-sm line-clamp-2 text-body-sm text-muted">{description}</p>
          ) : null}
          <p className="mt-sm text-body-sm text-muted">
            {minOrder > 0 ? `Min. order ${rupees(minOrder)}` : "No minimum order"}
          </p>
          <p className="text-body-sm text-subtle">Valid till {formatDateTime(validUntil)}</p>
          {isPublic || firstOrderOnly ? (
            <div className="mt-sm flex flex-wrap gap-xs">
              {isPublic ? (
                <span className="inline-flex items-center rounded-full bg-info-soft px-sm py-px text-body-sm font-semibold text-info">
                  Auto-applies
                </span>
              ) : null}
              {firstOrderOnly ? (
                <span className="inline-flex items-center rounded-full bg-accent-amber-soft px-sm py-px text-body-sm font-semibold text-accent-amber">
                  First order only
                </span>
              ) : null}
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}
