import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import type { HsnRateRule } from './hsn.master.js';
import {
  copyFor,
  normalizeTerm,
  resolveLocale,
  searchCopy,
  type HsnLocale,
} from './hsn.copy.js';

export const MIN_CODE_LENGTH = 4;

export type RateSource = 'HSN' | 'HSN_RULE' | 'OVERRIDE';

export type AppliedRule = {
  threshold: number;
  atOrBelow: number;
  above: number;
  per: HsnRateRule['per'];
  testedPrice: number | null;
};

export type HsnRateResolution = {
  requestedCode: string;
  code: string;
  exact: boolean;
  gstRate: number;
  cessRate: number;
  source: RateSource;
  revision: string;
  rateNote: string | null;
  rule: AppliedRule | null;
};

export type UnratedReason = 'CONDITIONAL' | 'NO_RATE_ON_FILE';

export type HsnRateOutcome =
  | { status: 'RESOLVED'; rate: HsnRateResolution }
  | {
      status: 'UNRATED';
      requestedCode: string;
      code: string;
      reason: UnratedReason;
      note: string | null;
    }
  | { status: 'UNKNOWN'; requestedCode: string };

export type HsnNode = { code: string; name: string };

export type HsnSearchResult = {
  code: string;
  kind: 'GOODS' | 'SERVICES';
  name: string;
  definition: string | null;
  gstRate: number;
  cessRate: number;
  rateNote: string | null;
  rule: Omit<AppliedRule, 'testedPrice'> | null;
  breadcrumb: HsnNode[];
  notHere: HsnNode[];
  fromShortcut: boolean;
};

export function normalizeHsn(raw: string): string {
  return raw.replace(/\D/g, '');
}

function startOfDay(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

function revisionOf(effectiveFrom: Date): string {
  return effectiveFrom.toISOString().slice(0, 10);
}

export function codeLadder(code: string): string[] {
  const out: string[] = [];
  if (code.length >= MIN_CODE_LENGTH) out.push(code);
  for (const len of [8, 6, 4, 2]) {
    if (code.length <= len) continue;
    const slice = code.slice(0, len);
    if (!out.includes(slice)) out.push(slice);
  }
  if (code.length > 2 && !out.includes(code.slice(0, 2))) out.push(code.slice(0, 2));
  return out;
}

function inForceOn(asOf: Date): Prisma.HsnCodeWhereInput {
  const day = startOfDay(asOf);
  return {
    isActive: true,
    effectiveFrom: { lte: day },
    OR: [{ effectiveTo: null }, { effectiveTo: { gte: day } }],
  };
}

const ROW_SELECT = {
  code: true,
  kind: true,
  description: true,
  gstRate: true,
  cessRate: true,
  rateNote: true,
  rateRule: true,
  isRatable: true,
  effectiveFrom: true,
  shopId: true,
} as const;

type Row = {
  code: string;
  kind: 'GOODS' | 'SERVICES';
  description: string;
  gstRate: Prisma.Decimal;
  cessRate: Prisma.Decimal;
  rateNote: string | null;
  rateRule: Prisma.JsonValue;
  isRatable: boolean;
  effectiveFrom: Date;
  shopId: number | null;
};

function parseRule(raw: Prisma.JsonValue): HsnRateRule | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const r = raw as Record<string, unknown>;
  if (r.kind !== 'PRICE_THRESHOLD') return null;
  const { threshold, atOrBelow, above, per } = r;
  if (
    typeof threshold !== 'number' ||
    typeof atOrBelow !== 'number' ||
    typeof above !== 'number' ||
    (per !== 'PIECE' && per !== 'PAIR' && per !== 'UNIT_PER_DAY')
  ) {
    return null;
  }
  return { kind: 'PRICE_THRESHOLD', threshold, atOrBelow, above, per };
}

function displayName(code: string, fallback: string, locale: HsnLocale): string {
  return copyFor(code, locale)?.name ?? fallback;
}

function conditionOf(row: Pick<Row, 'isRatable' | 'rateNote'>): string | null {
  if (row.isRatable) return null;
  const note = row.rateNote?.trim();
  return note ? note : null;
}

export class HsnService {
  async resolveRate(params: {
    code: string;
    shopId?: number;
    price?: number;
    asOf?: Date;
  }): Promise<HsnRateResolution | null> {
    const outcome = await this.resolveOutcome(params);
    return outcome.status === 'RESOLVED' ? outcome.rate : null;
  }

