"use client";

import { useId, useState, type ReactNode } from "react";
import { ChevronDown } from "lucide-react";

const inputClass =
  "w-full rounded-input border bg-white px-md py-sm text-body-md text-ink outline-none transition-colors placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled";

export function TextField({
  label,
  value,
  onChange,
  error,
  helper,
  placeholder,
  type = "text",
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  error?: string;
  helper?: string;
  placeholder?: string;
  type?: string;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-xs">
      <label htmlFor={id} className="text-label-md text-muted">
        {label}
      </label>
      <input
        id={id}
        type={type}
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        aria-invalid={error ? true : undefined}
        className={`${inputClass} ${error ? "border-error" : "border-hairline"}`}
      />
      {error ? (
        <p className="text-body-sm text-error">{error}</p>
      ) : helper ? (
        <p className="text-body-sm text-subtle">{helper}</p>
      ) : null}
    </div>
  );
}

export function NumberField(props: Omit<Parameters<typeof TextField>[0], "type">) {
  return <TextField {...props} type="number" />;
}

export function TextArea({
  label,
  value,
  onChange,
  error,
  helper,
  rows = 4,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  error?: string;
  helper?: string;
  rows?: number;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-xs">
      <label htmlFor={id} className="text-label-md text-muted">
        {label}
      </label>
      <textarea
        id={id}
        value={value}
        rows={rows}
        onChange={(e) => onChange(e.target.value)}
        className={`${inputClass} resize-y ${error ? "border-error" : "border-hairline"}`}
      />
      {error ? (
        <p className="text-body-sm text-error">{error}</p>
      ) : helper ? (
        <p className="text-body-sm text-subtle">{helper}</p>
      ) : null}
    </div>
  );
}

export function SelectField({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: Array<{ value: string; label: string }>;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-xs">
      <label htmlFor={id} className="text-label-md text-muted">
        {label}
      </label>
      <select
        id={id}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={`${inputClass} border-hairline`}
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </div>
  );
}

export function CheckboxField({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="flex cursor-pointer items-center gap-sm text-body-md text-ink">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="size-4 accent-brand"
      />
      {label}
    </label>
  );
}

/** Collapsible section for the editorial parts of the form. */
export function FormSection({
  title,
  description,
  defaultOpen = false,
  children,
}: {
  title: string;
  description?: string;
  defaultOpen?: boolean;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <section className="border-t border-hairline py-lg">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="flex w-full items-center justify-between gap-md text-left focus-visible:outline-none"
      >
        <span>
          <span className="text-title-sm text-ink">{title}</span>
          {description ? (
            <span className="block text-body-sm text-muted">{description}</span>
          ) : null}
        </span>
        <ChevronDown
          size={18}
          className={`shrink-0 text-muted transition-transform ${open ? "rotate-180" : ""}`}
        />
      </button>
      {open ? <div className="mt-lg">{children}</div> : null}
    </section>
  );
}

/** Small secondary "+ Add" / row-action button. */
export function MiniButton({
  onClick,
  children,
  tone = "default",
}: {
  onClick: () => void;
  children: ReactNode;
  tone?: "default" | "danger";
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex h-9 items-center gap-sm rounded-button border px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
        tone === "danger"
          ? "border-error text-error hover:bg-error-soft"
          : "border-hairline text-ink hover:bg-surface-tint"
      }`}
    >
      {children}
    </button>
  );
}
