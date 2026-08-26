import fs from 'node:fs';
import path from 'node:path';
import { corpus, normalizeTerm } from './hsn.copy.js';
import { HSN_MASTER } from './hsn.master.js';
import { logger } from '../../shared/logging/logger.js';

const K1 = 1.5;
const B = 0.75;

const WEIGHT_ALIAS = 5;
const WEIGHT_NAME = 3;
const WEIGHT_DEFINITION = 1;

const STOPWORDS = new Set([
  'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'can', 'do', 'for', 'from',
  'has', 'have', 'i', 'in', 'is', 'it', 'its', 'me', 'my', 'of', 'on', 'or',
  'other', 'our', 'that', 'the', 'their', 'them', 'then', 'there', 'these',
  'they', 'this', 'to', 'up', 'use', 'used', 'using', 'was', 'we', 'what',
  'when', 'where', 'which', 'who', 'why', 'will', 'with', 'you', 'your',
  'thing', 'things', 'stuff', 'item', 'items', 'kind', 'type', 'sort',
  'ka', 'ke', 'ki', 'ko', 'se', 'aur', 'hai', 'wala', 'wali',
]);

const TARIFF_STOPWORDS = new Set([
  'not', 'than', 'no', 'nor', 'but', 'those', 'whether',
  'heading', 'headings', 'subheading', 'subheadings', 'chapter', 'chapters',
  'section', 'sections', 'elsewhere', 'specified', 'thereof', 'nec', 'nes',
]);

function stem(token: string): string {
  if (token.length <= 3) return token;
  if (!/^[a-z]+$/.test(token)) return token;
  if (token.endsWith('ies') && token.length > 4) return `${token.slice(0, -3)}y`;
  if (token.endsWith('sses')) return token.slice(0, -2);
  if (token.endsWith('shes') || token.endsWith('ches') || token.endsWith('xes')) {
    return token.slice(0, -2);
  }
  if (token.endsWith('ing') && token.length > 5) return token.slice(0, -3);
  if (token.endsWith('ed') && token.length > 4) return token.slice(0, -2);
  if (token.endsWith('s') && !token.endsWith('ss') && !token.endsWith('us')) {
    return token.slice(0, -1);
  }
  return token;
}

export function phoneticKey(raw: string): string {
  if (!/^[a-z]+$/.test(raw) || raw.length < 5) return '';
  let s = raw;
  s = s
    .replace(/ph/g, 'f')
    .replace(/ch/g, 'C')
    .replace(/sh/g, 'S')
    .replace(/th/g, 't')
    .replace(/dh/g, 'd')
    .replace(/bh/g, 'b')
    .replace(/gh/g, 'g')
    .replace(/kh/g, 'k')
    .replace(/jh/g, 'j');
  s = s
    .replace(/q/g, 'k')
    .replace(/c/g, 'k')
    .replace(/x/g, 'ks')
    .replace(/z/g, 'j')
    .replace(/w/g, 'v')
    .replace(/C/g, 'c')
    .replace(/S/g, 's');
  const head = s[0];
  s = head + s.slice(1).replace(/[aeiouy]/g, '');
  s = s.replace(/(.)\1+/g, '$1');
  return s;
}

function trigrams(token: string): Set<string> {
  const padded = `  ${token} `;
  const out = new Set<string>();
  for (let i = 0; i < padded.length - 2; i++) out.add(padded.slice(i, i + 3));
  return out;
}

function diceSimilarity(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let shared = 0;
  for (const g of a) if (b.has(g)) shared++;
  return (2 * shared) / (a.size + b.size);
}

function tokenizeWith(text: string, extra: ReadonlySet<string> | null): string[] {
  return normalizeTerm(text)
    .split(' ')
    .filter((t) => t.length > 1 && !STOPWORDS.has(t) && !extra?.has(t))
    .map(stem)
    .filter(Boolean);
}

export function tokenize(text: string): string[] {
  return tokenizeWith(text, null);
}

function tokenizeTariff(text: string): string[] {
  return tokenizeWith(text, TARIFF_STOPWORDS).filter((t) => !/^\d+$/.test(t));
}

export type RetrievalLayer = 'CURATED' | 'TARIFF';

type Posting = { code: string; freq: number };

type Index = {
  layer: RetrievalLayer;
  postings: Map<string, Posting[]>;
  df: Map<string, number>;
  docLen: Map<string, number>;
  avgDocLen: number;
  docCount: number;
  vocabulary: string[];
  vocabTrigrams: Map<string, Set<string>>;
  phonetic: Map<string, Set<string>>;
  repairs: boolean;
  minConfidentScore: number;
};

type SourceDoc = { code: string; terms: Map<string, number> };

