import 'dotenv/config';
import prisma from '../src/infra/db/prisma.js';
import { CANONICAL_SLUGS } from '../src/modules/categories/catalog.seed.js';

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