  async resolveOutcome(params: {
    code: string;
    shopId?: number;
    price?: number;
    asOf?: Date;
  }): Promise<HsnRateOutcome> {
    const requestedCode = normalizeHsn(params.code);
    if (requestedCode.length < MIN_CODE_LENGTH) return { status: 'UNKNOWN', requestedCode };
    const asOf = params.asOf ?? new Date();
    const day = startOfDay(asOf);
    const ladder = codeLadder(requestedCode);

    if (params.shopId !== undefined) {
      const override = await prisma.shopHsnOverride.findFirst({
        where: {
          shopId: params.shopId,
          code: requestedCode,
          isActive: true,
          effectiveFrom: { lte: day },
          OR: [{ effectiveTo: null }, { effectiveTo: { gte: day } }],
        },
        orderBy: { effectiveFrom: 'desc' },
        select: { code: true, gstRate: true, cessRate: true, effectiveFrom: true, reason: true },
      });
      if (override) {
        return {
          status: 'RESOLVED',
          rate: {
            requestedCode,
            code: override.code,
            exact: true,
            gstRate: Number(override.gstRate),
            cessRate: Number(override.cessRate),
            source: 'OVERRIDE',
            revision: revisionOf(override.effectiveFrom),
            rateNote: override.reason,
            rule: null,
          },
        };
      }
    }

    const rows = (await prisma.hsnCode.findMany({
      where: {
        AND: [inForceOn(asOf), { shopId: null }, { code: { in: ladder } }],
      },
      select: ROW_SELECT,
    })) as Row[];
    if (rows.length === 0) return { status: 'UNKNOWN', requestedCode };

    const byCode = new Map<string, Row>();
    for (const row of rows) {
      const seen = byCode.get(row.code);
      if (!seen || row.effectiveFrom > seen.effectiveFrom) byCode.set(row.code, row);
    }

    const walk = [...ladder].sort((a, b) => b.length - a.length);
    let deepestKnown: Row | null = null;
    for (const code of walk) {
      const row = byCode.get(code);
      if (!row) continue;
      if (!deepestKnown && code.length >= MIN_CODE_LENGTH) deepestKnown = row;
      if (row.isRatable) {
        return { status: 'RESOLVED', rate: this.rateFrom(row, requestedCode, params.price) };
      }
      const condition = conditionOf(row);
      if (condition) {
        return {
          status: 'UNRATED',
          requestedCode,
          code: row.code,
          reason: 'CONDITIONAL',
          note: condition,
        };
      }
    }

    if (!deepestKnown) return { status: 'UNKNOWN', requestedCode };
    return {
      status: 'UNRATED',
      requestedCode,
      code: deepestKnown.code,
      reason: 'NO_RATE_ON_FILE',
      note: deepestKnown.rateNote,
    };
  }

  private rateFrom(row: Row, requestedCode: string, price?: number): HsnRateResolution {
    const rule = parseRule(row.rateRule);
    let gstRate = Number(row.gstRate);
    let source: RateSource = 'HSN';
    let applied: AppliedRule | null = null;

    if (rule) {
      const testedPrice = typeof price === 'number' && Number.isFinite(price) ? price : null;
      applied = { ...rule, testedPrice };
      if (testedPrice !== null) {
        gstRate = testedPrice <= rule.threshold ? rule.atOrBelow : rule.above;
        source = 'HSN_RULE';
      }
    }

    return {
      requestedCode,
      code: row.code,
      exact: row.code === requestedCode,
      gstRate,
      cessRate: Number(row.cessRate),
      source,
      revision: revisionOf(row.effectiveFrom),
      rateNote: row.rateNote,
      rule: applied,
    };
  }

  async breadcrumb(code: string, locale: HsnLocale = 'en', asOf?: Date): Promise<HsnNode[]> {
    const normalized = normalizeHsn(code);
    if (!normalized) return [];
    const ladder = codeLadder(normalized);
    if (ladder.length === 0) return [];
    const rows = await prisma.hsnCode.findMany({
      where: {
        AND: [inForceOn(asOf ?? new Date()), { shopId: null }, { code: { in: ladder } }],
      },
      select: { code: true, description: true },
    });
    const byCode = new Map(rows.map((r) => [r.code, r.description]));
    return ladder
      .filter((c) => byCode.has(c))
      .sort((a, b) => a.length - b.length)
      .map((c) => ({ code: c, name: displayName(c, byCode.get(c)!, locale) }));
  }

