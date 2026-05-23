import prisma from '../../infra/db/prisma.js';

/// Atomic per-key counter. Postgres UPSERT in a single round-trip means
/// two concurrent allocations never collide — fixes the `count()+1`
/// race flagged in audit C4.
async function nextCounter(key: string): Promise<number> {
  const rows = await prisma.$queryRaw<Array<{ value: number }>>`
    INSERT INTO "counters" ("key", "value") VALUES (${key}, 1)
    ON CONFLICT ("key") DO UPDATE SET "value" = "counters"."value" + 1
    RETURNING "value"
  `;
  return rows[0].value;
}

function currentYearMonth(): string {
  return new Date().toISOString().slice(0, 7).replace('-', '');
}

export async function nextInvoiceNo(type: 'SALE' | 'PURCHASE'): Promise<string> {
  const prefix = type === 'SALE' ? 'INV' : 'PUR';
  const ym = currentYearMonth();
  const seq = await nextCounter(`${prefix}-${ym}`);
  return `${prefix}-${ym}-${String(seq).padStart(5, '0')}`;
}

export async function nextChallanNo(): Promise<string> {
  const ym = currentYearMonth();
  const seq = await nextCounter(`CH-${ym}`);
  return `CH-${ym}-${String(seq).padStart(5, '0')}`;
}
