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

/// "The merchant typed a product name — what is this thing?"
///
/// Three layers, cheapest first, and the order is deliberate:
///
///   1. **The merchant's own shortcuts.** What *this* shop has already
///      classified is a better predictor than any shared dictionary.
///   2. **The shared alias index.** In memory, no network, no cost. Covers the
///      queries that actually happen — "kameez", "chappal", "sariya" — because
///      hand-written aliases beat embeddings on trade vocabulary and spelling
///      variants, which is most of what Indian merchants type.
///   3. **Semantic search**, only when the first two came up thin. This is the
///      one that costs money and latency, so it is the fallback, not the path.
///
/// Every layer degrades to the one above it. No embedding key, no vectors file,
/// no network — the suggester still works, just with less reach on the tail.

/// Whether a suggested code can price a line, and if not, why not.
///
/// Mirrors [HsnRateOutcome]. It rides on the suggestion because the alternative
/// — hiding every code that can't decide its own rate — is what made rice
/// unfindable: heading 1006 is nil loose and 5% pre-packaged, so it carries no
/// single rate, and a kirana merchant searching "chawal" got nothing at all.
///
///   - `RESOLVED` — [gstRate] is the master's answer, directly or inherited.
///   - `CONDITIONAL` — the schedule splits this code by a condition no column
///     holds. [rateNote] is the condition in the schedule's own words.
///   - `NO_RATE_ON_FILE` — the code is real and nothing on its ladder is rated.
///
/// For the last two [gstRate] is **null**, never 0. A code that cannot decide
/// its rate is the merchant's question to answer, and a zero we made up would
/// be an under-charged invoice they never got asked about.
export type SuggestionRateStatus = 'RESOLVED' | UnratedReason;

export type ClassifySuggestion = Omit<HsnSearchResult, 'gstRate' | 'cessRate'> & {
  /// Which layer produced this, so the UI can say "you saved this" versus
  /// "we think this fits" — a saved shortcut deserves more confidence than a
  /// text match, and far more than a semantic guess.
  ///
  /// `TARIFF` is a match on the official tariff description rather than on
  /// vocabulary anyone reviewed: right code, wording written for a customs
  /// officer. Worth showing more cautiously than `TEXT`.
  via: 'SHORTCUT' | 'ALIAS' | 'TEXT' | 'TARIFF' | 'SEMANTIC';
  rateStatus: SuggestionRateStatus;
  /// Null exactly when [rateStatus] is not `RESOLVED`.
  gstRate: number | null;
  cessRate: number | null;
};

export type ClassifyResult = {
  query: string;
  suggestions: ClassifySuggestion[];
  /// True when semantic search ran. Useful for cost tracing.
  usedEmbeddings: boolean;
};

/// Fire the paid semantic lookup only when everything above found **nothing**.
const SEMANTIC_FLOOR = 1;

/// Embeddings are opt-in. The lexical stack answers the overwhelming majority
/// of real product names on its own, deterministically and for free; turning
/// this on trades quota and latency for a slice of the paraphrase tail.
/// Requires `HSN_SEMANTIC=1` *and* a key *and* a generated vectors file.
function semanticEnabled(): boolean {
  return process.env.HSN_SEMANTIC === '1';
}

const VECTORS_PATH = path.join(__dirname, 'copy', 'hsn.vectors.json');

type VectorFile = { model: string; dim: number; vectors: Record<string, number[]> };

let vectorsLoaded = false;
let vectors: Map<string, Float32Array> | null = null;

/// Precomputed code vectors, generated offline by `npm run hsn:embed` and
/// checked in. Loading a file beats embedding 100+ codes on every boot, and
/// beats a vector database by roughly the entire complexity of a vector
/// database — at this size, brute-force cosine over a typed array is
/// sub-millisecond.
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
    // Absent by default — the file only exists once someone has run the
    // generator with an embedding key configured. Not an error.
    vectors = null;
    logger.info('hsn: no code vectors on disk; semantic suggestions disabled');
  }
  return vectors;
}

/// Vectors from both sides are unit-normalised by the provider, so cosine
/// similarity is just the dot product.
function dot(a: Float32Array, b: Float32Array): number {
  let sum = 0;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) sum += a[i] * b[i];
  return sum;
}

