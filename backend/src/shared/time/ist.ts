export const IST_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;
export const DAY_MS = 24 * 60 * 60 * 1000;

export function istDayStart(d: Date): Date {
  const ist = new Date(d.getTime() + IST_OFFSET_MS);
  const midnight = Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate());
  return new Date(midnight - IST_OFFSET_MS);
}

export function istMonthStart(d: Date): Date {
  const ist = new Date(d.getTime() + IST_OFFSET_MS);
  const first = Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), 1);
  return new Date(first - IST_OFFSET_MS);
}

export function istDateKey(instant: number): string {
  return new Date(instant + IST_OFFSET_MS).toISOString().slice(0, 10);
}

export function istDateUTC(instant: Date): Date {
  const ist = new Date(instant.getTime() + IST_OFFSET_MS);
  return new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()));
}

export function reportDayRange(dayDate: Date): { from: Date; to: Date } {
  const from = new Date(dayDate.getTime() + IST_OFFSET_MS);
  return { from, to: new Date(from.getTime() + DAY_MS) };
}

export function reportDayKey(instant: Date): string {
  return new Date(instant.getTime() - IST_OFFSET_MS).toISOString().slice(0, 10);
}

export function reportDayKeysEndingAt(now: Date, count: number): string[] {
  const base = new Date(`${reportDayKey(now)}T00:00:00.000Z`).getTime();
  return Array.from({ length: count }, (_, i) =>
    new Date(base - (count - 1 - i) * DAY_MS).toISOString().slice(0, 10),
  );
}
