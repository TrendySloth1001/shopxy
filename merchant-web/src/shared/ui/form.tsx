"use client";

import { useId } from "react";
import { isoToLocalInput, localInputToIso } from "@/shared/datetime";

const inputBase =
  "h-10 w-full rounded-input border border-hairline bg-surface px-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-surface-tint disabled:text-disabled";

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
        className="w-full rounded-input border border-hairline bg-surface px-md py-sm text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
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
  const id = useId();
  return (
    <FieldShell label={label} helper={helper} htmlFor={id}>
      <select
        id={id}
        value={value}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value as T)}
        className={inputBase}
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </FieldShell>
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
  return (
    <FieldShell label={label} helper={helper} error={error}>
      <input
        type="datetime-local"
        value={isoToLocalInput(value)}
        onChange={(e) => onChange(localInputToIso(e.target.value))}
        className={inputBase}
      />
    </FieldShell>
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
  // The native colour input only understands #RRGGBB; fall back to a neutral
  // swatch when the merchant has typed a partial/8-digit value.
  const swatch = /^#[0-9a-fA-F]{6}$/.test(value) ? value : "#ffffff";
  return (
    <FieldShell label={label} helper={helper}>
      <div className="flex items-center gap-sm">
        <input
          type="color"
          aria-label={`${label} swatch`}
          value={swatch}
          onChange={(e) => onChange(e.target.value)}
          className="size-10 shrink-0 cursor-pointer rounded-input border border-hairline bg-surface p-px"
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
