import { Prisma } from '@prisma/client';

export function toNumber(
  value: Prisma.Decimal | number | null | undefined,
): number {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  return Number(value.toString());
}

export function round2(v: number): number {
  return Math.round((v + Number.EPSILON) * 100) / 100;
}
