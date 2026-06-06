/**
 * Date/time helpers shared by the scheduling-heavy marketing screens
 * (carousels, flash deals, spotlight, promotions). The backend stores and
 * accepts UTC ISO-8601 strings (`z.string().datetime()`); the merchant edits
 * in their local timezone via native `<input type="datetime-local">`.
 */

const pad = (n: number) => String(n).padStart(2, "0");

/** Current instant as a UTC ISO string. (Wrapper keeps `new Date()` out of
 *  component render scope, where the react-hooks/purity rule forbids it.) */
export function nowIso(): string {
  return new Date().toISOString();
}

/** ISO string `ms` milliseconds from now. */
export function isoFromNow(ms: number): string {
  return new Date(Date.now() + ms).toISOString();
}

/** ISO (UTC) → value for `<input type="datetime-local">` (local wall time). */
export function isoToLocalInput(iso?: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours(),
  )}:${pad(d.getMinutes())}`;
}

/** `<input type="datetime-local">` value → UTC ISO string (or null if empty). */
export function localInputToIso(value: string): string | null {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

/** Today as a `YYYY-MM-DD` string (local) for `<input type="date">`. */
export function todayInputDate(): string {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** `YYYY-MM-DD` for `n` days before today (local). */
export function inputDateDaysAgo(n: number): string {
  const d = new Date(Date.now() - n * 24 * 60 * 60 * 1000);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** `YYYY-MM-DD` for the first day of the current month (local). */
export function startOfMonthInput(): string {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-01`;
}

/** `YYYY-MM-DD` for the start of the current Indian financial year (1 April). */
export function financialYearStartInput(): string {
  const d = new Date();
  const year = d.getMonth() >= 3 ? d.getFullYear() : d.getFullYear() - 1;
  return `${year}-04-01`;
}

/** `YYYY-MM-DD` → UTC ISO at the start (00:00) or end (23:59:59.999) of that day. */
export function dateInputToIso(value: string, endOfDay = false): string {
  const d = new Date(`${value}T${endOfDay ? "23:59:59.999" : "00:00:00"}`);
  return d.toISOString();
}

const dateTimeFmt = new Intl.DateTimeFormat("en-IN", {
  day: "numeric",
  month: "short",
  year: "numeric",
  hour: "numeric",
  minute: "2-digit",
});

/** "5 Jun 2026, 2:30 pm" — null/invalid → "—". */
export function formatDateTime(iso?: string | null): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  return dateTimeFmt.format(d);
}

/** "5 Jun, 2:30 pm → 6 Jun, 8:00 pm". */
export function formatDateRange(startIso?: string | null, endIso?: string | null): string {
  return `${formatDateTime(startIso)}  →  ${formatDateTime(endIso)}`;
}

/** "just now" / "5m ago" / "2h ago" / "3d ago", falling back to the date. */
export function formatRelativeTime(iso?: string | null): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  const diffMs = Date.now() - d.getTime();
  if (diffMs < 0) return "just now";
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  return formatDateTime(iso);
}

/** Relative "live window" state for a [start, end] pair against now. */
export type WindowState = "scheduled" | "live" | "ended";

export function windowState(
  startIso?: string | null,
  endIso?: string | null,
  now: Date = new Date(),
): WindowState {
  const start = startIso ? new Date(startIso) : null;
  const end = endIso ? new Date(endIso) : null;
  if (start && now < start) return "scheduled";
  if (end && now > end) return "ended";
  return "live";
}
