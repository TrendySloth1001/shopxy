import fs from 'node:fs';
import path from 'node:path';
import { corpus, normalizeTerm } from './hsn.copy.js';
import { HSN_MASTER } from './hsn.master.js';
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
/// ── Two corpora, not one ─────────────────────────────────────────────────
/// The curated catalogue is 101 codes of reviewed merchant vocabulary
/// ("chappal", "bartan", "chai"). The rate master is ~7,000 codes of official
/// tariff prose, which is the only place words like "keyboard", "tyre" and
/// "pneumatic" appear at all. Both are worth searching, and they must **not**
/// share an index — see [buildIndex] for why merging them breaks BM25 outright.
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

/// Structural prose that only the *tariff* is full of, stripped from official
/// descriptions on top of [STOPWORDS].
///
/// Every one of these is a legal-drafting artefact rather than a word about a
/// product: "not", "than", "whether" and "but" come from the exclusion clauses
/// ("whether or not containing…", "other than those of…"), and "heading",
/// "chapter", "item", "no", "elsewhere", "specified", "nec" are the tariff
/// pointing at itself. Measured over the 6,902 indexed descriptions, `not`
/// appears in 27%, `than` in 20%, `no` in 13% and `heading` in 12% — they cost
/// document length and buy nothing.
///
/// Deliberately narrow. "parts", "articles", "similar", "containing" and
/// "including" are frequent too, but they are words a merchant might really
/// type; BM25's IDF already discounts them to near-nothing without anyone
/// having to decide they're worthless.
const TARIFF_STOPWORDS = new Set([
  'not', 'than', 'no', 'nor', 'but', 'those', 'whether',
  'heading', 'headings', 'subheading', 'subheadings', 'chapter', 'chapters',
  'section', 'sections', 'elsewhere', 'specified', 'thereof', 'nec', 'nes',
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
///
/// Stopwords are matched **before** stemming, because that is the form they
/// are written in. Filtering afterwards silently misses half of them: `heading`
/// stems to `head` and `specified` to `specifi`, so a list containing the words
/// themselves would have let both straight through.
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

/// [tokenize] plus the tariff's own boilerplate, and without the code
/// fragments the schedule cites itself by.
///
/// "n.e.c. in item no. 8471.30 or 8471.41" tokenises to `8471`, `30`, `8471`,
/// `41` — digits that belong to a *different* code and would otherwise let a
/// search for one heading score every heading that cross-references it.
function tokenizeTariff(text: string): string[] {
  return tokenizeWith(text, TARIFF_STOPWORDS).filter((t) => !/^\d+$/.test(t));
}

/// Which corpus a hit came from. Curated copy is reviewed merchant vocabulary;
/// the tariff is the long tail nobody has written words for yet.
export type RetrievalLayer = 'CURATED' | 'TARIFF';

type Posting = { code: string; freq: number };

type Index = {
  layer: RetrievalLayer;
  /// term → the documents containing it, with their weighted frequency.
  /// A postings list rather than a per-term scan of every document: at 101
  /// codes the difference was invisible, at 7,000 it is the whole query cost.
  postings: Map<string, Posting[]>;
  /// term → number of documents containing it
  df: Map<string, number>;
  /// code → total weighted term count
  docLen: Map<string, number>;
  avgDocLen: number;
  docCount: number;
  /// Every indexed term, for prefix and fuzzy expansion.
  vocabulary: string[];
  /// Trigram sets and phonetic buckets back typo repair and transliteration
  /// folding. Empty on an index that does neither — see [repairs].
  vocabTrigrams: Map<string, Set<string>>;
  /// phonetic key → the terms that share it
  phonetic: Map<string, Set<string>>;
  /// Whether a query may be repaired against this index — folded phonetically
  /// or trigram-matched — as opposed to only matched literally.
  repairs: boolean;
  /// Score below which a hit from this corpus is not worth showing. Per-index
  /// because IDF scales with corpus size: the same single-rare-word match is
  /// worth ~2 against 101 documents and ~7 against 7,000.
  minConfidentScore: number;
};

type SourceDoc = { code: string; terms: Map<string, number> };

/// Assemble an index from documents whose term frequencies are already
/// weighted.
///
/// **One index per corpus, never one index over both.** BM25 normalises every
/// document against the corpus mean, and the two corpora have wildly different
/// shapes: a curated entry carries ~90 weighted terms (two locales of name,
/// definition and a dozen aliases), a tariff line ~11. Pooling them drags the
/// mean down to ~12, and at b=0.75 that makes every curated entry look
/// pathologically long — BM25 would divide their scores by roughly the ratio
/// of the lengths and hand the top of every result to a one-line tariff row.
/// The reviewed vocabulary would lose to the prose it exists to replace.
/// Document frequency is corpus-relative for the same reason.
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

// ── The curated corpus: 101 codes of reviewed merchant vocabulary ──────────

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

// ── The tariff corpus: every code's official description ───────────────────

/// The imported master, read straight from disk. Same file the seed syncs into
/// `hsn_codes`, so the index can't describe a code the database doesn't carry.
///
/// Read rather than `import`ed for the reason the copy catalogues are: it is
/// 1.8 MB of JSON that has no business in the TypeScript program. `npm run
/// build` copies `data/` into `dist/` alongside `copy/`; if that ever stops
/// happening the loader falls back to the hand-written manifest and the
/// curated layer carries on regardless.
const MASTER_PATH = path.join(__dirname, 'data', 'hsn.master.json');

type MasterEntry = { code: string; description: string };

function masterEntries(): MasterEntry[] {
  try {
    const raw = JSON.parse(fs.readFileSync(MASTER_PATH, 'utf8')) as {
      entries?: MasterEntry[];
    };
    if (Array.isArray(raw.entries) && raw.entries.length > 0) return raw.entries;
  } catch {
    // Nothing imported yet — fall through to the provisional manifest.
  }
  return HSN_MASTER as MasterEntry[];
}

/// Rows the importer had no description for. `HSN 40113000` is the code
/// written out as prose: it matches nothing a merchant would type, and
/// indexing 116 of them would put `hsn` in the vocabulary as a term that
/// distinguishes nothing.
const PLACEHOLDER_DESCRIPTION = /^hsn\s+\d+$/i;

/// Two-digit chapters are excluded. They are navigation rows by construction —
/// "Animals; live" is not a classification any product can bill under, and
/// [HsnService.resolveOutcome] refuses anything shorter than a heading anyway.
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

/// Score below which a result is too weak to present as a suggestion. A single
/// common word scraping one entry produces a low score, and showing it as "we
/// think this is your product" is worse than showing nothing — the merchant
/// trusts it, and the wrong code becomes a wrong rate on an invoice.
export const MIN_CONFIDENT_SCORE = 1.2;

/// The same judgement for the tariff, on the tariff's scale.
///
/// IDF grows with the corpus, so the numbers are not comparable: matching one
/// rare word scores ~2 against 101 curated entries and ~7 against 6,900 tariff
/// lines. Calibrated so that a whole distinctive word ("keyboard", "pneumatic")
/// clears it and a single frequent one ("machines", "articles") does not.
const MIN_CONFIDENT_TARIFF_SCORE = 4.5;

let curatedIndex: Index | null = null;
let tariffIndex: Index | null = null;

function indexes(): [Index, Index] {
  if (!curatedIndex || !tariffIndex) {
    const started = Date.now();
    // The curated catalogue repairs spellings; the tariff does not. Folding
    // and trigram-matching are how a merchant's own words are met halfway, and
    // the curated corpus is 101 reviewed entries where that is safe. The
    // tariff is machine-imported prose with a 12,000-word vocabulary: every
    // repair there is a chance to be confidently wrong, and — because a tariff
    // hit must be anchored by a word really typed — a repair could never carry
    // a hit on its own anyway. Not building the structures is also most of the
    // index build and most of the per-query cost.
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

/// Build the indexes off the critical path.
///
/// Reading and tokenising 6,900 tariff descriptions costs ~80 ms. Left lazy,
/// the merchant who types the first product name after a deploy pays all of it
/// on one keystroke; done at import time, every process — including a one-shot
/// script that will never search — pays it before it can serve anything. A
/// deferred, unreferenced build costs neither: the event loop is idle at boot
/// anyway, and it does not hold the process open if nothing else needs it.
setImmediate(() => {
  try {
    indexes();
  } catch (e) {
    // A corpus that won't load is worth a line in the log and nothing more —
    // the next [retrieve] will try again and, failing that, the alias index
    // above it still answers.
    logger.warn({ err: (e as Error).message }, 'hsn: could not warm the retrieval index');
  }
}).unref();

/// A query term, plus how much to trust it. An exact vocabulary hit counts
/// fully; something we reached by folding a spelling or repairing a typo
/// counts for less, so a fuzzy match can never outrank a real one.
type ExpandedTerm = {
  term: string;
  weight: number;
  via: 'exact' | 'prefix' | 'phonetic' | 'fuzzy';
  /// Which query token this came from. Carried through scoring so a hit can be
  /// judged on how much of the query it actually explains, not just how loudly
  /// one word scored — see [REPAIRED_ONLY_COVERAGE].
  source: number;
};

/// Minimum trigram overlap to treat two words as the same word mistyped.
/// Below ~0.6 the matches stop being typos and start being coincidences.
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
    if (!idx.repairs) continue;
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
  /// Fraction of the query's content words this entry accounted for, 0–1.
  coverage: number;
  /// Which corpus answered — reviewed vocabulary, or official tariff prose.
  layer: RetrievalLayer;
};

/// How much of the query a hit resting **only on repaired words** must explain.
///
/// BM25 alone rewards one loud word: "live horses for breeding" scored 7.6
/// against *biscuits*, because expansion folds `breed` and `bread` onto the
/// same consonant skeleton (`brd`) — the very mechanism that makes `qameez` →
/// `kameez` work. Vowels carry meaning in English that they don't in
/// transliteration, so no weighting fixes both cases at once.
///
/// Raw coverage doesn't separate them either: biscuits explains 1 of 3 tokens
/// (0.33) while the legitimate "device that keeps food cold" → refrigerators
/// explains only 1 of 4 (0.25). Coverage is the wrong axis on its own.
///
/// What actually differs is *how* the word matched. "cold" is a word the
/// merchant really typed and the entry really contains. "bread" is a word we
/// invented on their behalf. So: a hit anchored by at least one exact or prefix
/// term is judged on score alone, and a hit built purely from phonetic or
/// trigram repairs has to account for the entire query before we'll believe it.
/// `qameez` and `refrigerater` clear that at 1.0; the biscuits coincidence
/// doesn't come close.
const REPAIRED_ONLY_COVERAGE = 1;

/// Did any part of this match rest on a word the merchant actually typed?
function isAnchored(vias: Set<ExpandedTerm['via']>): boolean {
  return vias.has('exact') || vias.has('prefix');
}

/// Which query token names the thing being sold.
///
/// English product names are head-final — "wireless keyboard", "mobile phone
/// charger", "cotton formal shirt", "led bulb" — and so are the transliterated
/// ones merchants type ("sarson ka tel"). The last content word is what the
/// product *is*; everything before it is a modifier.
///
/// The tariff layer leans on this because BM25 alone can't: `wireless` occurs
/// in fewer tariff lines than `keyboard`, so "wireless keyboard" scored
/// smartphones above every keyboard in the schedule. Rarity is not aboutness.
function headToken(tokens: string[]): string | null {
  return tokens.length === 0 ? null : tokens[tokens.length - 1];
}

/// BM25 over one index. Returns every document that matched, ranked, before
/// any confidence judgement.
function score(tokens: string[], idx: Index): RetrievalHit[] {
  if (idx.docCount === 0) return [];
  const terms = expand(tokens, idx);
  if (terms.length === 0) return [];

  const scores = new Map<string, number>();
  const vias = new Map<string, Set<ExpandedTerm['via']>>();
  /// code → which query tokens it managed to account for.
  const covered = new Map<string, Set<number>>();

  for (const { term, weight, via, source } of terms) {
    const df = idx.df.get(term);
    if (!df) continue;
    // BM25 IDF, in the form that stays positive for terms present in more than
    // half the corpus — the raw formula goes negative there and would subtract
    // score for matching a common word, which is worse than ignoring it.
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
      // ── Three guards, because the tariff is 68× the corpus and none of it
      // was written to be searched by a shopkeeper ──────────────────────────
      //
      // 1. Anchored, always. The curated catalogue lets a repaired-only match
      //    through if it explains the whole query, which is safe at 101
      //    documents. Across ~6,900 short ones, a 12,000-word vocabulary puts
      //    some trigram neighbour within reach of almost any string, and a
      //    one-word query reaches coverage 1 for free. "asdfgh" must not find
      //    a code merely because it is two edits from one.
      // 2. A word really typed, or the whole query explained. A lone *prefix*
      //    match is type-ahead ("refriger…"), which is legitimate when it's
      //    the entire query and a coincidence when it isn't: "thing that goes
      //    fast" reached zip fasteners on `fast` → `fasten` alone.
      // 3. The head noun, or the whole query. Matching only a modifier means
      //    matching something that isn't the product — see [headToken].
      if (!h.anchored) return false;
      if (!h.hasExact && h.coverage < REPAIRED_ONLY_COVERAGE) return false;
      return h.matchesHead || h.coverage >= REPAIRED_ONLY_COVERAGE;
    })
    .map(({ anchored: _a, hasExact: _e, matchesHead: _m, ...hit }) => hit)
    .sort(
      (a, b) =>
        // How much of the query a tariff line explains outranks how loudly it
        // scored: `wireless` is rarer than `keyboard` and would otherwise
        // decide "wireless keyboard" on its own. The curated catalogue keeps
        // its pure BM25 order — its entries are written to be searched, and
        // rarity there means what it's supposed to mean.
        (idx.layer === 'TARIFF' ? b.coverage - a.coverage : 0) ||
        b.score - a.score ||
        a.code.localeCompare(b.code),
    );
}

/// Collapse a tariff hit onto its ancestor when both matched.
///
/// The schedule says the same thing at several depths — "Pianos; including …
/// harpsichords and other keyboard stringed instruments" at 9201 and
/// "harpsichords and other keyboard stringed instruments n.e.c. in heading no.
/// 9201" at 920190 — so one query lands on a heading and three of its own
/// sub-headings, and they crowd out every other answer.
///
/// The ancestor is the one to keep. It is where the notified rate actually
/// lives (a sub-heading usually inherits), it is the level the picker and the
/// breadcrumb are built around, and it is the level a merchant recognises.
/// Sub-headings are not lost — typing something more specific still reaches
/// them, because then the ancestor doesn't match and there is nothing to
/// collapse onto.
function collapseToAncestors(hits: RetrievalHit[]): RetrievalHit[] {
  const present = new Set(hits.map((h) => h.code));
  return hits.filter((h) => {
    for (let len = 4; len < h.code.length; len += 2) {
      if (present.has(h.code.slice(0, len))) return false;
    }
    return true;
  });
}

/// Rank codes for a free-text query. Empty query → empty result; the caller
/// decides what to show instead.
///
/// **Curated before tariff, always.** The 101 curated entries are reviewed
/// merchant vocabulary — the words merchants actually type, mapped by someone
/// who checked. The tariff is machine-imported prose that has never been read
/// with a merchant in mind: "Musical instruments; keyboard, (other than
/// accordions)" is a perfectly good match for "keyboard" and a bad answer for
/// the person selling computer peripherals. So the tariff answers what the
/// catalogue can't, and never overrules it.
///
/// Only hits already worth showing come back: the two corpora score on
/// different scales (see [MIN_CONFIDENT_TARIFF_SCORE]), so a caller cannot
/// apply one threshold to a mixed list, and shouldn't have to know that.
export function retrieve(query: string, limit = 10): RetrievalHit[] {
  const [curated, tariff] = indexes();
  const tokens = tokenize(query);
  if (tokens.length === 0) return [];

  const hits = score(tokens, curated);
  if (hits.length < limit) {
    const seen = new Set(hits.map((h) => h.code));
    // Nothing is folded phonetically against the tariff. Consonant-skeleton
    // matching exists for Hindi transliterations — kameez/qameez,
    // chappal/chapal — and the tariff contains none: it is formal English,
    // where vowels carry meaning. Folding it is precisely how `breeding`
    // reached `bread` and put biscuits at the top of "live horses for
    // breeding", and a 12,000-word vocabulary would offer that coincidence to
    // every query. See the `repairs` flag in [indexes].
    for (const hit of collapseToAncestors(score(tokens, tariff))) {
      if (seen.has(hit.code)) continue;
      hits.push(hit);
      if (hits.length >= limit) break;
    }
  }
  return hits.slice(0, limit);
}
