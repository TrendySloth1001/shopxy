"use client";

import { useTranslations } from "next-intl";
import { isoToLocalInput, localInputToIso } from "@/shared/datetime";
import { ComboSelect } from "./combo-select";
import { DatePicker, TimeSelect } from "./date-picker";

const inputBase =
  "h-10 w-full rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-field-tint disabled:text-disabled";

/** Label + helper/error wrapper shared by the form fields below. */
function FieldShell({
  label,
  helper,
  error,
  htmlFor,
  children,
}: {
  label: string;
  helper?: string;
  error?: string | null;
  htmlFor?: string;
  children: React.ReactNode;
}) {
  return (
    <label htmlFor={htmlFor} className="flex flex-col gap-xs">
      <span className="text-label-md text-muted">{label}</span>
      {children}
      {error ? (
        <span className="text-body-sm text-error">{error}</span>
      ) : helper ? (
        <span className="text-body-sm text-subtle">{helper}</span>
      ) : null}
    </label>
  );
}

export function TextField({
  label,
  value,
  onChange,
  placeholder,
  helper,
  error,
  type = "text",
  inputMode,
  disabled,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  helper?: string;
  error?: string | null;
  type?: string;
  inputMode?: "numeric" | "decimal" | "text";
  disabled?: boolean;
}) {
  return (
    <FieldShell label={label} helper={helper} error={error}>
      <input
        type={type}
        inputMode={inputMode}
        value={value}
        disabled={disabled}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className={inputBase}
      />
    </FieldShell>
  );
}

export function TextAreaField({
  label,
  value,
  onChange,
  rows = 3,
  placeholder,
  helper,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  rows?: number;
  placeholder?: string;
  helper?: string;
}) {
  return (
    <FieldShell label={label} helper={helper}>
      <textarea
        value={value}
        rows={rows}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-input border border-hairline bg-field px-md py-sm text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
      />
    </FieldShell>
  );
}

export function SelectField<T extends string>({
  label,
  value,
  onChange,
  options,
  helper,
  disabled,
}: {
  label: string;
  value: T;
  onChange: (v: T) => void;
  options: ReadonlyArray<{ value: T; label: string }>;
  helper?: string;
  disabled?: boolean;
}) {
  // Custom dropdown (no native <select>). ComboSelect renders its own label +
  // helper in the same style as FieldShell, so we hand them straight to it.
  return (
    <ComboSelect
      label={label}
      value={value}
      onChange={(v) => onChange(v as T)}
      options={options.map((o) => ({ value: o.value, label: o.label }))}
      helper={helper}
      disabled={disabled}
    />
  );
}

/** Native datetime-local field that reads/writes UTC ISO strings. */
export function DateTimeField({
  label,
  value,
  onChange,
  helper,
  error,
}: {
  label: string;
  value: string | null;
  onChange: (iso: string | null) => void;
  helper?: string;
  error?: string | null;
}) {
  // Custom date + time (no native datetime-local). Split the local input
  // string into date/time, edit each with our own controls, recombine to UTC.
  const local = isoToLocalInput(value); // "YYYY-MM-DDTHH:mm" or ""
  const date = local ? local.slice(0, 10) : "";
  const time = local ? local.slice(11, 16) : "";
  const emit = (d: string, tm: string) =>
    onChange(d ? localInputToIso(`${d}T${tm || "00:00"}`) : null);

  return (
    <div className="flex flex-col gap-xs">
      <span className="text-label-md text-muted">{label}</span>
      <div className="flex flex-wrap items-center gap-sm">
        <DatePicker
          ariaLabel={label}
          value={date}
          onChange={(d) => emit(d, time)}
          clearable
          className="min-w-0 flex-1"
        />
        <TimeSelect value={time} onChange={(tm) => emit(date, tm)} disabled={!date} />
      </div>
      {error ? (
        <span className="text-body-sm text-error">{error}</span>
      ) : helper ? (
        <span className="text-body-sm text-subtle">{helper}</span>
      ) : null}
    </div>
  );
}

/** Hex colour field — a live swatch (also a native picker) beside the text. */
export function HexColorField({
  label,
  value,
  onChange,
  helper,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  helper?: string;
}) {
  const t = useTranslations("common");
  // The native colour input only understands #RRGGBB; fall back to a neutral
  // swatch when the merchant has typed a partial/8-digit value.
  const swatch = /^#[0-9a-fA-F]{6}$/.test(value) ? value : "#ffffff";
  return (
    <FieldShell label={label} helper={helper}>
      <div className="flex items-center gap-sm">
        <input
          type="color"
          aria-label={t("colorField.swatchLabel", { label })}
          value={swatch}
          onChange={(e) => onChange(e.target.value)}
          className="size-10 shrink-0 cursor-pointer rounded-input border border-hairline bg-field p-px"
        />
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder="#RRGGBB"
          spellCheck={false}
          className={inputBase}
        />
      </div>
    </FieldShell>
  );
}

export function ToggleField({
  label,
  description,
  checked,
  onChange,
  disabled,
}: {
  label: string;
  description?: string;
  checked: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <div className="flex items-center gap-md">
      <div className="min-w-0 flex-1">
        <p className="text-body-md text-ink">{label}</p>
        {description ? <p className="text-body-sm text-muted">{description}</p> : null}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-label={label}
        disabled={disabled}
        onClick={() => onChange(!checked)}
        className={`relative inline-flex h-6 w-10 shrink-0 items-center rounded-full transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:opacity-50 ${
          checked ? "bg-brand" : "bg-hairline"
        }`}
      >
        <span
          className={`inline-block size-5 rounded-full bg-surface shadow-floating transition-transform ${
            checked ? "translate-x-[18px]" : "translate-x-px"
          }`}
        />
      </button>
    </div>
  );
}
