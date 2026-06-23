"use client";

import { useId, useState, type InputHTMLAttributes } from "react";
import { Eye, EyeOff } from "lucide-react";

type FieldProps = Omit<InputHTMLAttributes<HTMLInputElement>, "id" | "type"> & {
  label: string;
  type?: InputHTMLAttributes<HTMLInputElement>["type"];
  error?: string;
  /** Render a show/hide toggle (for password fields). */
  toggleable?: boolean;
  helper?: string;
};

/**
 * Single text field: label, input, optional helper, and an inline error.
 * Hairline border + brand focus ring, all from tokens — no boxes, nothing
 * chunky (CLAUDE.md §9). The whole control is the tap target.
 */
export function Field({
  label,
  type = "text",
  error,
  toggleable = false,
  helper,
  ...inputProps
}: FieldProps) {
  const id = useId();
  const [revealed, setRevealed] = useState(false);
  const resolvedType = toggleable ? (revealed ? "text" : "password") : type;
  const describedBy = error
    ? `${id}-error`
    : helper
      ? `${id}-helper`
      : undefined;

  return (
    <div className="flex flex-col gap-xs">
      <label htmlFor={id} className="text-label-md text-muted">
        {label}
      </label>
      <div className="relative">
        <input
          id={id}
          type={resolvedType}
          aria-invalid={error ? true : undefined}
          aria-describedby={describedBy}
          className={`w-full rounded-input border bg-white px-md py-sm text-body-md text-ink outline-none transition-colors placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled ${
            error ? "border-error" : "border-hairline"
          } ${toggleable ? "pr-massive" : ""}`}
          {...inputProps}
        />
        {toggleable ? (
          <button
            type="button"
            onClick={() => setRevealed((v) => !v)}
            className="absolute inset-y-0 right-0 flex items-center px-md text-muted transition-colors hover:text-ink focus-visible:text-ink focus-visible:outline-none"
            aria-label={revealed ? "Hide password" : "Show password"}
            aria-pressed={revealed}
          >
            {revealed ? <EyeOff size={18} aria-hidden /> : <Eye size={18} aria-hidden />}
          </button>
        ) : null}
      </div>
      {error ? (
        <p id={`${id}-error`} className="text-body-sm text-error">
          {error}
        </p>
      ) : helper ? (
        <p id={`${id}-helper`} className="text-body-sm text-subtle">
          {helper}
        </p>
      ) : null}
    </div>
  );
}
