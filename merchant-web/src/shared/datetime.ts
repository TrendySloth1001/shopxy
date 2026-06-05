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
