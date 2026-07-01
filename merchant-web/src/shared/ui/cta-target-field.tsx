"use client";

import { useTranslations } from "next-intl";
import { ctaHintKey, CTA_KIND_OPTIONS, type CtaKind } from "@/shared/cta-target";
import { SelectField, TextField } from "@/shared/ui/form";

/**
 * Controlled CTA-target editor: a kind dropdown plus a value field that only
 * shows when the kind needs one. The parent owns {kind, value} state and
 * builds/validates the wire string with `buildCtaTarget` on save.
 */
export function CtaTargetField({
  kind,
  value,
  onKindChange,
  onValueChange,
  error,
}: {
  kind: CtaKind;
  value: string;
  onKindChange: (kind: CtaKind) => void;
  onValueChange: (value: string) => void;
  error?: string | null;
}) {
  const t = useTranslations("common");
  const kindOptions = CTA_KIND_OPTIONS.map((o) => ({ value: o.value, label: t(o.labelKey) }));
  return (
    <div className="grid gap-md sm:grid-cols-[1fr_2fr]">
      <SelectField<CtaKind>
        label={t("cta.actionLabel")}
        value={kind}
        onChange={onKindChange}
        options={kindOptions}
      />
      {kind !== "none" ? (
        <TextField
          label={t("cta.targetLabel")}
          value={value}
          onChange={onValueChange}
          helper={t(ctaHintKey(kind))}
          error={error}
          inputMode={kind === "product" ? "numeric" : "text"}
        />
      ) : (
        <div className="hidden sm:flex sm:items-end sm:pb-sm">
          <p className="text-body-sm text-subtle">{t(ctaHintKey("none"))}</p>
        </div>
      )}
    </div>
  );
}
