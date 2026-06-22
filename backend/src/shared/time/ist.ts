/// IST (Asia/Kolkata, fixed +05:30, no DST) day/month helpers shared by the
/// dashboard and the analytics roll-ups so they bucket days identically.

export const IST_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;
export const DAY_MS = 24 * 60 * 60 * 1000;

/// Real UTC instant of the start of the IST calendar day containing `d`.
export function istDayStart(d: Date): Date {
  const ist = new Date(d.getTime() + IST_OFFSET_MS);
  const midnight = Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate());
  return new Date(midnight - IST_OFFSET_MS);
}

/// Real UTC instant of the start of the IST calendar month containing `d`.
export function istMonthStart(d: Date): Date {
  const ist = new Date(d.getTime() + IST_OFFSET_MS);
  const first = Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), 1);
  return new Date(first - IST_OFFSET_MS);
}

/// IST calendar date as YYYY-MM-DD (matches `to_char(... AT TIME ZONE 'Asia/Kolkata')`).
export function istDateKey(instant: number): string {
  return new Date(instant + IST_OFFSET_MS).toISOString().slice(0, 10);
}

/// Midnight-UTC Date whose UTC calendar date equals the IST calendar date of
/// `instant`. This is what goes into a Postgres `DATE` column (`@db.Date`) so the
/// stored day is the IST day, not the UTC day.
export function istDateUTC(instant: Date): Date {
  const ist = new Date(instant.getTime() + IST_OFFSET_MS);
  return new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()));
}

/// The [from, to) instant span for the day bucket the REPORTS module assigns,
/// so roll-ups aggregate exactly the rows the Reports screen does.
///
/// Quirk: `invoice_date` / `payment_date` are `timestamp without time zone`
/// (naive UTC) and the reports bucket with `... AT TIME ZONE 'Asia/Kolkata'`,
/// which on a naive column shifts by −5:30. So the bucket for an instant I is
/// `date(I − 5:30)`, i.e. day D spans instants `[D + 5:30, D + 1day + 5:30)`.
/// (`dayDate` is the midnight-UTC Date whose date == the bucket key.)
export function reportDayRange(dayDate: Date): { from: Date; to: Date } {
  const from = new Date(dayDate.getTime() + IST_OFFSET_MS);
  return { from, to: new Date(from.getTime() + DAY_MS) };
}

/// The roll-up/report bucket key (YYYY-MM-DD) an instant falls into — the
/// counterpart of reportDayRange (date of `instant − 5:30`). Use this so the
/// dashboard selects the same day buckets the roll-ups are stored under.
export function reportDayKey(instant: Date): string {
  return new Date(instant.getTime() - IST_OFFSET_MS).toISOString().slice(0, 10);
}

/// Ascending list of `count` bucket keys ending at the bucket containing `now`
/// (oldest → today). Used to build dashboard windows aligned to the roll-ups.
export function reportDayKeysEndingAt(now: Date, count: number): string[] {
  const base = new Date(`${reportDayKey(now)}T00:00:00.000Z`).getTime();
  return Array.from({ length: count }, (_, i) =>
    new Date(base - (count - 1 - i) * DAY_MS).toISOString().slice(0, 10),
  );
}
