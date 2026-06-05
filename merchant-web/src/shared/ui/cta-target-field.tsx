"use client";

import { ctaHint, CTA_KIND_OPTIONS, type CtaKind } from "@/shared/cta-target";
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
  return (
    <div className="grid gap-md sm:grid-cols-[1fr_2fr]">
      <SelectField<CtaKind>
        label="CTA action"
        value={kind}
        onChange={onKindChange}
        options={CTA_KIND_OPTIONS}
      />
      {kind !== "none" ? (
        <TextField
          label="Target"
          value={value}
          onChange={onValueChange}
          helper={ctaHint(kind)}
          error={error}
          inputMode={kind === "product" ? "numeric" : "text"}
        />
      ) : (
        <div className="hidden sm:flex sm:items-end sm:pb-sm">
          <p className="text-body-sm text-subtle">{ctaHint("none")}</p>
        </div>
      )}
    </div>
  );
}
