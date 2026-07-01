"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Check, ChevronDown, Search } from "lucide-react";

export type ComboOption = { value: string; label: string; hint?: string };

/**
 * A styled single-select dropdown — a nicer replacement for the native
 * `<select>`. Shows the chosen option in a pill-trigger, opens a popover list
 * with hover/selected states, and (when `searchable`) an inline filter. Closes
 * on outside-click or Escape. Pass `value=""` for the unselected/placeholder
 * state.
 */
export function ComboSelect({
  label,
  value,
  onChange,
  options,
  placeholder,
  searchable = false,
  emptyText,
  helper,
  disabled,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: ComboOption[];
  placeholder?: string;
  searchable?: boolean;
  emptyText?: string;
  helper?: string;
  disabled?: boolean;
}) {
  const t = useTranslations("common");
  const placeholderText = placeholder ?? t("comboSelect.placeholder");
  const emptyMessage = emptyText ?? t("comboSelect.empty");
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const rootRef = useRef<HTMLDivElement>(null);

  const selected = options.find((o) => o.value === value) ?? null;

  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onDoc);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDoc);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const q = query.trim().toLowerCase();
  const filtered = searchable && q ? options.filter((o) => o.label.toLowerCase().includes(q)) : options;

  function pick(v: string) {
    onChange(v);
    setOpen(false);
    setQuery("");
  }

  return (
    <div className="flex flex-col gap-xs">
      <span className="text-label-md text-muted">{label}</span>
      <div ref={rootRef} className="relative">
        <button
          type="button"
          disabled={disabled}
          onClick={() => setOpen((o) => !o)}
          aria-haspopup="listbox"
          aria-expanded={open}
          className={`flex h-10 w-full items-center gap-sm rounded-input border bg-field px-md text-left text-body-md outline-none transition-colors disabled:bg-field-tint disabled:text-disabled ${
            open ? "border-brand ring-2 ring-brand-soft" : "border-hairline hover:border-muted"
          }`}
        >
          <span className={`min-w-0 flex-1 truncate ${selected ? "text-ink" : "text-subtle"}`}>
            {selected ? selected.label : placeholderText}
          </span>
          <ChevronDown
            size={16}
            className={`shrink-0 text-subtle transition-transform ${open ? "rotate-180" : ""}`}
          />
        </button>

        {open ? (
          <div
            role="listbox"
            className="absolute left-0 right-0 z-20 mt-xs max-h-60 overflow-auto rounded-input border border-hairline bg-field py-xs shadow-menu"
          >
            {searchable ? (
              <div className="sticky top-0 flex items-center gap-sm border-b border-hairline bg-surface px-md pb-xs">
                <Search size={14} className="shrink-0 text-subtle" />
                <input
                  autoFocus
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder={t("search")}
                  className="h-8 w-full bg-transparent text-body-sm text-ink outline-none placeholder:text-subtle"
                />
              </div>
            ) : null}

            {filtered.length === 0 ? (
              <p className="px-md py-sm text-body-sm text-subtle">{emptyMessage}</p>
            ) : (
              filtered.map((o) => {
                const on = o.value === value;
                return (
                  <button
                    key={o.value}
                    type="button"
                    role="option"
                    aria-selected={on}
                    onClick={() => pick(o.value)}
                    className={`flex w-full items-center gap-sm px-md py-sm text-left transition-colors ${
                      on ? "bg-brand-soft text-brand-strong" : "text-ink hover:bg-surface-tint"
                    }`}
                  >
                    <span className="min-w-0 flex-1 truncate text-body-md">
                      {o.label}
                      {o.hint ? <span className="ml-sm text-body-sm text-subtle">{o.hint}</span> : null}
                    </span>
                    {on ? <Check size={15} className="shrink-0" /> : null}
                  </button>
                );
              })
            )}
          </div>
        ) : null}
      </div>
      {helper ? <span className="text-body-sm text-subtle">{helper}</span> : null}
    </div>
  );
}
