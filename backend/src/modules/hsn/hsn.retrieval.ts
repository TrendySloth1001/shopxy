import { corpus, normalizeTerm } from './hsn.copy.js';
import { logger } from '../../shared/logging/logger.js';

/// Classical text retrieval over the HSN copy catalogues — BM25, with fuzzy
/// and phonetic query expansion.
///
/// This is the **primary** way a product name becomes a code. It is
/// deterministic, offline, free, and answers in well under a millisecond, so
/// there is no quota to watch and no third party to be up.
///
/// ── Why this beats what it replaces ──────────────────────────────────────
/// The old lexical layer only searched *aliases* and ignored the definitions
/// we had already written. That was the whole gap: "stuff to wash dishes with"
/// shares `wash` and `dish` with 3402's definition ("…detergent powder and
/// bars, dishwash, floor cleaner…") and needed no model at all to find. BM25
/// over name + definition + aliases picks that up for nothing.
///
/// ── Why BM25 rather than raw term counting ───────────────────────────────
/// A term's worth is how *rare* it is. `dishwash` occurs in one entry and is
/// decisive; `oil` occurs in six and is weak; `for`, `with`, `other` occur
/// everywhere and mean nothing. BM25 encodes exactly that (inverse document
/// frequency), plus saturation — the tenth occurrence of a word in a long
/// definition adds far less than the first — and length normalisation, so a
/// verbose entry doesn't outrank a precise one just by having more words.
///
/// ── What it can't do ─────────────────────────────────────────────────────
/// True paraphrase with no shared vocabulary: "thing you fry pakoras in" → oil
/// needs world knowledge, because neither "fry" nor "pakora" appears in any
/// oil entry. That is the (small) tail an embedding model would cover — and it
/// is also just a missing alias. Every such miss is worth logging and curing
/// with a word, which makes the gap shrink instead of costing money forever.

/// BM25 tuning. k1 controls how fast term frequency saturates, b how strongly
/// document length is normalised. These are the standard defaults and there is
/// no reason to deviate on a corpus this small and this uniform.
const K1 = 1.5;
const B = 0.75;

/// Field weights. A word in a merchant-facing alias is a far stronger claim
/// than the same word buried in a tariff definition, so aliases and names are
/// counted several times over when building term frequencies.
const WEIGHT_ALIAS = 5;
const WEIGHT_NAME = 3;
const WEIGHT_DEFINITION = 1;

/// Query words that carry no signal. Deliberately small — an aggressive
/// stoplist strips words that turn out to matter ("set", "oil", "paper" are
/// all real product words). These are pure function words, plus the filler
/// that shows up when a merchant describes rather than names a thing.
const STOPWORDS = new Set([
  'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'can', 'do', 'for', 'from',
  'has', 'have', 'i', 'in', 'is', 'it', 'its', 'me', 'my', 'of', 'on', 'or',
  'other', 'our', 'that', 'the', 'their', 'them', 'then', 'there', 'these',
  'they', 'this', 'to', 'up', 'use', 'used', 'using', 'was', 'we', 'what',
  'when', 'where', 'which', 'who', 'why', 'will', 'with', 'you', 'your',
  // Filler nouns in descriptive queries: "thing you fry X in", "stuff to …".
  'thing', 'things', 'stuff', 'item', 'items', 'kind', 'type', 'sort',
  // Hindi function words that appear in transliterated names.
  'ka', 'ke', 'ki', 'ko', 'se', 'aur', 'hai', 'wala', 'wali',
]);

