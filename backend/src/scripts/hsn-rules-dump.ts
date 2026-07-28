import fs from 'node:fs';
import path from 'node:path';
import { HSN_RATE_RULES } from '../modules/hsn/hsn.rules.js';

/// Export the price-threshold rules as JSON, for `hsn-rates-extract.py`.
///
///   npm run hsn:rules-dump -- --out ../readmes/hsn-rates/rules.json
///
/// ── Why this exists ─────────────────────────────────────────────────────
/// The rate schedules declare apparel, made-up textiles, footwear and hotel
/// accommodation as a *pair* of rates split by a price threshold ("of sale
/// value not exceeding Rs 2500 per piece" → 5%, above → 18%). To the
/// extractor those codes look exactly like conditional rice: one code, two
/// rates, no way to choose. Withheld on that basis, a T-shirt cannot price a
/// line at all — which is what happened before this file existed.
///
/// The difference is that this particular condition IS evaluable: it is the
/// selling price, which the product already carries, and `hsn.rules.ts`
/// already models it. So the extractor emits these codes at the rule's *base*
/// rate (`atOrBelow`) and the overlay refines them at resolve time.
///
/// `hsn.rules.ts` is the single source of truth for which codes those are.
/// This script only reads it — it never authors a rate, and the extractor
/// cross-checks every base it is handed against the rates actually printed in
/// the schedules, so a drift between the two is reported rather than trusted.
///
/// Kept as a TypeScript dump rather than having the Python regex-scrape
/// `hsn.rules.ts`: the rule table is real code (shared consts, spread
/// operators), and text-scraping it would silently go stale the first time
/// someone refactors it.

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

function main(): void {
  const args = parseArgs(process.argv.slice(2));
  // Default alongside the extractor's default --out-dir. `readmes/` is
  // gitignored: these are regenerable build inputs, not source.
  const repoRoot = path.join(__dirname, '..', '..', '..');
  const outPath = args.out ?? path.join(repoRoot, 'readmes', 'hsn-rates', 'rules.json');

  const rows = Object.entries(HSN_RATE_RULES).map(([code, rule]) => ({
    code,
    kind: rule.kind,
    // The rate that applies at or below the threshold — the base the
    // extractor emits. `null` for any future rule kind that has no such
    // notion; the extractor skips those rather than guessing.
    base: 'atOrBelow' in rule ? rule.atOrBelow : null,
  }));

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(rows));

  const withBase = rows.filter((r) => r.base !== null).length;
  console.log(`hsn-rules-dump: ${rows.length} rules (${withBase} with a base rate) → ${outPath}`);
}

main();
