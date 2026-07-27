import fs from 'node:fs';
import path from 'node:path';
import { z } from 'zod';
import { logger } from '../../shared/logging/logger.js';

/// Loader for the translatable HSN copy catalogues.
///
/// The words a merchant reads and searches by live in `copy/hsn.copy.<locale>.json`,
/// keyed by code, deliberately apart from the rates in the database. Two
/// properties fall out of that split and both matter:
///
///   * A translation PR can't touch a tax figure, and a rate change can't
///     silently invalidate a translation.
///   * Adding "kameez" as a search term is a content edit, not a migration.
///
/// **Aliases are merged across every locale.** A merchant on the English UI
/// still types `kameez`, and one on the Hindi UI still types `shirt`. Only the
/// display strings (name, definition) are locale-scoped; matching sees all of
/// them at once, so each spelling is listed exactly once in whichever file it
/// naturally belongs to.
///
/// Loaded once at import and held in memory. The whole catalogue is a few
/// hundred small objects — an index build measured in microseconds — so
/// there's no cache to invalidate and no round trip on the typing path.

const entrySchema = z.object({
  name: z.string().min(1),
  definition: z.string().optional(),
  aliases: z.array(z.string().min(1)).optional(),
  /// Cross-references to the neighbours this code gets confused with, as
  /// `code → label`. Half of misclassification isn't failing to find something,
  /// it's confidently picking the wrong one — this is what redirects them.
  notHere: z.record(z.string(), z.string()).optional(),
});

const catalogueSchema = z.object({
  locale: z.string().min(2),
  // Free-form note block at the top of each file; ignored here.
  _readme: z.array(z.string()).optional(),
  entries: z.record(z.string(), entrySchema),
});

export type HsnCopyEntry = z.infer<typeof entrySchema>;

/// Locales we ship copy for. Adding one is: drop in the JSON, add it here.
const LOCALES = ['en', 'hi'] as const;
export type HsnLocale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: HsnLocale = 'en';

/// Read from disk rather than `import`ing the JSON: `resolveJsonModule` would
/// inline these into the bundle and pull every JSON in the tree into the TS
/// program. Reading at runtime also means a translator's edit is visible on a
/// dev restart without a recompile.
///
/// `tsc` doesn't copy non-TS assets, so `npm run build` copies this directory
/// into `dist/` alongside the compiled output — if that step is ever dropped,
/// the loader logs a warning and every locale falls back to tariff wording
/// rather than the process failing to boot.
const COPY_DIR = path.join(__dirname, 'copy');

/// code → locale → copy
const byCode = new Map<string, Map<HsnLocale, HsnCopyEntry>>();
/// normalised alias → codes that claim it. One alias can legitimately point at
/// several codes ("bag" is both luggage and packaging sacks); ranking sorts it
/// out downstream rather than the loader picking a winner.
const aliasIndex = new Map<string, Set<string>>();

