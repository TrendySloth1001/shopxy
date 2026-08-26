"use client";

import { useTranslations } from "next-intl";
import { AlertTriangle, Info, Pencil } from "@/shared/icons";
import { NumberField } from "./form-controls";
import type { HsnResolution } from "../hsn";

export function GstRateField({
  value,
  onChange,
  manual,
  onManualChange,
  resolution,
  unknownCode,
  error,
}: {
  value: string;
  onChange: (v: string) => void;
  manual: boolean;
  onManualChange: (manual: boolean) => void;
  resolution: HsnResolution | null;
  unknownCode: boolean;
  error?: string;
}) {
  const t = useTranslations("products.form");

  const diverges =
    manual &&
    resolution !== null &&
    Math.abs(Number.parseFloat(value || "0") - resolution.gstRate) > 0.005;

  return (
    <div className="flex flex-col gap-xs">
      <span className="text-label-md text-muted">{t("taxPercentLabel")}</span>

      {manual ? (
        <NumberField
          label=""
          value={value}
          onChange={onChange}
          error={error}
          min={0}
          max={100}
          step={0.01}
        />
      ) : (
        <div className="flex h-10 items-center gap-sm rounded-input border border-hairline bg-field-tint px-md">
          <span className="text-body-md text-ink">
            {resolution ? `${resolution.gstRate}%` : unknownCode ? "—" : t("gstAwaitingCode")}
          </span>
          {resolution?.source === "HSN_RULE" ? (
            <span className="rounded-full bg-brand-soft px-sm text-body-sm text-brand">
              {t("gstFromRule")}
            </span>
          ) : null}
          {resolution?.source === "OVERRIDE" ? (
            <span className="rounded-full bg-warning-soft px-sm text-body-sm text-warning">
              {t("gstFromOverride")}
            </span>
          ) : null}
        </div>
      )}

      {resolution && !manual ? (
        <p className="flex items-start gap-xs text-body-sm text-subtle">
          <Info className="mt-0.5 size-3.5 shrink-0" aria-hidden />
          <span>
            {resolution.exact
              ? t("hsnRateFrom", { code: resolution.code })
              : t("hsnRateFromHeading", { code: resolution.code })}
            {resolution.rule && resolution.rule.testedPrice !== null
              ? ` ${t("gstRuleApplied", {
                  price: resolution.rule.testedPrice,
                  threshold: resolution.rule.threshold,
                })}`
              : ""}
            {resolution.rateNote ? ` ${resolution.rateNote}` : ""}
          </span>
        </p>
      ) : null}

      {unknownCode && !manual ? (
        <p className="flex items-start gap-xs text-body-sm text-error">
          <AlertTriangle className="mt-0.5 size-3.5 shrink-0" aria-hidden />
          <span>{t("hsnUnknown")}</span>
        </p>
      ) : null}

      {diverges ? (
        <p className="flex items-start gap-xs text-body-sm text-warning">
          <AlertTriangle className="mt-0.5 size-3.5 shrink-0" aria-hidden />
          <span>{t("gstManualDiverges", { code: resolution!.code, rate: resolution!.gstRate })}</span>
        </p>
      ) : null}

      <button
        type="button"
        onClick={() => {
          const next = !manual;
          onManualChange(next);
          if (!next && resolution) onChange(String(resolution.gstRate));
        }}
        className="flex w-fit items-center gap-xs text-body-sm text-brand"
      >
        <Pencil className="size-3.5" aria-hidden />
        {manual ? t("gstUseHsnRate") : t("gstSetManually")}
      </button>
    </div>
  );
}
