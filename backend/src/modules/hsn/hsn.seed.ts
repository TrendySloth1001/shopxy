import fs from 'node:fs';
import path from 'node:path';
import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';
import { HSN_MASTER, HSN_RATE_REVISION, type HsnMasterEntry } from './hsn.master.js';
import { applyOverlay } from './hsn.rules.js';

const IMPORTED_PATH = path.join(__dirname, 'data', 'hsn.master.json');

type SourcedManifest = {
  entries: HsnMasterEntry[];
  source: 'imported' | 'provisional';
};

export function loadManifest(): SourcedManifest {
  try {
    const raw = JSON.parse(fs.readFileSync(IMPORTED_PATH, 'utf8')) as {
      entries?: HsnMasterEntry[];
    };
    if (Array.isArray(raw.entries) && raw.entries.length > 0) {
      return { entries: applyOverlay(raw.entries), source: 'imported' };
    }
  } catch {
  }
  return { entries: applyOverlay(HSN_MASTER), source: 'provisional' };
}

const DAY_MS = 24 * 60 * 60 * 1000;

function parseDate(iso: string): Date {
  return new Date(`${iso}T00:00:00.000Z`);
}

function effectiveFromOf(entry: HsnMasterEntry): Date {
  return parseDate(entry.since ?? HSN_RATE_REVISION);
}

function sameRule(
  stored: Prisma.JsonValue | null | undefined,
  desired: HsnMasterEntry['rateRule'],
): boolean {
  if (!desired) return stored === null || stored === undefined;
  if (!stored || typeof stored !== 'object' || Array.isArray(stored)) return false;
  const s = stored as Record<string, unknown>;
  return (
    s.kind === desired.kind &&
    Number(s.threshold) === desired.threshold &&
    Number(s.atOrBelow) === desired.atOrBelow &&
    Number(s.above) === desired.above &&
    s.per === desired.per
  );
}

export async function seedHsnMaster(): Promise<{
  created: number;
  updated: number;
  superseded: number;
  deactivated: number;
}> {
  const { entries: manifest, source } = loadManifest();
  if (source === 'provisional') {
    logger.warn(
      { entries: manifest.length },
      'hsn: using the PROVISIONAL hand-written manifest — a curated subset, not the ' +
        'official tariff. Run `npm run hsn:import` against CBIC data and commit ' +
        'src/modules/hsn/data/hsn.master.json before relying on these rates.',
    );
  }

  const existing = await prisma.hsnCode.findMany({
    where: { shopId: null },
    select: {
      id: true,
      code: true,
      kind: true,
      description: true,
      gstRate: true,
      cessRate: true,
      rateNote: true,
      rateRule: true,
      isRatable: true,
      effectiveFrom: true,
      effectiveTo: true,
      isActive: true,
    },
  });
  const key = (code: string, from: Date): string => `${code}@${from.toISOString().slice(0, 10)}`;
  const byKey = new Map(existing.map((r) => [key(r.code, r.effectiveFrom), r]));

  let created = 0;
  let updated = 0;

  for (const entry of manifest) {
    const effectiveFrom = effectiveFromOf(entry);
    const desired = {
      kind: entry.kind ?? ('GOODS' as const),
      description: entry.description,
      gstRate: entry.gstRate,
      cessRate: entry.cessRate ?? 0,
      rateNote: entry.rateNote ?? null,
      rateRule: entry.rateRule
        ? (entry.rateRule as unknown as Prisma.InputJsonValue)
        : Prisma.DbNull,
      isRatable: entry.isRatable ?? true,
      effectiveTo: null,
      isActive: true,
    };
    const row = byKey.get(key(entry.code, effectiveFrom));
    if (!row) {
      await prisma.hsnCode.create({
        data: { code: entry.code, shopId: null, effectiveFrom, ...desired },
      });
      created += 1;
      continue;
    }
    const same =
      row.kind === desired.kind &&
      row.description === desired.description &&
      Number(row.gstRate) === desired.gstRate &&
      Number(row.cessRate) === desired.cessRate &&
      (row.rateNote ?? null) === desired.rateNote &&
      sameRule(row.rateRule, entry.rateRule) &&
      row.isRatable === desired.isRatable &&
      row.effectiveTo === null &&
      row.isActive;
    if (same) continue;
    await prisma.hsnCode.update({ where: { id: row.id }, data: desired });
    updated += 1;
  }

  const currentFrom = new Map<string, Date>();
  for (const entry of manifest) {
    const from = effectiveFromOf(entry);
    const known = currentFrom.get(entry.code);
    if (!known || from > known) currentFrom.set(entry.code, from);
  }

  let superseded = 0;
  for (const [code, current] of currentFrom) {
    const stale = existing.filter(
      (r) =>
        r.code === code &&
        r.effectiveFrom < current &&
        (r.effectiveTo === null || r.effectiveTo >= current),
    );
    if (stale.length === 0) continue;
    const res = await prisma.hsnCode.updateMany({
      where: { id: { in: stale.map((r) => r.id) } },
      data: { effectiveTo: new Date(current.getTime() - DAY_MS) },
    });
    superseded += res.count;
  }

  const orphans = existing.filter((r) => r.isActive && !currentFrom.has(r.code));
  let deactivated = 0;
  if (orphans.length > 0) {
    const res = await prisma.hsnCode.updateMany({
      where: { id: { in: orphans.map((r) => r.id) } },
      data: { isActive: false },
    });
    deactivated = res.count;
  }

  logger.info(
    { created, updated, superseded, deactivated, entries: manifest.length, source },
    'hsn: rate master synced',
  );
  return { created, updated, superseded, deactivated };
}