/// Lowercase, strip punctuation, collapse whitespace. Applied identically to
/// stored aliases and to incoming queries — the only way the two can meet.
/// Devanagari passes through untouched: the class being stripped is ASCII
/// punctuation, not "non-Latin".
export function normalizeTerm(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[.,/#!$%^&*;:{}=\-_`~()'"]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/// True when `needle` appears in `haystack` as a whole space-delimited word.
/// Both sides are already normalised to single spaces by [normalizeTerm].
function containsWord(haystack: string, needle: string): boolean {
  const at = haystack.indexOf(needle);
  if (at < 0) return false;
  const before = at === 0 || haystack[at - 1] === ' ';
  const end = at + needle.length;
  const after = end === haystack.length || haystack[end] === ' ';
  return before && after;
}

function indexAlias(alias: string, code: string): void {
  const key = normalizeTerm(alias);
  if (!key) return;
  let set = aliasIndex.get(key);
  if (!set) {
    set = new Set();
    aliasIndex.set(key, set);
  }
  set.add(code);
}

function load(): void {
  for (const locale of LOCALES) {
    let raw: unknown;
    try {
      raw = JSON.parse(
        fs.readFileSync(path.join(COPY_DIR, `hsn.copy.${locale}.json`), 'utf8'),
      );
    } catch (e) {
      // A missing catalogue degrades that locale to the fallback rather than
      // taking the process down — the rates, which are what actually matter,
      // don't live here.
      logger.warn({ locale, err: (e as Error).message }, 'hsn copy: catalogue not loaded');
      continue;
    }
    const parsed = catalogueSchema.safeParse(raw);
    if (!parsed.success) {
      logger.error(
        { locale, issues: parsed.error.issues.slice(0, 5) },
        'hsn copy: catalogue failed validation; skipped',
      );
      continue;
    }
    for (const [code, entry] of Object.entries(parsed.data.entries)) {
      let perLocale = byCode.get(code);
      if (!perLocale) {
        perLocale = new Map();
        byCode.set(code, perLocale);
      }
      perLocale.set(locale, entry);

      // The name itself is a search term — merchants type what they see.
      indexAlias(entry.name, code);
      for (const alias of entry.aliases ?? []) indexAlias(alias, code);
    }
  }
  logger.info(
    { codes: byCode.size, aliases: aliasIndex.size, locales: LOCALES.length },
    'hsn copy: catalogues indexed',
  );
}

load();

export function resolveLocale(raw: string | undefined): HsnLocale {
  if (!raw) return DEFAULT_LOCALE;
  // Accept "hi-IN", "hi_IN", "hi" — only the primary subtag is meaningful here.
  const primary = raw.toLowerCase().split(/[-_]/)[0];
  return (LOCALES as readonly string[]).includes(primary)
    ? (primary as HsnLocale)
    : DEFAULT_LOCALE;
}

/// Copy for a code in the requested locale, falling back field-by-field to
/// English. A half-translated entry therefore shows a Hindi name with an
/// English definition rather than dropping to English wholesale — the merchant
/// gets whatever has actually been translated.
export function copyFor(code: string, locale: HsnLocale = DEFAULT_LOCALE): HsnCopyEntry | null {
  const perLocale = byCode.get(code);
  if (!perLocale) return null;
  const wanted = perLocale.get(locale);
  const fallback = perLocale.get(DEFAULT_LOCALE);
  if (!wanted) return fallback ?? null;
  if (!fallback || locale === DEFAULT_LOCALE) return wanted;
  return {
    name: wanted.name,
    definition: wanted.definition ?? fallback.definition,
    aliases: wanted.aliases,
    notHere: wanted.notHere ?? fallback.notHere,
  };
}

/// Codes whose aliases match the query, ranked: exact alias hit first, then
/// prefix, then substring. Cheap enough to run on every keystroke — it's a Map
/// probe plus a scan of a few hundred short keys.
///
/// Returns codes only; the caller joins them against the rate table, because
/// copy alone can't say whether a code is currently ratable.
export function searchCopy(query: string, limit = 20): string[] {
  const q = normalizeTerm(query);
  if (!q) return [];

  const exact = aliasIndex.get(q);
  const ranked = new Map<string, number>();
  const bump = (code: string, score: number) => {
    const cur = ranked.get(code);
    if (cur === undefined || score < cur) ranked.set(code, score);
  };

  if (exact) for (const code of exact) bump(code, 0);
  for (const [alias, codes] of aliasIndex) {
    if (alias === q) continue;
    // 1 = the alias starts with what they typed (type-ahead: "sham" → "shampoo").
    // 2 = the query appears as a whole word inside it ("oil" → "hair oil").
    //
    // Whole-word, not raw substring: a plain `includes` matched "oil" against
    // "toilet paper" and put tissues above cooking oil. Aliases are normalised
    // to single-spaced words, so boundary checking is three string compares.
    const score = alias.startsWith(q) ? 1 : containsWord(alias, q) ? 2 : -1;
    if (score < 0) continue;
    for (const code of codes) bump(code, score);
    if (ranked.size > limit * 4) break;
  }

  return [...ranked.entries()]
    .sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([code]) => code);
}

/// Codes whose alias appears **inside** the given text as a whole phrase.
///
/// [searchCopy] answers "which aliases start with or contain what the merchant
/// typed" — right for a search box, wrong for a product name. A real product
/// name is longer than the alias: "sarson ka tel 1L" *contains* the alias
/// "sarson ka tel", and checking only the other direction made mustard oil
/// invisible while generic oils (matching the bare word "tel") won.
///
/// Ranked by alias length, longest first: a match on "sarson ka tel" is a far
/// more specific claim than one on "tel", so specificity is the signal, not
/// word position or rarity — both of which get it wrong on one name shape or
/// the other.
export function matchAliasesInText(text: string, limit = 20): string[] {
  const haystack = normalizeTerm(text);
  if (!haystack) return [];
  const hits: Array<{ code: string; len: number }> = [];
  const seen = new Set<string>();
  for (const [alias, codes] of aliasIndex) {
    // Single characters and two-letter fragments match far too much to be
    // evidence of anything.
    if (alias.length < 3) continue;
    if (!containsWord(haystack, alias)) continue;
    for (const code of codes) {
      if (seen.has(code)) continue;
      seen.add(code);
      hits.push({ code, len: alias.length });
    }
  }
  return hits
    .sort((a, b) => b.len - a.len || a.code.localeCompare(b.code))
    .slice(0, limit)
    .map((h) => h.code);
}

/// The full corpus, field by field, across every locale.
///
/// Kept structured rather than pre-joined because the retrieval index weights
/// the fields differently: a hit on an alias is a much stronger claim than a
/// hit somewhere in a definition, and flattening to one string throws that
/// distinction away.
export function corpus(): Array<{
  code: string;
  names: string[];
  definitions: string[];
  aliases: string[];
}> {
  const out: Array<{ code: string; names: string[]; definitions: string[]; aliases: string[] }> =
    [];
  for (const [code, perLocale] of byCode) {
    const names: string[] = [];
    const definitions: string[] = [];
    const aliases: string[] = [];
    for (const entry of perLocale.values()) {
      names.push(entry.name);
      if (entry.definition) definitions.push(entry.definition);
      if (entry.aliases?.length) aliases.push(...entry.aliases);
    }
    out.push({ code, names, definitions, aliases });
  }
  return out;
}

/// Every code that carries copy, for the embedding build. Sorted so the
/// generated vector file is byte-stable across runs and diffs cleanly.
export function codesWithCopy(): string[] {
  return [...byCode.keys()].sort();
}

/// The text an embedding should be built from: name, definition and aliases
/// together, so a semantic query matches on meaning rather than the label
/// alone. English and Hindi are concatenated on purpose — one vector per code
/// that answers queries in either language.
export function embeddingTextFor(code: string): string {
  const perLocale = byCode.get(code);
  if (!perLocale) return '';
  const parts: string[] = [];
  for (const entry of perLocale.values()) {
    parts.push(entry.name);
    if (entry.definition) parts.push(entry.definition);
    if (entry.aliases?.length) parts.push(entry.aliases.join(', '));
  }
  return parts.join('\n');
}
