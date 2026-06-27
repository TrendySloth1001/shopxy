"use client";

import {
  useId,
  useState,
  type FocusEvent,
  type InputHTMLAttributes,
  type KeyboardEvent,
} from "react";

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
 *
 * Password fields (`toggleable`) also surface a live Caps Lock warning while
 * focused — a common cause of failed sign-ins the user can't otherwise see,
 * since the characters are masked.
 */
export function Field({
  label,
  type = "text",
  error,
  toggleable = false,
  helper,
  onKeyUp,
  onKeyDown,
  onFocus,
  onBlur,
  ...inputProps
}: FieldProps) {
  const id = useId();
  const [revealed, setRevealed] = useState(false);
  const [capsLock, setCapsLock] = useState(false);
  const [focused, setFocused] = useState(false);
  const resolvedType = toggleable ? (revealed ? "text" : "password") : type;

  const trackCaps = (event: KeyboardEvent<HTMLInputElement>) => {
    if (!toggleable) return;
    if (typeof event.getModifierState === "function") {
      setCapsLock(event.getModifierState("CapsLock"));
    }
  };

  const showCapsWarning = toggleable && capsLock && focused && !error;
  const describedBy = error
    ? `${id}-error`
    : showCapsWarning
      ? `${id}-caps`
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
          onKeyUp={(e) => {
            trackCaps(e);
            onKeyUp?.(e);
          }}
          onKeyDown={(e) => {
            trackCaps(e);
            onKeyDown?.(e);
          }}
          onFocus={(e: FocusEvent<HTMLInputElement>) => {
            setFocused(true);
            onFocus?.(e);
          }}
          onBlur={(e: FocusEvent<HTMLInputElement>) => {
            setFocused(false);
            setCapsLock(false);
            onBlur?.(e);
          }}
          className={`w-full rounded-input border bg-field px-md py-sm text-body-md text-ink outline-none transition-colors placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled ${
            error ? "border-error" : "border-hairline"
          } ${toggleable ? "pr-massive" : ""}`}
          {...inputProps}
        />
        {toggleable ? (
          <button
            type="button"
            onClick={() => setRevealed((v) => !v)}
            className="absolute inset-y-0 right-0 px-md text-label-md text-muted transition-colors hover:text-ink focus-visible:text-ink focus-visible:outline-none"
            aria-label={revealed ? "Hide password" : "Show password"}
          >
            {revealed ? "Hide" : "Show"}
          </button>
        ) : null}
      </div>
      {error ? (
        <p id={`${id}-error`} className="text-body-sm text-error">
          {error}
        </p>
      ) : showCapsWarning ? (
        <p id={`${id}-caps`} role="status" className="text-body-sm text-warning">
          Caps Lock is on.
        </p>
      ) : helper ? (
        <p id={`${id}-helper`} className="text-body-sm text-subtle">
          {helper}
        </p>
      ) : null}
    </div>
  );
}