export class ClassifyService {
  /// Suggest HSN/SAC codes for a product name.
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

    // ── 1. The merchant's own shortcuts ──────────────────────────────────
    const shortcutCodes = new Set<string>();
    if (params.shopId !== undefined) {
      for (const code of await this.matchShortcuts(params.shopId, query)) {
        shortcutCodes.add(code);
        push(code, 'SHORTCUT');
      }
    }

    // ── 2. Exact alias phrases ───────────────────────────────────────────
    // The longest alias contained *in* the name. This is the strongest signal
    // there is: "sarson ka tel 1L" contains "sarson ka tel", and "mens t shirt"
    // contains "t shirt" — which no amount of word-level ranking recovers,
    // because "t" is a single character and drops out of any tokeniser.
    for (const code of matchAliasesInText(query, limit)) push(code, 'ALIAS');
    // Also the whole name as a prefix, for a merchant who typed something
    // shorter than the alias ("sham" → "shampoo").
    for (const code of searchCopy(query, limit)) push(code, 'ALIAS');

    // ── 3. BM25 over the curated copy, then the official tariff ──────────
    // The workhorse. Rare words dominate, common ones are ignored, and the
    // definitions we already wrote finally get searched — "stuff to wash
    // dishes with" lands on detergent because `dishwash` is in 3402's text,
    // with no model and no network. Underneath it, every one of the ~7,000
    // imported tariff descriptions: "keyboard" and "pneumatic tyres" appear
    // nowhere in the 101 curated entries and everywhere in the schedule.
    for (const hit of retrieve(query, limit)) {
      push(hit.code, hit.layer === 'TARIFF' ? 'TARIFF' : 'TEXT');
    }

    // ── 4. Semantic — off by default ─────────────────────────────────────
    // Everything above is deterministic, offline and free. Embeddings only
    // add true paraphrase with no shared vocabulary ("thing you fry pakoras
    // in" → oil), which is a small tail and is equally curable by adding the
    // word as an alias. Enable deliberately once the quota is worth spending.
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

    // ── Nothing fitted ───────────────────────────────────────────────────
    // The one thing worth writing down. Retrieval is capped by the vocabulary
    // it searches, and guessing at what that vocabulary lacks produces aliases
    // nobody searches for. What merchants type and don't find is the real
    // backlog — and each entry is curable once, for free, forever.
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

