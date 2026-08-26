"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { Ticket } from "@/shared/icons";
import { BackLink } from "@/shared/ui/page-header";
import { DateTimeField, SelectField, TextAreaField, TextField, ToggleField } from "@/shared/ui/form";
import { Divider } from "@/shared/ui/divider";
import { formatDateTime, isoFromNow, nowIso } from "@/shared/datetime";
import { createCoupon, updateCoupon, type CouponWrite } from "./api";
import { discountLabel, rupees } from "./format";
import { DISCOUNT_TYPES, type Coupon, type DiscountType } from "./schema";

const BACK = "/dashboard/coupons";

function canonCode(raw: string): string {
  return raw.replace(/[^A-Za-z0-9_-]/g, "").toUpperCase().slice(0, 40);
}

function toInt(v: string): number {
  const n = Number(v);
  return Number.isInteger(n) && n >= 0 ? n : 0;
}

export function CouponEditor({ existing }: { existing: Coupon | null }) {
  const t = useTranslations("coupons");
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
      ? t("form.errors.valueAboveZero")
      : percentTooHigh
        ? t("form.errors.percentMax")
        : null;

  async function save() {
    setError(null);
    const cleanCode = canonCode(code);
    if (cleanCode.length < 2) return setError(t("form.errors.codeMinLength"));
    if (!title.trim()) return setError(t("form.errors.titleRequired"));
    if (!Number.isFinite(valueNum) || valueNum <= 0) return setError(t("form.errors.discountAboveZero"));
    if (discountType === "PERCENT" && valueNum > 100) return setError(t("form.errors.percentMax"));
    if (!validFrom || !validUntil || new Date(validUntil) <= new Date(validFrom)) {
      return setError(t("form.errors.validUntilAfterFrom"));
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
      setError(e instanceof Error ? e.message : t("form.errors.saveFailed"));
      setBusy(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label={t("list.title")} />
      <h1 className="mt-md text-headline-md text-ink">{isEdit ? t("form.editTitle") : t("form.newTitle")}</h1>
      <p className="mt-xs text-body-md text-muted">
        {t("form.subtitle")}
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl grid gap-xl lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[380px_minmax(0,1fr)]">
        <div className="lg:sticky lg:top-lg lg:self-start">
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">{t("form.preview")}</p>
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

        <div className="flex max-w-content flex-col gap-lg">
          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <TextField
              label={t("form.codeLabel")}
              value={code}
              onChange={(v) => setCode(canonCode(v))}
              placeholder="WELCOME10"
              helper={t("form.codeHelper")}
            />
            <TextField
              label={t("form.titleLabel")}
              value={title}
              onChange={setTitle}
              placeholder={t("form.titlePlaceholder")}
            />
          </div>

          <TextAreaField
            label={t("form.descriptionLabel")}
            value={description ?? ""}
            onChange={setDescription}
            rows={2}
            placeholder={t("form.descriptionPlaceholder")}
          />

          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <SelectField<DiscountType>
              label={t("form.typeLabel")}
              value={discountType}
              onChange={setDiscountType}
              options={DISCOUNT_TYPES.map((dt) => ({ value: dt, label: t(`discountType.${dt}`) }))}
            />
            <TextField
              label={discountType === "PERCENT" ? t("form.percentOffLabel") : t("form.rupeeOffLabel")}
              value={discountValue}
              onChange={setDiscountValue}
              inputMode="decimal"
              error={valueError}
            />
          </div>

          {discountType === "PERCENT" ? (
            <TextField
              label={t("form.maxDiscountLabel")}
              value={maxDiscount}
              onChange={setMaxDiscount}
              inputMode="decimal"
              helper={t("form.maxDiscountHelper")}
            />
          ) : null}

          <TextField
            label={t("form.minOrderLabel")}
            value={minOrder}
            onChange={setMinOrder}
            inputMode="decimal"
            helper={t("form.minOrderHelper")}
          />

          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <DateTimeField label={t("form.validFromLabel")} value={validFrom} onChange={setValidFrom} />
            <DateTimeField label={t("form.validUntilLabel")} value={validUntil} onChange={setValidUntil} />
          </div>

          <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
            <TextField
              label={t("form.perUserLimitLabel")}
              value={perUserLimit}
              onChange={setPerUserLimit}
              inputMode="numeric"
              helper={t("form.unlimitedHelper")}
            />
            <TextField
              label={t("form.totalCapLabel")}
              value={totalCap}
              onChange={setTotalCap}
              inputMode="numeric"
              helper={t("form.unlimitedHelper")}
            />
          </div>

          <Divider className="my-xs" />

          <div className="flex flex-col gap-lg">
            <ToggleField
              label={t("form.publicLabel")}
              description={t("form.publicDescription")}
              checked={isPublic}
              onChange={setIsPublic}
            />
            <ToggleField
              label={t("form.firstOrderLabel")}
              description={t("form.firstOrderDescription")}
              checked={firstOrderOnly}
              onChange={setFirstOrderOnly}
            />
            <ToggleField
              label={t("form.activeLabel")}
              description={t("form.activeDescription")}
              checked={isActive}
              onChange={setIsActive}
            />
          </div>
        </div>
      </div>

      <div className="sticky bottom-0 mt-xxl -mx-lg flex items-center justify-end gap-md border-t border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
        <Link
          href={BACK}
          className="inline-flex h-11 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink"
        >
          {t("form.cancel")}
        </Link>
        <button
          type="button"
          onClick={save}
          disabled={busy}
          className="inline-flex h-11 items-center rounded-button bg-brand px-xl text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {busy ? t("form.saving") : isEdit ? t("form.saveChanges") : t("form.create")}
        </button>
      </div>
    </div>
  );
}

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
  const t = useTranslations("coupons");
  const headline = discountValue > 0 ? discountLabel({ discountType, discountValue }).toUpperCase() : "—";
  return (
    <div className="overflow-hidden rounded-lg border border-hairline bg-surface shadow-floating">
      <div className="flex items-stretch">
        <div className="flex w-1/3 shrink-0 flex-col items-center justify-center gap-xs bg-brand-soft px-md py-lg text-center">
          <Ticket size={20} className="text-brand-strong" />
          <span className="text-title-sm font-extrabold leading-tight text-brand-strong">{headline}</span>
        </div>
        <div className="min-w-0 flex-1 border-l border-dashed border-hairline p-lg">
          <p className="truncate text-body-md font-bold text-ink">{title || t("preview.titleFallback")}</p>
          <span className="mt-xs inline-flex items-center rounded-md bg-surface-tint px-sm py-px text-body-sm font-semibold tracking-wide text-ink">
            {code || t("preview.codeFallback")}
          </span>
          {description ? (
            <p className="mt-sm line-clamp-2 text-body-sm text-muted">{description}</p>
          ) : null}
          <p className="mt-sm text-body-sm text-muted">
            {minOrder > 0 ? t("preview.minOrder", { amount: rupees(minOrder) }) : t("preview.noMinOrder")}
          </p>
          <p className="text-body-sm text-subtle">{t("preview.validTill", { date: formatDateTime(validUntil) })}</p>
          {isPublic || firstOrderOnly ? (
            <div className="mt-sm flex flex-wrap gap-xs">
              {isPublic ? (
                <span className="inline-flex items-center rounded-full bg-info-soft px-sm py-px text-body-sm font-semibold text-info">
                  {t("preview.autoApplies")}
                </span>
              ) : null}
              {firstOrderOnly ? (
                <span className="inline-flex items-center rounded-full bg-accent-amber-soft px-sm py-px text-body-sm font-semibold text-accent-amber">
                  {t("badges.firstOrderOnly")}
                </span>
              ) : null}
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}