  async search(params: {
    query: string;
    shopId?: number;
    locale?: string;
    kind?: 'GOODS' | 'SERVICES';
    limit?: number;
    asOf?: Date;
  }): Promise<HsnSearchResult[]> {
    const locale = resolveLocale(params.locale);
    const limit = Math.min(Math.max(params.limit ?? 20, 1), 50);
    const asOf = params.asOf ?? new Date();
    const q = params.query.trim();
    const digits = normalizeHsn(q);

    const shortcutCodes: string[] = [];
    if (params.shopId !== undefined && q.length > 0) {
      const term = normalizeTerm(q);
      const hits = await prisma.shopHsnShortcut.findMany({
        where: {
          shopId: params.shopId,
          OR: [{ term: { startsWith: term } }, { code: { startsWith: digits || ' ' } }],
        },
        orderBy: [{ useCount: 'desc' }, { lastUsedAt: 'desc' }],
        take: 5,
        select: { code: true },
      });
      for (const h of hits) if (!shortcutCodes.includes(h.code)) shortcutCodes.push(h.code);
    }

    const lexical = digits.length > 0 ? [] : searchCopy(q, limit);
    const candidateCodes = [...new Set([...shortcutCodes, ...lexical])];

    const rows = (await prisma.hsnCode.findMany({
      where: {
        AND: [
          inForceOn(asOf),
          { shopId: null },
          { isRatable: true },
          ...(params.kind ? [{ kind: params.kind }] : []),
          {
            OR: [
              ...(digits.length > 0 ? [{ code: { startsWith: digits } }] : []),
              ...(candidateCodes.length > 0 ? [{ code: { in: candidateCodes } }] : []),
              ...(q.length === 0 && candidateCodes.length === 0 ? [{}] : []),
            ],
          },
        ],
      },
      select: ROW_SELECT,
      orderBy: { code: 'asc' },
      take: limit * 2,
    })) as Row[];

    const shortcutRank = new Map(shortcutCodes.map((c, i) => [c, i]));
    const lexicalRank = new Map(lexical.map((c, i) => [c, i]));
    const scored = rows
      .map((row) => {
        const isShortcut = shortcutRank.has(row.code);
        const tier = isShortcut
          ? 0
          : row.code === digits
            ? 1
            : lexicalRank.has(row.code)
              ? 2
              : 3;
        const within = isShortcut
          ? shortcutRank.get(row.code)!
          : (lexicalRank.get(row.code) ?? 0);
        return { row, tier, within, isShortcut };
      })
      .sort((a, b) => a.tier - b.tier || a.within - b.within || a.row.code.localeCompare(b.row.code))
      .slice(0, limit);

    return this.shape(
      scored.map(({ row, isShortcut }) => ({ row, isShortcut })),
      locale,
    );
  }

  async describeCodes(
    codes: string[],
    locale: HsnLocale = 'en',
    opts: { shortcutCodes?: Set<string>; asOf?: Date } = {},
  ): Promise<HsnSearchResult[]> {
    const unique = [...new Set(codes.map(normalizeHsn).filter(Boolean))];
    if (unique.length === 0) return [];
    const rows = (await prisma.hsnCode.findMany({
      where: {
        AND: [
          inForceOn(opts.asOf ?? new Date()),
          { shopId: null },
          { isRatable: true },
          { code: { in: unique } },
        ],
      },
      select: ROW_SELECT,
    })) as Row[];
    const byCode = new Map(rows.map((r) => [r.code, r]));
    const ordered = unique
      .map((code) => byCode.get(code))
      .filter((r): r is Row => r !== undefined)
      .map((row) => ({ row, isShortcut: opts.shortcutCodes?.has(row.code) ?? false }));
    return this.shape(ordered, locale);
  }

  private async shape(
    items: Array<{ row: Row; isShortcut: boolean }>,
    locale: HsnLocale,
  ): Promise<HsnSearchResult[]> {
    if (items.length === 0) return [];
    const extraCodes = new Set<string>();
    for (const { row } of items) {
      for (const c of codeLadder(row.code)) extraCodes.add(c);
      for (const c of Object.keys(copyFor(row.code, locale)?.notHere ?? {})) extraCodes.add(c);
    }
    const known = await prisma.hsnCode.findMany({
      where: { shopId: null, code: { in: [...extraCodes] } },
      select: { code: true, description: true },
    });
    const nameOf = new Map(known.map((a) => [a.code, a.description]));

    return items.map(({ row, isShortcut }) => {
      const copy = copyFor(row.code, locale);
      const rule = parseRule(row.rateRule);
      return {
        code: row.code,
        kind: row.kind,
        name: copy?.name ?? row.description,
        definition: copy?.definition ?? null,
        gstRate: Number(row.gstRate),
        cessRate: Number(row.cessRate),
        rateNote: row.rateNote,
        rule: rule
          ? { threshold: rule.threshold, atOrBelow: rule.atOrBelow, above: rule.above, per: rule.per }
          : null,
        breadcrumb: codeLadder(row.code)
          .filter((c) => c !== row.code && nameOf.has(c))
          .sort((a, b) => a.length - b.length)
          .map((c) => ({ code: c, name: displayName(c, nameOf.get(c)!, locale) })),
        notHere: Object.entries(copy?.notHere ?? {}).map(([c, label]) => ({
          code: c,
          name: label,
        })),
        fromShortcut: isShortcut,
      };
    });
  }