function buildIndex(
  layer: RetrievalLayer,
  source: SourceDoc[],
  minConfidentScore: number,
  repairs: boolean,
): Index {
  const postings = new Map<string, Posting[]>();
  const df = new Map<string, number>();
  const docLen = new Map<string, number>();
  const phonetic = new Map<string, Set<string>>();

  for (const { code, terms } of source) {
    if (terms.size === 0) continue;
    let len = 0;
    for (const [term, freq] of terms) {
      len += freq;
      df.set(term, (df.get(term) ?? 0) + 1);
      let list = postings.get(term);
      if (!list) {
        list = [];
        postings.set(term, list);
      }
      list.push({ code, freq });
      if (!repairs) continue;
      const key = phoneticKey(term);
      if (key) {
        let set = phonetic.get(key);
        if (!set) {
          set = new Set();
          phonetic.set(key, set);
        }
        set.add(term);
      }
    }
    docLen.set(code, len);
  }

  const docCount = docLen.size;
  const avgDocLen =
    docCount === 0 ? 0 : [...docLen.values()].reduce((a, b) => a + b, 0) / docCount;
  const vocabulary = [...df.keys()];
  const vocabTrigrams = new Map(
    repairs ? vocabulary.map((t) => [t, trigrams(t)] as const) : [],
  );

  return {
    layer,
    postings,
    df,
    docLen,
    avgDocLen,
    docCount,
    vocabulary,
    vocabTrigrams,
    phonetic,
    repairs,
    minConfidentScore,
  };
}

function curatedDocs(): SourceDoc[] {
  const out: SourceDoc[] = [];
  for (const entry of corpus()) {
    const terms = new Map<string, number>();
    const add = (text: string, weight: number) => {
      for (const token of tokenize(text)) {
        terms.set(token, (terms.get(token) ?? 0) + weight);
      }
    };
    for (const n of entry.names) add(n, WEIGHT_NAME);
    for (const d of entry.definitions) add(d, WEIGHT_DEFINITION);
    for (const a of entry.aliases) add(a, WEIGHT_ALIAS);
    out.push({ code: entry.code, terms });
  }
  return out;
}

const MASTER_PATH = path.join(__dirname, 'data', 'hsn.master.json');

type MasterEntry = { code: string; description: string };

function masterEntries(): MasterEntry[] {
  try {
    const raw = JSON.parse(fs.readFileSync(MASTER_PATH, 'utf8')) as {
      entries?: MasterEntry[];
    };
    if (Array.isArray(raw.entries) && raw.entries.length > 0) return raw.entries;
  } catch {
  }
  return HSN_MASTER as MasterEntry[];
}

const PLACEHOLDER_DESCRIPTION = /^hsn\s+\d+$/i;

const MIN_INDEXED_CODE_LENGTH = 4;

function tariffDocs(): SourceDoc[] {
  const out: SourceDoc[] = [];
  for (const entry of masterEntries()) {
    if (!entry.code || entry.code.length < MIN_INDEXED_CODE_LENGTH) continue;
    if (!entry.description || PLACEHOLDER_DESCRIPTION.test(entry.description)) continue;
    const terms = new Map<string, number>();
    for (const token of tokenizeTariff(entry.description)) {
      terms.set(token, (terms.get(token) ?? 0) + WEIGHT_DEFINITION);
    }
    if (terms.size === 0) continue;
    out.push({ code: entry.code, terms });
  }
  return out;
}

export const MIN_CONFIDENT_SCORE = 1.2;

const MIN_CONFIDENT_TARIFF_SCORE = 4.5;

let curatedIndex: Index | null = null;
let tariffIndex: Index | null = null;

function indexes(): [Index, Index] {
  if (!curatedIndex || !tariffIndex) {
    const started = Date.now();
    curatedIndex = buildIndex('CURATED', curatedDocs(), MIN_CONFIDENT_SCORE, true);
    tariffIndex = buildIndex('TARIFF', tariffDocs(), MIN_CONFIDENT_TARIFF_SCORE, false);
    logger.info(
      {
        curated: curatedIndex.docCount,
        curatedTerms: curatedIndex.vocabulary.length,
        curatedAvgDocLen: Math.round(curatedIndex.avgDocLen),
        tariff: tariffIndex.docCount,
        tariffTerms: tariffIndex.vocabulary.length,
        tariffAvgDocLen: Math.round(tariffIndex.avgDocLen),
        ms: Date.now() - started,
      },
      'hsn: retrieval index built',
    );
  }
  return [curatedIndex, tariffIndex];
}

setImmediate(() => {
  try {
    indexes();
  } catch (e) {
    logger.warn({ err: (e as Error).message }, 'hsn: could not warm the retrieval index');
  }
}).unref();

type ExpandedTerm = {
  term: string;
  weight: number;
  via: 'exact' | 'prefix' | 'phonetic' | 'fuzzy';
  source: number;
};

const FUZZY_THRESHOLD = 0.62;

