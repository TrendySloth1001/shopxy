import fs from 'node:fs';
import path from 'node:path';
import prisma from '../../infra/db/prisma.js';
import { cached } from '../../shared/cache/cached.js';
import { logger } from '../../shared/logging/logger.js';
import { embeddingService } from '../search/embedding.service.js';
import { copyFor, matchAliasesInText, normalizeTerm, searchCopy, type HsnLocale } from './hsn.copy.js';
import { retrieve } from './hsn.retrieval.js';
import {
  codeLadder,
  hsnService,
  normalizeHsn,
  type HsnSearchResult,
  type UnratedReason,
} from './hsn.service.js';

export type SuggestionRateStatus = 'RESOLVED' | UnratedReason;

export type ClassifySuggestion = Omit<HsnSearchResult, 'gstRate' | 'cessRate'> & {
  via: 'SHORTCUT' | 'ALIAS' | 'TEXT' | 'TARIFF' | 'SEMANTIC';
  rateStatus: SuggestionRateStatus;
  gstRate: number | null;
  cessRate: number | null;
};

export type ClassifyResult = {
  query: string;
  suggestions: ClassifySuggestion[];
  usedEmbeddings: boolean;
};

const SEMANTIC_FLOOR = 1;

function semanticEnabled(): boolean {
  return process.env.HSN_SEMANTIC === '1';
}

const VECTORS_PATH = path.join(__dirname, 'copy', 'hsn.vectors.json');

type VectorFile = { model: string; dim: number; vectors: Record<string, number[]> };

let vectorsLoaded = false;
let vectors: Map<string, Float32Array> | null = null;

function loadVectors(): Map<string, Float32Array> | null {
  if (vectorsLoaded) return vectors;
  vectorsLoaded = true;
  try {
    const raw = JSON.parse(fs.readFileSync(VECTORS_PATH, 'utf8')) as VectorFile;
    const map = new Map<string, Float32Array>();
    for (const [code, values] of Object.entries(raw.vectors)) {
      map.set(code, Float32Array.from(values));
    }
    vectors = map;
    logger.info({ codes: map.size, model: raw.model, dim: raw.dim }, 'hsn: code vectors loaded');
  } catch {
    vectors = null;
    logger.info('hsn: no code vectors on disk; semantic suggestions disabled');
  }
  return vectors;
}

function dot(a: Float32Array, b: Float32Array): number {
  let sum = 0;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) sum += a[i] * b[i];
  return sum;
}

export class ClassifyService {
  async suggestForName(params: {
    name: string;
    shopId?: number;
    locale?: HsnLocale;
    limit?: number;
  }): Promise<ClassifyResult> {
    const query = params.name.trim();
    const locale = params.locale ?? 'en';
    const limit = Math.min(Math.max(params.limit ?? 6, 1), 20);
    if (!query) return { query, suggestions: [], usedEmbeddings: false };

    const via = new Map<string, ClassifySuggestion['via']>();
    const ordered: string[] = [];
    const push = (code: string, source: ClassifySuggestion['via']) => {
      const c = normalizeHsn(code);
      if (!c || via.has(c)) return;
      via.set(c, source);
      ordered.push(c);
    };

    const shortcutCodes = new Set<string>();
    if (params.shopId !== undefined) {
      for (const code of await this.matchShortcuts(params.shopId, query)) {
        shortcutCodes.add(code);
        push(code, 'SHORTCUT');
      }
    }

    for (const code of matchAliasesInText(query, limit)) push(code, 'ALIAS');
    for (const code of searchCopy(query, limit)) push(code, 'ALIAS');

    for (const hit of retrieve(query, limit)) {
      push(hit.code, hit.layer === 'TARIFF' ? 'TARIFF' : 'TEXT');
    }

    let usedEmbeddings = false;
    if (
      semanticEnabled() &&
      ordered.length < SEMANTIC_FLOOR &&
      embeddingService.isEnabled &&
      loadVectors()
    ) {
      const semantic = await this.semanticCodes(query, limit);
      usedEmbeddings = semantic.length > 0;
      for (const code of semantic) push(code, 'SEMANTIC');
    }

    if (ordered.length === 0 && params.shopId !== undefined) {
      void this.recordMiss(params.shopId, query);
    }

    const wanted = ordered.slice(0, limit);
    const described = await this.describe(wanted, locale, shortcutCodes);
    return {
      query,
      suggestions: described.map((d) => ({ ...d, via: via.get(d.code) ?? 'ALIAS' })),
      usedEmbeddings,
    };
  }

  private async describe(
    codes: string[],
    locale: HsnLocale,
    shortcutCodes: Set<string>,
  ): Promise<Array<Omit<ClassifySuggestion, 'via'>>> {
    if (codes.length === 0) return [];
    const rated = await hsnService.describeCodes(codes, locale, { shortcutCodes });
    const byCode = new Map<string, Omit<ClassifySuggestion, 'via'>>(
      rated.map((r) => [r.code, { ...r, rateStatus: 'RESOLVED' as const }]),
    );
    const missing = codes.filter((c) => !byCode.has(c));
    for (const row of await this.describeWithoutOwnRate(missing, locale, shortcutCodes)) {
      byCode.set(row.code, row);
    }

    return codes.flatMap((code) => {
      const hit = byCode.get(code);
      return hit ? [hit] : [];
    });
  }