  async resolveMany(params: {
    codes: string[];
    shopId?: number;
    price?: number;
    asOf?: Date;
  }): Promise<Map<string, HsnRateResolution>> {
    const unique = [
      ...new Set(params.codes.map(normalizeHsn).filter((c) => c.length >= MIN_CODE_LENGTH)),
    ];
    const out = new Map<string, HsnRateResolution>();
    for (const code of unique) {
      const hit = await this.resolveRate({
        code,
        shopId: params.shopId,
        price: params.price,
        asOf: params.asOf,
      });
      if (hit) out.set(code, hit);
    }
    return out;
  }

  async listShortcuts(shopId: number, locale: HsnLocale = 'en') {
    const rows = await prisma.shopHsnShortcut.findMany({
      where: { shopId },
      orderBy: [{ useCount: 'desc' }, { lastUsedAt: 'desc' }],
      select: { id: true, label: true, code: true, useCount: true, lastUsedAt: true },
    });
    if (rows.length === 0) return [];
    const codes = [...new Set(rows.map((r) => r.code))];
    const live = (await prisma.hsnCode.findMany({
      where: { AND: [inForceOn(new Date()), { shopId: null }, { code: { in: codes } }] },
      select: { code: true, description: true, gstRate: true },
    })) as Array<{ code: string; description: string; gstRate: Prisma.Decimal }>;
    const byCode = new Map(live.map((r) => [r.code, r]));
    return rows.map((r) => {
      const hit = byCode.get(r.code);
      return {
        id: r.id,
        label: r.label,
        code: r.code,
        name: hit ? displayName(r.code, hit.description, locale) : null,
        gstRate: hit ? Number(hit.gstRate) : null,
        useCount: r.useCount,
        lastUsedAt: r.lastUsedAt,
        needsAttention: !hit,
      };
    });
  }

  async saveShortcut(shopId: number, label: string, code: string) {
    const term = normalizeTerm(label);
    const normalized = normalizeHsn(code);
    if (!term || normalized.length < MIN_CODE_LENGTH) return null;
    return prisma.shopHsnShortcut.upsert({
      where: { shopId_term: { shopId, term } },
      create: { shopId, term, label: label.trim(), code: normalized, useCount: 1 },
      update: { label: label.trim(), code: normalized, lastUsedAt: new Date() },
      select: { id: true, label: true, code: true },
    });
  }

  async deleteShortcut(shopId: number, id: number): Promise<boolean> {
    const { count } = await prisma.shopHsnShortcut.deleteMany({ where: { id, shopId } });
    return count > 0;
  }

  async touchShortcut(shopId: number, code: string): Promise<void> {
    await prisma.shopHsnShortcut
      .updateMany({
        where: { shopId, code: normalizeHsn(code) },
        data: { useCount: { increment: 1 }, lastUsedAt: new Date() },
      })
      .catch(() => undefined);
  }

  async listOverrides(shopId: number) {
    return prisma.shopHsnOverride.findMany({
      where: { shopId, isActive: true },
      orderBy: [{ code: 'asc' }, { effectiveFrom: 'desc' }],
      select: {
        id: true,
        code: true,
        gstRate: true,
        cessRate: true,
        reason: true,
        effectiveFrom: true,
        effectiveTo: true,
        createdAt: true,
      },
    });
  }

  async createOverride(params: {
    shopId: number;
    code: string;
    gstRate: number;
    cessRate?: number;
    reason: string;
    effectiveFrom?: Date;
    createdByUserId?: number;
  }) {
    const code = normalizeHsn(params.code);
    if (code.length < MIN_CODE_LENGTH) return null;
    const effectiveFrom = startOfDay(params.effectiveFrom ?? new Date());
    return prisma.shopHsnOverride.upsert({
      where: { shopId_code_effectiveFrom: { shopId: params.shopId, code, effectiveFrom } },
      create: {
        shopId: params.shopId,
        code,
        gstRate: params.gstRate,
        cessRate: params.cessRate ?? 0,
        reason: params.reason.trim(),
        effectiveFrom,
        createdByUserId: params.createdByUserId,
      },
      update: {
        gstRate: params.gstRate,
        cessRate: params.cessRate ?? 0,
        reason: params.reason.trim(),
        isActive: true,
      },
      select: { id: true, code: true, gstRate: true, cessRate: true, reason: true },
    });
  }

  async deleteOverride(shopId: number, id: number): Promise<boolean> {
    const { count } = await prisma.shopHsnOverride.updateMany({
      where: { id, shopId },
      data: { isActive: false, effectiveTo: startOfDay(new Date()) },
    });
    return count > 0;
  }
}

export const hsnService = new HsnService();
