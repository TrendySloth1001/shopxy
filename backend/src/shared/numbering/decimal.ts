import { Prisma } from '@prisma/client';

/// Coerce a Prisma.Decimal (or number/null) to a plain JS number. Returns 0
/// for null/undefined so aggregate sums with no rows behave as zero.
export function toNumber(
  value: Prisma.Decimal | number | null | undefined,
): number {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  return Number(value.toString());
}

/// Round to 2 decimal places (currency). Matches the invoice engine's
/// per-line rounding so estimates computed elsewhere line up with the
/// authoritative invoice total for the common no-cess case.
export function round2(v: number): number {
  return Math.round((v + Number.EPSILON) * 100) / 100;
}
