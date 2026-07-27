import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import { HSN_RATE_REVISION, type HsnMasterEntry } from '../modules/hsn/hsn.master.js';

/// Build the HSN/SAC master from **official** data, instead of anyone typing
/// rates by hand.
///
///   npm run hsn:import -- --directory hsn_codes.csv --rates gst_rates.csv
///
/// The two inputs are genuinely different datasets and both are needed:
///
///   --directory  The HSN/SAC code list: code + official tariff description.
///                ~12,000 rows, published as part of the Customs Tariff /
///                GST portal HSN master. Gives complete *structure* — every
///                chapter, heading and sub-heading — but carries no rates.
///
///   --rates      Code → GST rate, from the CBIC rate finder or the rate
///                notification schedules. Far fewer rows than the directory,
///                because rates are declared at the level the notification
///                chose (often the 4-digit heading).
///
/// A code present in the directory but absent from the rate file becomes a
/// **navigation row** (`isRatable: false`): it shows up in the breadcrumb and
/// in search, but can never price a line. That is exactly right — a chapter
/// has no rate of its own, and inventing one would bill at a slab that does
/// not legally exist.
///
/// ── Why this script exists ──────────────────────────────────────────────
/// Whatever ends up on an invoice has to be the real code at the notified
/// rate, because that is what the department reconciles against. Hand-authored
/// tax data is a liability no matter how carefully it is written. So the code
/// in this repo owns the *shape*; the government owns the *content*.
///
/// The output is written to `src/modules/hsn/data/hsn.master.json`, which the
/// seed prefers over the checked-in provisional manifest. Commit it: it is
/// reviewable, diffable, and a rate change becomes a visible PR rather than
/// someone's memory.
///
/// ── Input formats ───────────────────────────────────────────────────────
/// CSV (with a header row) or JSON (an array of objects). Column names are
/// auto-detected from the usual spellings; override with --code-field etc.
/// when a particular download disagrees.

type Row = Record<string, string>;

const CODE_FIELDS = ['code', 'hsn', 'hsn_code', 'hsncode', 'hsn_sac', 'sac', 'c', 'chapter'];
const DESC_FIELDS = ['description', 'desc', 'name', 'n', 'goods', 'commodity', 'particulars'];
const RATE_FIELDS = ['rate', 'gst', 'gst_rate', 'gstrate', 'igst', 'igst_rate', 'tax'];
const CESS_FIELDS = ['cess', 'cess_rate', 'compensation_cess'];

function parseArgs(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    if (!argv[i].startsWith('--')) continue;
    const key = argv[i].slice(2);
    const next = argv[i + 1];
    out[key] = next && !next.startsWith('--') ? next : 'true';
    if (out[key] !== 'true') i++;
  }
  return out;
}

