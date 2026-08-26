import fs from 'node:fs';
import path from 'node:path';
import { HSN_RATE_RULES } from '../modules/hsn/hsn.rules.js';

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
  const repoRoot = path.join(__dirname, '..', '..', '..');
  const outPath = args.out ?? path.join(repoRoot, 'readmes', 'hsn-rates', 'rules.json');

  const rows = Object.entries(HSN_RATE_RULES).map(([code, rule]) => ({
    code,
    kind: rule.kind,
    base: 'atOrBelow' in rule ? rule.atOrBelow : null,
  }));

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(rows));

  const withBase = rows.filter((r) => r.base !== null).length;
  console.log(`hsn-rules-dump: ${rows.length} rules (${withBase} with a base rate) → ${outPath}`);
}

main();