function expand(tokens: string[], idx: Index): ExpandedTerm[] {
  const out: ExpandedTerm[] = [];
  const seen = new Set<string>();
  let source = 0;
  const push = (term: string, weight: number, via: ExpandedTerm['via']) => {
    if (seen.has(term)) return;
    seen.add(term);
    out.push({ term, weight, via, source });
  };

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    source = i;
    if (idx.df.has(token)) {
      push(token, 1, 'exact');
      continue;
    }
    if (token.length >= 4) {
      const prefixed = idx.vocabulary
        .filter((t) => t !== token && t.startsWith(token))
        .sort((a, b) => a.length - b.length)
        .slice(0, 3);
      if (prefixed.length > 0) {
        for (const term of prefixed) push(term, 0.9, 'prefix');
        continue;
      }
    }
    if (!idx.repairs) continue;
    const key = phoneticKey(token);
    const sameSound = key ? idx.phonetic.get(key) : undefined;
    if (sameSound && sameSound.size > 0) {
      for (const term of sameSound) push(term, 0.85, 'phonetic');
      continue;
    }
    const grams = trigrams(token);
    let best: { term: string; score: number } | null = null;
    for (const term of idx.vocabulary) {
      const score = diceSimilarity(grams, idx.vocabTrigrams.get(term)!);
      if (score >= FUZZY_THRESHOLD && (!best || score > best.score)) best = { term, score };
    }
    if (best) push(best.term, 0.7 * best.score, 'fuzzy');
  }
  return out;
}

export type RetrievalHit = {
  code: string;
  score: number;
  matched: Array<ExpandedTerm['via']>;
  coverage: number;
  layer: RetrievalLayer;
};

const REPAIRED_ONLY_COVERAGE = 1;

function isAnchored(vias: Set<ExpandedTerm['via']>): boolean {
  return vias.has('exact') || vias.has('prefix');
}

function headToken(tokens: string[]): string | null {
  return tokens.length === 0 ? null : tokens[tokens.length - 1];
}

function score(tokens: string[], idx: Index): RetrievalHit[] {
  if (idx.docCount === 0) return [];
  const terms = expand(tokens, idx);
  if (terms.length === 0) return [];

  const scores = new Map<string, number>();
  const vias = new Map<string, Set<ExpandedTerm['via']>>();
  const covered = new Map<string, Set<number>>();

  for (const { term, weight, via, source } of terms) {
    const df = idx.df.get(term);
    if (!df) continue;
    const idf = Math.log(1 + (idx.docCount - df + 0.5) / (df + 0.5));

    for (const { code, freq } of idx.postings.get(term) ?? []) {
      const len = idx.docLen.get(code) ?? 0;
      const norm = freq * (K1 + 1);
      const denom = freq + K1 * (1 - B + (B * len) / (idx.avgDocLen || 1));
      const contribution = idf * (norm / denom) * weight;
      scores.set(code, (scores.get(code) ?? 0) + contribution);
      let set = vias.get(code);
      if (!set) {
        set = new Set();
        vias.set(code, set);
      }
      set.add(via);
      let seenTokens = covered.get(code);
      if (!seenTokens) {
        seenTokens = new Set();
        covered.set(code, seenTokens);
      }
      seenTokens.add(source);
    }
  }

  const headIndex = tokens.length - 1;
  return [...scores.entries()]
    .map(([code, hitScore]) => {
      const via = vias.get(code) ?? new Set<ExpandedTerm['via']>();
      const seenTokens = covered.get(code);
      return {
        code,
        score: hitScore,
        matched: [...via],
        coverage: (seenTokens?.size ?? 0) / tokens.length,
        layer: idx.layer,
        anchored: isAnchored(via),
        hasExact: via.has('exact'),
        matchesHead: seenTokens?.has(headIndex) ?? false,
      };
    })
    .filter((h) => {
      if (h.score < idx.minConfidentScore) return false;
      if (idx.layer !== 'TARIFF') {
        return h.anchored || h.coverage >= REPAIRED_ONLY_COVERAGE;
      }
      if (!h.anchored) return false;
      if (!h.hasExact && h.coverage < REPAIRED_ONLY_COVERAGE) return false;
      return h.matchesHead || h.coverage >= REPAIRED_ONLY_COVERAGE;
    })
    .map(({ anchored: _a, hasExact: _e, matchesHead: _m, ...hit }) => hit)
    .sort(
      (a, b) =>
        (idx.layer === 'TARIFF' ? b.coverage - a.coverage : 0) ||
        b.score - a.score ||
        a.code.localeCompare(b.code),
    );
}

function collapseToAncestors(hits: RetrievalHit[]): RetrievalHit[] {
  const present = new Set(hits.map((h) => h.code));
  return hits.filter((h) => {
    for (let len = 4; len < h.code.length; len += 2) {
      if (present.has(h.code.slice(0, len))) return false;
    }
    return true;
  });
}

export function retrieve(query: string, limit = 10): RetrievalHit[] {
  const [curated, tariff] = indexes();
  const tokens = tokenize(query);
  if (tokens.length === 0) return [];

  const hits = score(tokens, curated);
  if (hits.length < limit) {
    const seen = new Set(hits.map((h) => h.code));
    for (const hit of collapseToAncestors(score(tokens, tariff))) {
      if (seen.has(hit.code)) continue;
      hits.push(hit);
      if (hits.length >= limit) break;
    }
  }
  return hits.slice(0, limit);
}