/// Conservative suffix stripping. Not a full Porter stemmer: this corpus is
/// short, and over-stemming ("batteries" → "batteri") costs more than the
/// recall it buys. Only the suffixes that actually differ between how a
/// merchant types and how a definition is written.
function stem(token: string): string {
  if (token.length <= 3) return token;
  // Devanagari and other non-Latin scripts pass through — English suffix
  // rules would mangle them.
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

/// A spelling-insensitive key for Latin transliterations of Indian words.
///
/// `kameez`, `kamiz`, `qameez` and `kamees` are the same word typed four ways,
/// and no amount of alias curation catches every variant. Reducing to a
/// consonant skeleton — with the digraphs and consonant equivalences Hindi
/// transliteration actually varies over — collapses them to one key.
///
/// Returns '' for anything that isn't Latin (Devanagari is already canonical,
/// so it matches exactly and needs no folding).
export function phoneticKey(raw: string): string {
  // Short words fold into keys too coarse to mean anything: `dish` reduces to
  // the same skeleton as `desi` and put butter and ghee at the top of "stuff
  // to wash dishes with". Transliterated words that genuinely need folding
  // (kameez, chappal, sariya) are all longer than this.
  if (!/^[a-z]+$/.test(raw) || raw.length < 5) return '';
  let s = raw;
  // Digraphs first, so the single-letter rules below can't split them.
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
  // Consonants that transliteration treats as interchangeable.
  s = s
    .replace(/q/g, 'k')
    .replace(/c/g, 'k')
    .replace(/x/g, 'ks')
    .replace(/z/g, 'j')
    .replace(/w/g, 'v')
    .replace(/C/g, 'c')
    .replace(/S/g, 's');
  // Keep the leading sound, then drop vowels: it's the consonant frame that
  // stays stable across spellings.
  const head = s[0];
  s = head + s.slice(1).replace(/[aeiouy]/g, '');
  // Doubled consonants are a spelling choice ("chappal" / "chapal").
  s = s.replace(/(.)\1+/g, '$1');
  return s;
}

/// Character trigrams, for catching typos the phonetic key can't — a merchant
/// typing "refrigerater" or "shrt" has made a keyboard mistake, not a
/// transliteration choice.
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

/// Tokenise, drop stopwords, stem. Used identically for documents and queries
/// — the only way the two can meet.
export function tokenize(text: string): string[] {
  return normalizeTerm(text)
    .split(' ')
    .filter((t) => t.length > 1 && !STOPWORDS.has(t))
    .map(stem)
    .filter(Boolean);
}

type Index = {
  /// code → term → weighted frequency
  docs: Map<string, Map<string, number>>;
  /// term → number of documents containing it
  df: Map<string, number>;
  /// code → total weighted term count
  docLen: Map<string, number>;
  avgDocLen: number;
  docCount: number;
  /// Every indexed term, for fuzzy expansion.
  vocabulary: string[];
  vocabTrigrams: Map<string, Set<string>>;
  /// phonetic key → the terms that share it
  phonetic: Map<string, Set<string>>;
};

let index: Index | null = null;

function build(): Index {
  const docs = new Map<string, Map<string, number>>();
  const df = new Map<string, number>();
  const docLen = new Map<string, number>();
  const phonetic = new Map<string, Set<string>>();

  for (const entry of corpus()) {
    const tf = new Map<string, number>();
    const add = (text: string, weight: number) => {
      for (const token of tokenize(text)) {
        tf.set(token, (tf.get(token) ?? 0) + weight);
      }
    };
    for (const n of entry.names) add(n, WEIGHT_NAME);
    for (const d of entry.definitions) add(d, WEIGHT_DEFINITION);
    for (const a of entry.aliases) add(a, WEIGHT_ALIAS);
    if (tf.size === 0) continue;

    docs.set(entry.code, tf);
    let len = 0;
    for (const [term, freq] of tf) {
      len += freq;
      df.set(term, (df.get(term) ?? 0) + 1);
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
    docLen.set(entry.code, len);
  }

  const docCount = docs.size;
  const avgDocLen =
    docCount === 0 ? 0 : [...docLen.values()].reduce((a, b) => a + b, 0) / docCount;
  const vocabulary = [...df.keys()];
  const vocabTrigrams = new Map(vocabulary.map((t) => [t, trigrams(t)]));

  logger.info(
    { codes: docCount, terms: vocabulary.length, avgDocLen: Math.round(avgDocLen) },
    'hsn: retrieval index built',
  );
  return { docs, df, docLen, avgDocLen, docCount, vocabulary, vocabTrigrams, phonetic };
}

function getIndex(): Index {
  if (!index) index = build();
  return index;
}

/// A query term, plus how much to trust it. An exact vocabulary hit counts
/// fully; something we reached by folding a spelling or repairing a typo
/// counts for less, so a fuzzy match can never outrank a real one.
type ExpandedTerm = {
  term: string;
  weight: number;
  via: 'exact' | 'prefix' | 'phonetic' | 'fuzzy';
};

/// Minimum trigram overlap to treat two words as the same word mistyped.
/// Below ~0.6 the matches stop being typos and start being coincidences.
const FUZZY_THRESHOLD = 0.62;

function expand(tokens: string[], idx: Index): ExpandedTerm[] {
  const out: ExpandedTerm[] = [];
  const seen = new Set<string>();
  const push = (term: string, weight: number, via: ExpandedTerm['via']) => {
    if (seen.has(term)) return;
    seen.add(term);
    out.push({ term, weight, via });
  };

  for (const token of tokens) {
    if (idx.df.has(token)) {
      push(token, 1, 'exact');
      continue;
    }
    // A prefix of a compound the catalogue spells as one word. "dish" is not a
    // term on its own but "dishwash" is, and a merchant typing "wash dishes"
    // means exactly that entry. Cheap, and it also covers the merchant who
    // stops typing early ("refriger…").
    if (token.length >= 4) {
      const prefixed = idx.vocabulary
        .filter((t) => t !== token && t.startsWith(token))
        // Shortest first: the closest word to what they typed.
        .sort((a, b) => a.length - b.length)
        .slice(0, 3);
      if (prefixed.length > 0) {
        for (const term of prefixed) push(term, 0.9, 'prefix');
        continue;
      }
    }
    // Spelling variant of a transliterated word?
    const key = phoneticKey(token);
    const sameSound = key ? idx.phonetic.get(key) : undefined;
    if (sameSound && sameSound.size > 0) {
      for (const term of sameSound) push(term, 0.85, 'phonetic');
      continue;
    }
    // Typo? Take the single best trigram match, not everything above the bar —
    // one repair per word, or a misspelling starts pulling in a crowd.
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
  /// Whether any part of the match needed repairing, for diagnostics and for
  /// deciding whether a result is confident enough to auto-apply.
  matched: Array<ExpandedTerm['via']>;
};

/// Rank codes for a free-text query. Empty query → empty result; the caller
/// decides what to show instead.
export function retrieve(query: string, limit = 10): RetrievalHit[] {
  const idx = getIndex();
  if (idx.docCount === 0) return [];
  const tokens = tokenize(query);
  if (tokens.length === 0) return [];

  const terms = expand(tokens, idx);
  if (terms.length === 0) return [];

  const scores = new Map<string, number>();
  const vias = new Map<string, Set<ExpandedTerm['via']>>();

  for (const { term, weight, via } of terms) {
    const df = idx.df.get(term);
    if (!df) continue;
    // BM25 IDF, in the form that stays positive for terms present in more than
    // half the corpus — the raw formula goes negative there and would subtract
    // score for matching a common word, which is worse than ignoring it.
    const idf = Math.log(1 + (idx.docCount - df + 0.5) / (df + 0.5));

    for (const [code, tf] of idx.docs) {
      const freq = tf.get(term);
      if (!freq) continue;
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
    }
  }

  return [...scores.entries()]
    .map(([code, score]) => ({ code, score, matched: [...(vias.get(code) ?? [])] }))
    .sort((a, b) => b.score - a.score || a.code.localeCompare(b.code))
    .slice(0, limit);
}

/// Score below which a result is too weak to present as a suggestion. A single
/// common word scraping one entry produces a low score, and showing it as "we
/// think this is your product" is worse than showing nothing — the merchant
/// trusts it, and the wrong code becomes a wrong rate on an invoice.
export const MIN_CONFIDENT_SCORE = 1.2;