  private async describeWithoutOwnRate(
    codes: string[],
    locale: HsnLocale,
    shortcutCodes: Set<string>,
  ): Promise<Array<Omit<ClassifySuggestion, 'via'>>> {
    if (codes.length === 0) return [];
    const wanted = new Set<string>();
    for (const code of codes) for (const c of codeLadder(code)) wanted.add(c);

    const [rows, outcomes] = await Promise.all([
      prisma.hsnCode.findMany({
        where: { shopId: null, code: { in: [...wanted] } },
        select: { code: true, kind: true, description: true },
      }),
      Promise.all(codes.map((code) => hsnService.resolveOutcome({ code }))),
    ]);
    const known = new Map(rows.map((r) => [r.code, r]));

    const out: Array<Omit<ClassifySuggestion, 'via'>> = [];
    for (let i = 0; i < codes.length; i++) {
      const code = codes[i];
      const row = known.get(code);
      const outcome = outcomes[i];
      if (!row || outcome.status === 'UNKNOWN') continue;
      const copy = copyFor(code, locale);
      const resolved = outcome.status === 'RESOLVED' ? outcome.rate : null;
      const unrated = outcome.status === 'UNRATED' ? outcome : null;
      out.push({
        code,
        kind: row.kind,
        name: copy?.name ?? row.description,
        definition: copy?.definition ?? null,
        gstRate: resolved ? resolved.gstRate : null,
        cessRate: resolved ? resolved.cessRate : null,
        rateStatus: unrated ? unrated.reason : 'RESOLVED',
        rateNote: unrated ? unrated.note : (resolved?.rateNote ?? null),
        rule: resolved?.rule
          ? {
              threshold: resolved.rule.threshold,
              atOrBelow: resolved.rule.atOrBelow,
              above: resolved.rule.above,
              per: resolved.rule.per,
            }
          : null,
        breadcrumb: codeLadder(code)
          .filter((c) => c !== code && known.has(c))
          .sort((a, b) => a.length - b.length)
          .map((c) => ({ code: c, name: copyFor(c, locale)?.name ?? known.get(c)!.description })),
        notHere: Object.entries(copy?.notHere ?? {}).map(([c, label]) => ({ code: c, name: label })),
        fromShortcut: shortcutCodes.has(code),
      });
    }
    return out;
  }

  private static readonly MIN_MISS_LENGTH = 3;

  private async recordMiss(shopId: number, query: string): Promise<void> {
    const term = normalizeTerm(query);
    if (term.length < ClassifyService.MIN_MISS_LENGTH) return;
    try {
      await prisma.hsnLookupMiss.upsert({
        where: { shopId_term: { shopId, term } },
        create: { shopId, term, sample: query.slice(0, 300) },
        update: {
          occurrences: { increment: 1 },
          lastSeenAt: new Date(),
          resolvedCode: null,
          resolvedAt: null,
        },
      });
    } catch (e) {
      logger.debug({ err: (e as Error).message }, 'hsn: could not record lookup miss');
    }
  }

  async outstandingGaps(limit = 100): Promise<
    Array<{ term: string; sample: string; occurrences: number; shops: number }>
  > {
    const rows = await prisma.hsnLookupMiss.groupBy({
      by: ['term'],
      where: { resolvedCode: null },
      _sum: { occurrences: true },
      _count: { shopId: true },
      _max: { lastSeenAt: true },
      orderBy: { _sum: { occurrences: 'desc' } },
      take: Math.min(Math.max(limit, 1), 500),
    });
    if (rows.length === 0) return [];
    const samples = await prisma.hsnLookupMiss.findMany({
      where: { term: { in: rows.map((r) => r.term) }, resolvedCode: null },
      distinct: ['term'],
      select: { term: true, sample: true },
    });
    const sampleOf = new Map(samples.map((s) => [s.term, s.sample]));
    return rows.map((r) => ({
      term: r.term,
      sample: sampleOf.get(r.term) ?? r.term,
      occurrences: r._sum.occurrences ?? 0,
      shops: r._count.shopId,
    }));
  }

  async resolveGap(term: string, code: string): Promise<number> {
    const normalized = normalizeTerm(term);
    if (!normalized) return 0;
    const { count } = await prisma.hsnLookupMiss.updateMany({
      where: { term: normalized, resolvedCode: null },
      data: { resolvedCode: normalizeHsn(code), resolvedAt: new Date() },
    });
    return count;
  }

  private async matchShortcuts(shopId: number, query: string): Promise<string[]> {
    const term = normalizeTerm(query);
    if (!term) return [];
    const rows = await prisma.shopHsnShortcut.findMany({
      where: { shopId },
      orderBy: [{ useCount: 'desc' }, { lastUsedAt: 'desc' }],
      take: 200,
      select: { code: true, term: true },
    });
    const hits: string[] = [];
    for (const row of rows) {
      if (!row.term) continue;
      if (term === row.term || term.includes(row.term) || row.term.includes(term)) {
        hits.push(row.code);
      }
      if (hits.length >= 3) break;
    }
    return hits;
  }

  private async semanticCodes(query: string, limit: number): Promise<string[]> {
    const table = loadVectors();
    if (!table) return [];
    try {
      const key = `hsn:qvec:${embeddingService.providerName}:${normalizeTerm(query)}`;
      const values = await cached<number[] | null>(key, 60 * 60 * 24 * 30, async () => {
        const batch = await embeddingService.embedBatch([query]);
        return batch?.[0] ?? null;
      });
      if (!values || values.length === 0) return [];
      const q = Float32Array.from(values);

      const scored: Array<{ code: string; score: number }> = [];
      for (const [code, vec] of table) scored.push({ code, score: dot(q, vec) });
      scored.sort((a, b) => b.score - a.score);
      return scored
        .filter((s) => s.score >= 0.5)
        .slice(0, limit)
        .map((s) => s.code);
    } catch (e) {
      logger.warn({ err: (e as Error).message }, 'hsn: semantic suggestion failed; lexical only');
      return [];
    }
  }
}

export const classifyService = new ClassifyService();
