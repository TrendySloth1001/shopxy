import 'dotenv/config';
import prisma from '../src/infra/db/prisma.js';
import { CANONICAL_SLUGS } from '../src/modules/categories/catalog.seed.js';

/// One-off cleanup for category rows left behind by tests that created
/// throwaway categories via `prisma.category.create` without an
/// `afterAll` cleanup (filter-fixture-*, t-a-*, t-b-*, l-*, i-*).
/// Any slug not in CANONICAL_SLUGS is fair game — the canonical
/// taxonomy is the single source of truth; everything else is debris.
/// Product.categoryId is `onDelete: SetNull`, so deleting is safe.
async function main() {
  const all = await prisma.category.findMany({ select: { id: true, slug: true, name: true } });
  const debris = all.filter((c) => !CANONICAL_SLUGS.has(c.slug));

  if (debris.length === 0) {
    console.log('no non-canonical categories found — DB is clean');
    return;
  }

  console.log(`deleting ${debris.length} non-canonical categories:`);
  for (const c of debris) console.log(`  - [${c.id}] ${c.slug}  (${c.name})`);

  const result = await prisma.category.deleteMany({
    where: { id: { in: debris.map((c) => c.id) } },
  });
  console.log(`deleted ${result.count} rows`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
