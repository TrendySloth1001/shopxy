"use client";

import { useEffect, useId, useMemo, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Check, ChevronDown, Search } from "lucide-react";

export type ComboOption = { value: string; label: string; hint?: string };

/**
 * A styled single-select dropdown — our custom replacement for the native
 * `<select>` (no browser-native menu anywhere). Shows the chosen option in a
 * pill trigger, opens a popover list with hover/selected/active states, full
 * keyboard support (Arrow/Home/End/Enter/Space + type-ahead), and — when
 * `searchable` — an inline filter. Closes on outside-click, Escape or blur.
 *
 * `label` is optional: omit it for inline/toolbar triggers and pass `ariaLabel`
 * instead. `className` styles the outer wrapper (e.g. width). Pass `value=""`
 * for the unselected/placeholder state.
 */
export function ComboSelect({
  label,
  ariaLabel,
  value,
  onChange,
  options,
  placeholder,
  searchable = false,
  emptyText,
  helper,
  disabled,
  className,
}: {
  label?: string;
  ariaLabel?: string;
  value: string;
  onChange: (v: string) => void;
  options: ComboOption[];
  placeholder?: string;
  searchable?: boolean;
  emptyText?: string;
  helper?: string;
  disabled?: boolean;
  className?: string;
}) {
  const t = useTranslations("common");
  const placeholderText = placeholder ?? t("comboSelect.placeholder");
  const emptyMessage = emptyText ?? t("comboSelect.empty");
  const baseId = useId();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [active, setActive] = useState(0); // highlighted index within `filtered`
  const rootRef = useRef<HTMLDivElement>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const typeahead = useRef<{ buffer: string; at: number }>({ buffer: "", at: 0 });

  const selected = options.find((o) => o.value === value) ?? null;

  const q = query.trim().toLowerCase();
  const filtered = useMemo(
    () => (searchable && q ? options.filter((o) => o.label.toLowerCase().includes(q)) : options),
    [searchable, q, options],
  );

  // Close on outside-click.
  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, [open]);

  // Open and highlight the selected row (or the first). Done in the handler,
  // not an effect, so there's no synchronous setState-in-effect.
  function openList() {
    const idx = filtered.findIndex((o) => o.value === value);
    setActive(idx >= 0 ? idx : 0);
    setOpen(true);
  }

  // Keep the active row scrolled into view as it changes.
  useEffect(() => {
    if (!open || !listRef.current) return;
    const el = listRef.current.querySelector<HTMLElement>(`#${cssId(baseId, active)}`);
    el?.scrollIntoView({ block: "nearest" });
  }, [active, open, baseId]);

  function pick(v: string) {
    onChange(v);
    setOpen(false);
    setQuery("");
  }

  function moveActive(delta: number) {
    setActive((i) => {
      if (filtered.length === 0) return 0;
      return (i + delta + filtered.length) % filtered.length;
    });
  }

  // Type-ahead: jump to the next option whose label starts with the typed run.
  function onTypeahead(key: string) {
    if (key.length !== 1) return;
    const now = Date.now();
    const ta = typeahead.current;
    ta.buffer = now - ta.at > 700 ? key : ta.buffer + key;
    ta.at = now;
    const needle = ta.buffer.toLowerCase();
    const from = ta.buffer.length === 1 ? active + 1 : active;
    for (let n = 0; n < filtered.length; n++) {
      const idx = (from + n) % filtered.length;
      if (filtered[idx].label.toLowerCase().startsWith(needle)) {
        setActive(idx);
        return;
      }
    }
  }

  function onKeyDown(e: React.KeyboardEvent) {
    if (!open) {
      if (e.key === "ArrowDown" || e.key === "Enter" || (e.key === " " && !searchable)) {
        e.preventDefault();
        openList();
      }
      return;
    }
    switch (e.key) {
      case "ArrowDown":
        e.preventDefault();
        moveActive(1);
        break;
      case "ArrowUp":
        e.preventDefault();
        moveActive(-1);
        break;
      case "Home":
        e.preventDefault();
        setActive(0);
        break;
      case "End":
        e.preventDefault();
        setActive(filtered.length - 1);
        break;
      case "Enter":
        e.preventDefault();
        if (filtered[active]) pick(filtered[active].value);
        break;
      case " ":
        if (searchable) break; // a space belongs to the query
        e.preventDefault();
        if (filtered[active]) pick(filtered[active].value);
        break;
      case "Escape":
        e.preventDefault();
        setOpen(false);
        break;
      case "Tab":
        setOpen(false);
        break;
      default:
        if (!searchable) onTypeahead(e.key);
    }
  }

  return (
    <div className={`flex flex-col gap-xs ${className ?? ""}`}>
      {label ? <span className="text-label-md text-muted">{label}</span> : null}
      <div ref={rootRef} className="relative">
        <button
          type="button"
          disabled={disabled}
          onClick={() => (open ? setOpen(false) : openList())}
          onKeyDown={onKeyDown}
          role="combobox"
          aria-controls={`combo-list-${baseId.replace(/[^a-zA-Z0-9_-]/g, "")}`}
          aria-haspopup="listbox"
          aria-expanded={open}
          aria-label={label ? undefined : ariaLabel}
          aria-activedescendant={open && filtered[active] ? cssId(baseId, active) : undefined}
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
            ref={listRef}
            id={`combo-list-${baseId.replace(/[^a-zA-Z0-9_-]/g, "")}`}
            role="listbox"
            aria-label={label ?? ariaLabel}
            className="absolute left-0 right-0 z-30 mt-xs max-h-60 overflow-auto rounded-input border border-hairline bg-field py-xs shadow-menu"
          >
            {searchable ? (
              <div className="sticky top-0 flex items-center gap-sm border-b border-hairline bg-surface px-md pb-xs">
                <Search size={14} className="shrink-0 text-subtle" />
                <input
                  autoFocus
                  value={query}
                  onChange={(e) => {
                    setQuery(e.target.value);
                    setActive(0);
                  }}
                  onKeyDown={onKeyDown}
                  placeholder={t("search")}
                  className="h-8 w-full bg-transparent text-body-sm text-ink outline-none placeholder:text-subtle"
                />
              </div>
            ) : null}

            {filtered.length === 0 ? (
              <p className="px-md py-sm text-body-sm text-subtle">{emptyMessage}</p>
            ) : (
              filtered.map((o, i) => {
                const on = o.value === value;
                const activeRow = i === active;
                return (
                  <button
                    key={o.value}
                    id={cssId(baseId, i)}
                    type="button"
                    role="option"
                    aria-selected={on}
                    onClick={() => pick(o.value)}
                    onMouseEnter={() => setActive(i)}
                    className={`flex w-full items-center gap-sm px-md py-sm text-left transition-colors ${
                      on
                        ? "bg-brand-soft text-brand-strong"
                        : activeRow
                          ? "bg-surface-tint text-ink"
                          : "text-ink"
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

/** Stable DOM id for the option at `index` (aria-activedescendant target). */
function cssId(base: string, index: number): string {
  return `combo-${base.replace(/[^a-zA-Z0-9_-]/g, "")}-opt-${index}`;
}
