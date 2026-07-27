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

/// The read side of the HSN/SAC master.
///
/// Two questions, and they are deliberately separate steps:
///
///   1. **"What code is this product?"** — the merchant's own shortcuts first,
///      then the shared vocabulary. Classification is theirs to decide.
///   2. **"What rate does that code bill at?"** — their explicit overrides
///      first, then the shared master. Rates are the government's to decide.
///
/// Keeping them apart is what lets a merchant's saved shortcut list stay
/// permanently correct: it holds no rate, so a Council revision reaches them
/// automatically and there is nothing of theirs for us to silently rewrite.

/// Shortest real HSN heading — below this, a lookup is noise rather than a code.
export const MIN_CODE_LENGTH = 4;

export type RateSource = 'HSN' | 'HSN_RULE' | 'OVERRIDE';

export type AppliedRule = {
  threshold: number;
  atOrBelow: number;
  above: number;
  per: HsnRateRule['per'];
  /// The price the threshold was tested against. Null when no price was
  /// supplied — the rule is then reported but not applied, and the caller
  /// shows it as a condition rather than a decision.
  testedPrice: number | null;
};

export type HsnRateResolution = {
  /// What was asked for, normalised to digits.
  requestedCode: string;
  /// The code the rate actually came from. Equal to `requestedCode` on a
  /// direct hit; a shorter heading when we don't carry the exact tariff item.
  code: string;
  exact: boolean;
  gstRate: number;
  cessRate: number;
  source: RateSource;
  /// Which revision of the master produced this. Stamped onto the product and
  /// onto every invoice line, so "exactly which documents used the rate that
  /// turned out to be wrong" is a query with an exact answer.
  revision: string;
  /// Advisory caveat for conditions we can't evaluate (packaging, engine size).
  rateNote: string | null;
  /// The price rule, if the code has one — whether or not it could be applied.
  rule: AppliedRule | null;
};

export type HsnNode = { code: string; name: string };

export type HsnSearchResult = {
  code: string;
  kind: 'GOODS' | 'SERVICES';
  /// Plain-language label from the copy catalogue, falling back to the
  /// official tariff wording.
  name: string;
  definition: string | null;
  gstRate: number;
  cessRate: number;
  rateNote: string | null;
  rule: Omit<AppliedRule, 'testedPrice'> | null;
  /// Chapter → heading → sub-heading, ending at this code. Shown in the picker
  /// because the four-digit code alone can't tell a merchant that 62 is woven
  /// and 61 is knitted — which is the single most common apparel error.
  breadcrumb: HsnNode[];
  /// "Not this? try these" cross-references, from the copy catalogue.
  notHere: HsnNode[];
  /// True when this came from the merchant's own saved shortcuts.
  fromShortcut: boolean;
};

/// HSN/SAC codes are digits only; merchants paste them with spaces and dots.
export function normalizeHsn(raw: string): string {
  return raw.replace(/\D/g, '');
}