  /// Hydrate ranked codes into suggestions, **including the ones that carry no
  /// rate**.
  ///
  /// [HsnService.describeCodes] answers only for `isRatable` rows, which is
  /// right for a picker that must not offer an unbillable code — and wrong
  /// here. Two thirds of the curated catalogue's own headings are non-ratable:
  /// 1006 rice and 4820 notebooks because the schedule splits them by a
  /// condition, and 3305 shampoo, 9608 pens, 1905 biscuits, 4011 tyres, 9405
  /// lamps because their rate lives in sub-headings the import left unrated.
  /// Filtering them out is what made a kirana merchant's entire shelf
  /// unsearchable.
  ///
  /// So: take what `describeCodes` gives, and fill the gaps from
  /// [HsnService.resolveOutcome] — which is the one function that can tell
  /// "inherits 5% from its parent heading" from "the law needs you to answer a
  /// question first". Order is the caller's throughout; the ranking is theirs.
  private async describe(
    codes: string[],
    locale: HsnLocale,
    shortcutCodes: Set<string>,
  ): Promise<Array<Omit<ClassifySuggestion, 'via'>>> {
    if (codes.length === 0) return [];
    const rated = await hsnService.describeCodes(codes, locale, { shortcutCodes });
    const byCode = new Map<string, Omit<ClassifySuggestion, 'via'>>(
      // A row `describeCodes` returned at all is a row with a rate of its own.
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

  /// Suggestions for codes with no rate row of their own.
  ///
  /// Costs one query for the descriptions of every code and ancestor at once,
  /// plus one outcome walk per code — and only ever runs for the handful
  /// `describeCodes` couldn't answer.
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
      // Nothing in the master at heading level or deeper: we have no name for
      // it and no rate, so there is nothing honest to show.
      if (!row || outcome.status === 'UNKNOWN') continue;
      const copy = copyFor(code, locale);
      const resolved = outcome.status === 'RESOLVED' ? outcome.rate : null;
      const unrated = outcome.status === 'UNRATED' ? outcome : null;
      out.push({
        code,
        kind: row.kind,
        name: copy?.name ?? row.description,
        definition: copy?.definition ?? null,
        // The master's own number when the ladder could decide one, and null
        // when it could not. Never a stand-in zero.
        gstRate: resolved ? resolved.gstRate : null,
        cessRate: resolved ? resolved.cessRate : null,
        rateStatus: unrated ? unrated.reason : 'RESOLVED',
        // The condition in the schedule's own words — "Nil when sold
        // loose/unbranded; 5% when pre-packaged and labelled" is what lets the
        // merchant answer the question the code can't.
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

  /// Shortest string worth recording. One or two characters is someone
  /// mid-keystroke, not a gap in the catalogue.
  private static readonly MIN_MISS_LENGTH = 3;

  /// Note that this shop asked for something we couldn't place.
  ///
  /// Deliberately fire-and-forget and deliberately un-awaited by the caller:
  /// this runs on the typing path, and a suggester that fails — or even one
  /// that gets slower — because a *logging* write went wrong would be a bad
  /// trade for a curation nicety. Every failure is swallowed.
  ///
  /// Upsert on (shop, term) rather than insert: a merchant retyping a name
  /// they can't classify would otherwise write a row per keystroke and drown
  /// the signal we're collecting.
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
          // A term that recurs after being marked fixed is not fixed.
          resolvedCode: null,
          resolvedAt: null,
        },
      });
    } catch (e) {
      logger.debug({ err: (e as Error).message }, 'hsn: could not record lookup miss');
    }
  }

  /// The curation backlog: gaps nobody has closed, most-hit first.
  ///
  /// Aggregated across shops at read time, because a term twenty shops search
  /// for is worth an alias and one shop's private jargon usually isn't — but
  /// the rows stay attributed to the shop that produced them, since a product
  /// name is that merchant's business data, not the platform's.
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
    // One extra query for a readable sample per term, rather than dragging
    // `sample` through the group-by (which would split the aggregation).
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

  /// Mark a gap closed once an alias has been added for it. Idempotent, and
  /// re-opened automatically by [recordMiss] if the term is searched again —
  /// which is the only proof that the fix actually worked.
  async resolveGap(term: string, code: string): Promise<number> {
    const normalized = normalizeTerm(term);
    if (!normalized) return 0;
    const { count } = await prisma.hsnLookupMiss.updateMany({
      where: { term: normalized, resolvedCode: null },
      data: { resolvedCode: normalizeHsn(code), resolvedAt: new Date() },
    });
    return count;
  }

  /// Shortcuts whose saved wording overlaps the product name. Matched on the
  /// merchant's own terms, so "Formal Shirt → 6205" fires for
  /// "Blue Formal Shirt XL" without anyone having indexed that exact string.
  private async matchShortcuts(shopId: number, query: string): Promise<string[]> {
    const term = normalizeTerm(query);
    if (!term) return [];
    const rows = await prisma.shopHsnShortcut.findMany({
      where: { shopId },
      orderBy: [{ useCount: 'desc' }, { lastUsedAt: 'desc' }],
      // A shop's list is dozens of rows, so scanning it in memory is cheaper
      // and far more flexible than trying to express "term appears anywhere in
      // the name" in SQL.
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

  /// Embed the query once and rank the precomputed code vectors against it.
  ///
  /// The query embedding is cached for 30 days keyed on the normalised name:
  /// merchants add "blue cotton shirt" and "red cotton shirt" minutes apart,
  /// and there is no reason to pay for both. A failure degrades to no semantic
  /// results rather than failing the request — the merchant can still type a
  /// code by hand, and a suggester that 500s is worse than one that's quiet.
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

      // Brute force over ~100 (eventually ~12,000) vectors. At 768 dims that's
      // single-digit milliseconds worst case — an index would cost more in
      // complexity than it saves in time.
      const scored: Array<{ code: string; score: number }> = [];
      for (const [code, vec] of table) scored.push({ code, score: dot(q, vec) });
      scored.sort((a, b) => b.score - a.score);
      // A weak best match means the query isn't about anything we carry;
      // returning the least-bad row would be worse than returning nothing,
      // because the merchant would trust it.
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