/// Minimal RFC-4180 reader: quoted fields, escaped quotes, embedded commas and
/// newlines. Small enough to keep here rather than take a dependency for one
/// script, and government CSV exports routinely contain commas inside
/// descriptions — a naive `split(',')` silently shifts every later column.
function parseCsv(text: string): Row[] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else quoted = false;
      } else field += ch;
      continue;
    }
    if (ch === '"') quoted = true;
    else if (ch === ',') {
      row.push(field);
      field = '';
    } else if (ch === '\n' || ch === '\r') {
      if (field !== '' || row.length > 0) {
        row.push(field);
        rows.push(row);
        row = [];
        field = '';
      }
      if (ch === '\r' && text[i + 1] === '\n') i++;
    } else field += ch;
  }
  if (field !== '' || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  if (rows.length === 0) return [];

  const header = rows[0].map((h) => h.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_'));
  return rows.slice(1).map((r) => {
    const obj: Row = {};
    header.forEach((h, i) => {
      obj[h] = (r[i] ?? '').trim();
    });
    return obj;
  });
}

function readTable(file: string): Row[] {
  const text = fs.readFileSync(file, 'utf8');
  if (file.toLowerCase().endsWith('.json')) {
    const parsed = JSON.parse(text);
    const arr = Array.isArray(parsed) ? parsed : (parsed.data ?? parsed.records ?? []);
    return (arr as Array<Record<string, unknown>>).map((o) => {
      const row: Row = {};
      for (const [k, v] of Object.entries(o)) {
        row[k.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_')] = `${v ?? ''}`.trim();
      }
      return row;
    });
  }
  return parseCsv(text);
}

/// Pick the first column present in the data, preferring an explicit override.
function pickField(rows: Row[], candidates: string[], override?: string): string | null {
  if (override) return override.toLowerCase().replace(/[^a-z0-9]+/g, '_');
  const keys = new Set(rows.flatMap((r) => Object.keys(r)));
  for (const c of candidates) if (keys.has(c)) return c;
  // Fall back to a fuzzy contains, for headers like "hsn_code_8_digit".
  for (const c of candidates) {
    const hit = [...keys].find((k) => k.includes(c));
    if (hit) return hit;
  }
  return null;
}

const digitsOnly = (s: string) => s.replace(/\D/g, '');

/// Rates arrive as "5", "5%", "5.00", "Nil", "NIL", "-".
function parseRate(raw: string): number | null {
  const s = raw.trim().toLowerCase();
  if (!s || s === '-' || s === 'na' || s === 'n/a') return null;
  if (s === 'nil' || s === 'exempt' || s === 'exempted') return 0;
  const n = Number.parseFloat(s.replace('%', '').trim());
  return Number.isFinite(n) ? n : null;
}

function main(): void {
  const args = parseArgs(process.argv.slice(2));
  const directoryFile = args.directory;
  const ratesFile = args.rates;

  if (!directoryFile && !ratesFile) {
    console.error(
      [
        'Usage: npm run hsn:import -- --directory <file> [--rates <file>]',
        '',
        '  --directory   HSN/SAC code list (code + official description).',
        '  --rates       code → GST rate (CBIC rate finder / notification schedule).',
        '',
        'Optional column overrides when auto-detection picks wrong:',
        '  --code-field --desc-field --rate-field --cess-field',
        '  --revision    effective-from date for the imported rates',
        `                (default ${HSN_RATE_REVISION})`,
        '',
        'CSV (with header) or JSON array. Writes src/modules/hsn/data/hsn.master.json.',
      ].join('\n'),
    );
    process.exit(1);
  }

  const revision = args.revision ?? HSN_RATE_REVISION;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(revision)) {
    console.error(`--revision must be YYYY-MM-DD, got "${revision}"`);
    process.exit(1);
  }

  // ── Rates first: they decide which codes can price a line ───────────────
  const rates = new Map<string, { gstRate: number; cessRate: number }>();
  if (ratesFile) {
    const rows = readTable(ratesFile);
    const codeField = pickField(rows, CODE_FIELDS, args['code-field']);
    const rateField = pickField(rows, RATE_FIELDS, args['rate-field']);
    const cessField = pickField(rows, CESS_FIELDS, args['cess-field']);
    if (!codeField || !rateField) {
      console.error(
        `Could not find code/rate columns in ${ratesFile}. ` +
          `Saw: ${[...new Set(rows.flatMap((r) => Object.keys(r)))].join(', ')}`,
      );
      process.exit(1);
    }
    let skipped = 0;
    for (const row of rows) {
      const code = digitsOnly(row[codeField] ?? '');
      const gstRate = parseRate(row[rateField] ?? '');
      if (code.length < 2 || gstRate === null) {
        skipped++;
        continue;
      }
      // A code can appear more than once when a notification splits it by
      // condition. Keep the LOWEST rate and let the rate note / rule layer
      // handle the split — over-charging by default is the worse error, and a
      // conditional entry needs a human anyway.
      const existing = rates.get(code);
      if (!existing || gstRate < existing.gstRate) {
        rates.set(code, {
          gstRate,
          cessRate: cessField ? (parseRate(row[cessField] ?? '') ?? 0) : 0,
        });
      }
    }
    console.log(
      `rates: ${rates.size} codes from ${ratesFile} (${skipped} rows skipped as unparseable)`,
    );
  }

  // ── Directory: structure, including the levels that carry no rate ───────
  const entries = new Map<string, HsnMasterEntry>();
  if (directoryFile) {
    const rows = readTable(directoryFile);
    const codeField = pickField(rows, CODE_FIELDS, args['code-field']);
    const descField = pickField(rows, DESC_FIELDS, args['desc-field']);
    if (!codeField || !descField) {
      console.error(
        `Could not find code/description columns in ${directoryFile}. ` +
          `Saw: ${[...new Set(rows.flatMap((r) => Object.keys(r)))].join(', ')}`,
      );
      process.exit(1);
    }
    for (const row of rows) {
      const code = digitsOnly(row[codeField] ?? '');
      const description = (row[descField] ?? '').replace(/\s+/g, ' ').trim();
      if (code.length < 2 || !description) continue;
      const rate = rates.get(code);
      entries.set(code, {
        code,
        description,
        // SAC codes are the 99xx series; everything else is goods.
        kind: code.startsWith('99') ? 'SERVICES' : 'GOODS',
        gstRate: rate?.gstRate ?? 0,
        ...(rate?.cessRate ? { cessRate: rate.cessRate } : {}),
        // No rate in the schedule ⇒ navigation only. This is the mechanism
        // that keeps a chapter from ever pricing a line.
        ...(rate ? {} : { isRatable: false }),
        since: revision,
      });
    }
  }

  // A rate can be declared for a code the directory doesn't list (the
  // schedules sometimes use groupings the code list doesn't). Keep it — the
  // rate is the part that matters — with a placeholder description.
  let orphanRates = 0;
  for (const [code, rate] of rates) {
    if (entries.has(code)) continue;
    orphanRates++;
    entries.set(code, {
      code,
      description: `HSN ${code}`,
      kind: code.startsWith('99') ? 'SERVICES' : 'GOODS',
      gstRate: rate.gstRate,
      ...(rate.cessRate ? { cessRate: rate.cessRate } : {}),
      since: revision,
    });
  }

  const sorted = [...entries.values()].sort((a, b) => a.code.localeCompare(b.code));
  const ratable = sorted.filter((e) => e.isRatable !== false).length;

  const outDir = path.join(__dirname, '..', 'modules', 'hsn', 'data');
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, 'hsn.master.json');
  fs.writeFileSync(
    outPath,
    `${JSON.stringify(
      {
        revision,
        importedFrom: {
          directory: directoryFile ? path.basename(directoryFile) : null,
          rates: ratesFile ? path.basename(ratesFile) : null,
        },
        entries: sorted,
      },
      null,
      2,
    )}\n`,
  );

  console.log(
    [
      `Wrote ${sorted.length} entries to ${outPath}`,
      `  ratable (can price a line): ${ratable}`,
      `  navigation only:            ${sorted.length - ratable}`,
      orphanRates > 0 ? `  rates with no directory entry: ${orphanRates}` : null,
      '',
      'Review the diff, then commit. The seed prefers this file over the',
      'provisional hand-written manifest on the next boot.',
    ]
      .filter(Boolean)
      .join('\n'),
  );
}

main();