function startOfDay(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

function revisionOf(effectiveFrom: Date): string {
  return effectiveFrom.toISOString().slice(0, 10);
}

/// The prefix ladder for a code: itself, then progressively shorter ancestors
/// down to the two-digit chapter. `62052000` → `62052000, 620520, 6205, 62`.
export function codeLadder(code: string): string[] {
  const out: string[] = [];
  if (code.length >= MIN_CODE_LENGTH) out.push(code);
  for (const len of [8, 6, 4, 2]) {
    if (code.length <= len) continue;
    const slice = code.slice(0, len);
    if (!out.includes(slice)) out.push(slice);
  }
  // A 4-digit input still wants its chapter for the breadcrumb.
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

/// Narrow the stored JSON to a rule we can actually evaluate. Anything that
/// doesn't match the shape is treated as absent rather than trusted — a
/// malformed rule must never silently produce a rate.
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

/// Merchant-facing label for a code, preferring curated copy over tariff prose.
function displayName(code: string, fallback: string, locale: HsnLocale): string {
  return copyFor(code, locale)?.name ?? fallback;
}

export class HsnService {
  /// Rate for a code. Null when nothing matches at any prefix length — callers
  /// must surface that rather than defaulting to 0%, because a silent zero is
  /// an under-charged invoice.
  ///
  /// `price` is the per-unit amount the threshold rules test against. Pass the
  /// **line price at billing time**, not the product's list price: a shirt
  /// listed at ₹2,400 and sold at ₹2,600 is 18%, and a rate frozen at save
  /// time would get that wrong.
  async resolveRate(params: {
    code: string;
    shopId?: number;
    price?: number;
    asOf?: Date;
  }): Promise<HsnRateResolution | null> {
    const requestedCode = normalizeHsn(params.code);
    if (requestedCode.length < MIN_CODE_LENGTH) return null;
    const asOf = params.asOf ?? new Date();
    const day = startOfDay(asOf);
    const ladder = codeLadder(requestedCode);

    // ── Tier 1: the shop's own override ────────────────────────────────────
    // Checked on the exact code only. An override is a stated position about
    // one classification; inheriting it down a prefix would silently extend a
    // ruling to goods it was never granted for.
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
          requestedCode,
          code: override.code,
          exact: true,
          gstRate: Number(override.gstRate),
          cessRate: Number(override.cessRate),
          source: 'OVERRIDE',
          revision: revisionOf(override.effectiveFrom),
          rateNote: override.reason,
          rule: null,
        };
      }
    }

    // ── Tier 2: the shared master ──────────────────────────────────────────
    // Ratable rows only: chapters exist for the breadcrumb and have no rate of
    // their own, so matching one would invent a slab.
    const rows = (await prisma.hsnCode.findMany({
      where: {
        AND: [inForceOn(asOf), { shopId: null }, { isRatable: true }, { code: { in: ladder } }],
      },
      select: ROW_SELECT,
    })) as Row[];
    if (rows.length === 0) return null;

    // Longest matching code wins — heading 2202 (aerated drinks, 40%) must
    // never beat sub-heading 220299 (juice drinks, 5%).
    let best = rows[0];
    for (const row of rows) {
      if (row.code.length > best.code.length) best = row;
      else if (row.code.length === best.code.length && row.effectiveFrom > best.effectiveFrom) {
        best = row;
      }
    }

    const rule = parseRule(best.rateRule);
    let gstRate = Number(best.gstRate);
    let source: RateSource = 'HSN';
    let applied: AppliedRule | null = null;

    if (rule) {
      const testedPrice = typeof params.price === 'number' && Number.isFinite(params.price)
        ? params.price
        : null;
      applied = { ...rule, testedPrice };
      if (testedPrice !== null) {
        // "of sale value not exceeding ₹2,500 per piece" — the boundary is
        // inclusive, and it lands on real SKU prices, so ≤ not <.
        gstRate = testedPrice <= rule.threshold ? rule.atOrBelow : rule.above;
        source = 'HSN_RULE';
      }
    }

    return {
      requestedCode,
      code: best.code,
      exact: best.code === requestedCode,
      gstRate,
      cessRate: Number(best.cessRate),
      source,
      revision: revisionOf(best.effectiveFrom),
      rateNote: best.rateNote,
      rule: applied,
    };
  }

  /// Chapter → heading → … → this code, for the picker's breadcrumb. Includes
  /// the non-ratable navigation rows, which is the entire point: seeing
  /// "Chapter 62 — apparel, NOT knitted" above 6205 is what prevents the
  /// woven/knitted mistake.
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
    // Shortest first: chapter, then heading, then the leaf.
    return ladder
      .filter((c) => byCode.has(c))
      .sort((a, b) => a.length - b.length)
      .map((c) => ({ code: c, name: displayName(c, byCode.get(c)!, locale) }));
  }

  /// Type-ahead over the shared vocabulary plus the merchant's own shortcuts.
  ///
  /// Digits match on code prefix; anything else goes through the alias index,
  /// which is what makes "kameez", "chappal" and "sariya" work. Costs two
  /// queries regardless of result count: one for the shop's shortcuts, one for
  /// the rate rows behind every candidate code and its ancestors.
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

    // The merchant's own words come first — they are a better predictor of
    // what this merchant means than any shared dictionary.
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

    // Digits → code prefix; words → the alias index.
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
              // An empty query opens the picker on something useful instead of
              // nothing; the shortcuts above still lead.
              ...(q.length === 0 && candidateCodes.length === 0 ? [{}] : []),
            ],
          },
        ],
      },
      select: ROW_SELECT,
      orderBy: { code: 'asc' },
      take: limit * 2,
    })) as Row[];

    // Rank: the merchant's own shortcuts, then an exact code hit, then the
    // order the vocabulary suggested, then everything else by code.
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

  /// Hydrate a list of codes into full picker results — copy, rate, rule,
  /// breadcrumb, cross-references. Preserves the order it's given, because the
  /// caller's ranking is the meaningful one.
  ///
  /// Two queries total regardless of list length: one for the rate rows, one
  /// for every ancestor and cross-referenced code at once. Used by both the
  /// type-ahead and the name-based suggester so the two can't drift.
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

  /// Shared final step for [search] and [describeCodes]: attach breadcrumbs and
  /// cross-references in one round trip, then map to the wire shape.
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
        // Ancestors only, shortest first — the leaf is the row itself.
        breadcrumb: codeLadder(row.code)
          .filter((c) => c !== row.code && nameOf.has(c))
          .sort((a, b) => a.length - b.length)
          .map((c) => ({ code: c, name: displayName(c, nameOf.get(c)!, locale) })),
        notHere: Object.entries(copy?.notHere ?? {}).map(([c, label]) => ({
          code: c,
          // The copy file's own label wins — it's written to be read in this
          // exact "not this? try that" context.
          name: label,
        })),
        fromShortcut: isShortcut,
      };
    });
  }

  /// Bulk rate lookup for a write path that carries several codes at once.
  /// Sequential rather than parallel: a product has a handful of distinct
  /// codes at most, and this keeps the connection pool free during a write.
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

  // ── The merchant's own shortcut list ─────────────────────────────────────

  async listShortcuts(shopId: number, locale: HsnLocale = 'en') {
    const rows = await prisma.shopHsnShortcut.findMany({
      where: { shopId },
      orderBy: [{ useCount: 'desc' }, { lastUsedAt: 'desc' }],
      select: { id: true, label: true, code: true, useCount: true, lastUsedAt: true },
    });
    if (rows.length === 0) return [];
    // Join the current rate on at read time — never stored, so a Council
    // revision reaches this list without anyone touching the merchant's data.
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
        /// True when the saved code no longer resolves — a WCO revision retired
        /// or split it. The merchant has to choose the successor; we must not.
        needsAttention: !hit,
      };
    });
  }

  /// Save (or re-point) a shortcut. Keyed on the merchant's own normalised
  /// wording, so saving "Formal Shirt" twice updates rather than duplicates.
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

  /// Bump usage so the picker leads with what this merchant actually reaches
  /// for. Best-effort: a failure here must never fail the product save.
  async touchShortcut(shopId: number, code: string): Promise<void> {
    await prisma.shopHsnShortcut
      .updateMany({
        where: { shopId, code: normalizeHsn(code) },
        data: { useCount: { increment: 1 }, lastUsedAt: new Date() },
      })
      .catch(() => undefined);
  }

  // ── Explicit rate overrides ──────────────────────────────────────────────

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

  /// Record a rate override. Deliberately heavier than saving a shortcut: a
  /// reason is required, because an override without a stated basis can't be
  /// told apart from a typo, and this is the field an auditor asks about.
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
    // Soft: an override that was in force when documents were raised stays on
    // the record, it just stops applying to new ones.
    const { count } = await prisma.shopHsnOverride.updateMany({
      where: { id, shopId },
      data: { isActive: false, effectiveTo: startOfDay(new Date()) },
    });
    return count > 0;
  }
}

export const hsnService = new HsnService();
