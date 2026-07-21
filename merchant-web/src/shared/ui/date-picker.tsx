"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useLocale, useTranslations } from "next-intl";
import { Calendar as CalendarIcon, ChevronLeft, ChevronRight, X } from "lucide-react";
import { ComboSelect, type ComboOption } from "./combo-select";

/**
 * Custom date picker — our replacement for the native `<input type="date">`
 * (no browser-native calendar anywhere). A pill trigger shows the formatted
 * date; clicking opens a month-grid popover with prev/next navigation,
 * keyboard support (arrows move day, PageUp/Down move month, Enter selects,
 * Escape closes) and min/max clamping. Values are `YYYY-MM-DD` strings, exactly
 * like the native input it replaces. Pass `value=""` for the empty state.
 */
export function DatePicker({
  label,
  ariaLabel,
  value,
  onChange,
  min,
  max,
  placeholder,
  disabled,
  clearable = false,
  className,
}: {
  label?: string;
  ariaLabel?: string;
  value: string;
  onChange: (v: string) => void;
  min?: string;
  max?: string;
  placeholder?: string;
  disabled?: boolean;
  clearable?: boolean;
  className?: string;
}) {
  const t = useTranslations("common");
  const locale = useLocale();
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  const selected = parseYmd(value);
  const minD = min ? parseYmd(min) : null;
  const maxD = max ? parseYmd(max) : null;

  const [view, setView] = useState<Date>(() => startOfMonth(selected ?? new Date()));
  const [focus, setFocus] = useState<Date>(() => selected ?? clamp(new Date(), minD, maxD));

  // Re-anchor the grid on open — in the handler, not an effect, to avoid a
  // synchronous setState-in-effect.
  function openPicker() {
    const anchor = selected ?? clamp(new Date(), minD, maxD);
    setView(startOfMonth(anchor));
    setFocus(anchor);
    setOpen(true);
  }

  // Close on outside-click.
  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, [open]);

  const fmt = useMemo(
    () => new Intl.DateTimeFormat(locale, { day: "numeric", month: "short", year: "numeric" }),
    [locale],
  );
  const monthFmt = useMemo(
    () => new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" }),
    [locale],
  );
  const weekdays = useMemo(() => weekdayLabels(locale), [locale]);

  function commit(d: Date) {
    if (isDisabledDay(d, minD, maxD)) return;
    onChange(toYmd(d));
    setOpen(false);
  }

  function shiftFocus(days: number) {
    setFocus((f) => {
      const next = addDays(f, days);
      setView(startOfMonth(next));
      return next;
    });
  }

  function onGridKeyDown(e: React.KeyboardEvent) {
    switch (e.key) {
      case "ArrowLeft":
        e.preventDefault();
        shiftFocus(-1);
        break;
      case "ArrowRight":
        e.preventDefault();
        shiftFocus(1);
        break;
      case "ArrowUp":
        e.preventDefault();
        shiftFocus(-7);
        break;
      case "ArrowDown":
        e.preventDefault();
        shiftFocus(7);
        break;
      case "PageUp":
        e.preventDefault();
        setView((v) => addMonths(v, -1));
        setFocus((f) => addMonths2(f, -1));
        break;
      case "PageDown":
        e.preventDefault();
        setView((v) => addMonths(v, 1));
        setFocus((f) => addMonths2(f, 1));
        break;
      case "Enter":
      case " ":
        e.preventDefault();
        commit(focus);
        break;
      case "Escape":
        e.preventDefault();
        setOpen(false);
        break;
    }
  }

  const cells = useMemo(() => monthGrid(view), [view]);
  const today = new Date();

  return (
    <div className={`flex flex-col gap-xs ${className ?? ""}`}>
      {label ? <span className="text-label-md text-muted">{label}</span> : null}
      <div ref={rootRef} className="relative">
        <button
          type="button"
          disabled={disabled}
          onClick={() => (open ? setOpen(false) : openPicker())}
          aria-haspopup="dialog"
          aria-expanded={open}
          aria-label={label ? undefined : ariaLabel}
          className={`flex h-10 w-full items-center gap-sm rounded-input border bg-field px-md text-left text-body-md outline-none transition-colors disabled:bg-field-tint disabled:text-disabled ${
            open ? "border-brand ring-2 ring-brand-soft" : "border-hairline hover:border-muted"
          }`}
        >
          <CalendarIcon size={16} className="shrink-0 text-subtle" />
          <span className={`min-w-0 flex-1 truncate ${selected ? "text-ink" : "text-subtle"}`}>
            {selected ? fmt.format(selected) : (placeholder ?? t("datePicker.placeholder"))}
          </span>
          {clearable && selected && !disabled ? (
            <span
              role="button"
              tabIndex={-1}
              aria-label={t("datePicker.clear")}
              onClick={(e) => {
                e.stopPropagation();
                onChange("");
              }}
              className="shrink-0 rounded-full p-px text-subtle hover:text-ink"
            >
              <X size={14} />
            </span>
          ) : null}
        </button>

        {open ? (
          <div
            role="dialog"
            aria-label={label ?? ariaLabel ?? t("datePicker.placeholder")}
            onKeyDown={onGridKeyDown}
            className="absolute left-0 z-30 mt-xs w-72 rounded-input border border-hairline bg-field p-md shadow-menu"
          >
            {/* Month header */}
            <div className="mb-sm flex items-center justify-between">
              <IconNav
                label={t("datePicker.prevMonth")}
                onClick={() => setView((v) => addMonths(v, -1))}
              >
                <ChevronLeft size={16} />
              </IconNav>
              <span className="text-body-md font-medium text-ink">{monthFmt.format(view)}</span>
              <IconNav
                label={t("datePicker.nextMonth")}
                onClick={() => setView((v) => addMonths(v, 1))}
              >
                <ChevronRight size={16} />
              </IconNav>
            </div>

            {/* Weekday row */}
            <div className="grid grid-cols-7 gap-px">
              {weekdays.map((w, i) => (
                <span
                  key={i}
                  className="py-xs text-center text-label-md uppercase tracking-wide text-subtle"
                >
                  {w}
                </span>
              ))}
            </div>

            {/* Day grid */}
            <div className="grid grid-cols-7 gap-px" role="grid">
              {cells.map((d) => {
                const inMonth = d.getMonth() === view.getMonth();
                const isSel = selected != null && sameDay(d, selected);
                const isToday = sameDay(d, today);
                const isFocus = sameDay(d, focus);
                const off = isDisabledDay(d, minD, maxD);
                return (
                  <button
                    key={toYmd(d)}
                    type="button"
                    disabled={off}
                    tabIndex={isFocus ? 0 : -1}
                    aria-pressed={isSel}
                    aria-current={isToday ? "date" : undefined}
                    onClick={() => commit(d)}
                    onMouseEnter={() => setFocus(d)}
                    className={`flex h-9 items-center justify-center rounded-button text-body-md tabular-nums transition-colors disabled:text-disabled disabled:hover:bg-transparent ${
                      isSel
                        ? "bg-brand text-white"
                        : isFocus
                          ? "bg-brand-soft text-brand-strong"
                          : inMonth
                            ? "text-ink hover:bg-surface-tint"
                            : "text-subtle hover:bg-surface-tint"
                    } ${isToday && !isSel ? "ring-1 ring-brand-soft" : ""}`}
                  >
                    {d.getDate()}
                  </button>
                );
              })}
            </div>

            {/* Today shortcut */}
            <div className="mt-sm flex justify-end">
              <button
                type="button"
                onClick={() => commit(clamp(new Date(), minD, maxD))}
                className="rounded-button px-sm py-xs text-label-md text-brand-strong hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                {t("datePicker.today")}
              </button>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}

/**
 * Custom time picker — two dropdowns (hour + minute), no native time input.
 * Value is a 24h `HH:mm` string (empty = unset, treated as 00:00 on edit).
 */
export function TimeSelect({
  value,
  onChange,
  disabled,
  className,
}: {
  value: string;
  onChange: (hhmm: string) => void;
  disabled?: boolean;
  className?: string;
}) {
  const t = useTranslations("common");
  const [h, m] = value ? value.split(":") : ["", ""];
  const hours: ComboOption[] = useMemo(
    () => Array.from({ length: 24 }, (_, i) => ({ value: pad2(i), label: pad2(i) })),
    [],
  );
  const minutes: ComboOption[] = useMemo(
    () => Array.from({ length: 60 }, (_, i) => ({ value: pad2(i), label: pad2(i) })),
    [],
  );
  return (
    <div className={`flex items-center gap-xs ${className ?? ""}`}>
      <ComboSelect
        ariaLabel={t("timeSelect.hour")}
        value={h || "00"}
        onChange={(v) => onChange(`${v}:${m || "00"}`)}
        options={hours}
        disabled={disabled}
        className="w-20"
      />
      <span className="text-body-md text-muted">:</span>
      <ComboSelect
        ariaLabel={t("timeSelect.minute")}
        value={m || "00"}
        onChange={(v) => onChange(`${h || "00"}:${v}`)}
        options={minutes}
        disabled={disabled}
        className="w-20"
      />
    </div>
  );
}

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

function IconNav({
  label,
  onClick,
  children,
}: {
  label: string;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className="flex h-8 w-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      {children}
    </button>
  );
}

// ── date helpers (all local-time, matching native date-input semantics) ──

function parseYmd(s: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
  if (!m) return null;
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return Number.isNaN(d.getTime()) ? null : d;
}
function toYmd(d: Date): string {
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}
function sameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}
function startOfMonth(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}
function addMonths(d: Date, n: number): Date {
  return new Date(d.getFullYear(), d.getMonth() + n, 1);
}
/** Add months keeping the day-of-month (clamped to month length). */
function addMonths2(d: Date, n: number): Date {
  const target = new Date(d.getFullYear(), d.getMonth() + n, 1);
  const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate();
  return new Date(target.getFullYear(), target.getMonth(), Math.min(d.getDate(), lastDay));
}
function addDays(d: Date, n: number): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
}
function clamp(d: Date, min: Date | null, max: Date | null): Date {
  if (min && d < min) return new Date(min);
  if (max && d > max) return new Date(max);
  return d;
}
function isDisabledDay(d: Date, min: Date | null, max: Date | null): boolean {
  if (min && d < startOfDay(min)) return true;
  if (max && d > endOfDay(max)) return true;
  return false;
}
function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}
function endOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59);
}
/** 42-cell (6-week) grid starting on the Sunday on/before the 1st. */
function monthGrid(view: Date): Date[] {
  const first = startOfMonth(view);
  const start = addDays(first, -first.getDay()); // back up to Sunday
  return Array.from({ length: 42 }, (_, i) => addDays(start, i));
}
/** Localised short weekday labels, Sunday-first. */
function weekdayLabels(locale: string): string[] {
  const fmt = new Intl.DateTimeFormat(locale, { weekday: "short" });
  // 2023-01-01 is a Sunday.
  return Array.from({ length: 7 }, (_, i) => fmt.format(new Date(2023, 0, 1 + i)));
}
