import fs from 'node:fs';
import path from 'node:path';
import { z } from 'zod';
import { logger } from '../../shared/logging/logger.js';

const entrySchema = z.object({
  name: z.string().min(1),
  definition: z.string().optional(),
  aliases: z.array(z.string().min(1)).optional(),
  notHere: z.record(z.string(), z.string()).optional(),
});

const catalogueSchema = z.object({
  locale: z.string().min(2),
  _readme: z.array(z.string()).optional(),
  entries: z.record(z.string(), entrySchema),
});

export type HsnCopyEntry = z.infer<typeof entrySchema>;

const LOCALES = ['en', 'hi'] as const;
export type HsnLocale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: HsnLocale = 'en';

const COPY_DIR = path.join(__dirname, 'copy');

const byCode = new Map<string, Map<HsnLocale, HsnCopyEntry>>();
const aliasIndex = new Map<string, Set<string>>();

export function normalizeTerm(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[.,/#!$%^&*;:{}=\-_`~()'"]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

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
  const primary = raw.toLowerCase().split(/[-_]/)[0];
  return (LOCALES as readonly string[]).includes(primary)
    ? (primary as HsnLocale)
    : DEFAULT_LOCALE;
}

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

export function matchAliasesInText(text: string, limit = 20): string[] {
  const haystack = normalizeTerm(text);
  if (!haystack) return [];
  const best = new Map<string, number>();
  for (const [alias, codes] of aliasIndex) {
    if (alias.length < 3) continue;
    if (!containsWord(haystack, alias)) continue;
    for (const code of codes) {
      if ((best.get(code) ?? 0) < alias.length) best.set(code, alias.length);
    }
  }
  return [...best.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([code]) => code);
}

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

export function codesWithCopy(): string[] {
  return [...byCode.keys()].sort();
}

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
