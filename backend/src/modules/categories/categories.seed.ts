import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';
import { CANONICAL_CATEGORIES, flattenCanonical } from './catalog.seed.js';

export async function seedCanonicalCategories(): Promise<{
  upserted: number;
  total: number;
}> {
  const flat = Array.from(flattenCanonical());
  let upserted = 0;

  for (const node of flat) {
    await prisma.category.upsert({
      where: { slug: node.slug },
      create: {
        slug: node.slug,
        name: node.name,
        iconName: node.iconName,
        imageUrl: node.imageUrl,
        sortOrder: node.sortOrder,
        isActive: true,
      },
      update: {
        name: node.name,
        iconName: node.iconName,
        imageUrl: node.imageUrl,
        sortOrder: node.sortOrder,
        isActive: true,
      },
    });
    upserted += 1;
  }

  const slugToId = new Map<string, number>();
  const rows = await prisma.category.findMany({
    where: { slug: { in: flat.map((n) => n.slug) } },
    select: { id: true, slug: true },
  });
  for (const r of rows) slugToId.set(r.slug, r.id);

  for (const node of flat) {
    const parentId = node.parentSlug ? slugToId.get(node.parentSlug) ?? null : null;
    await prisma.category.update({
      where: { slug: node.slug },
      data: { parentId },
    });
  }

  logger.info(
    { upserted, parents: CANONICAL_CATEGORIES.length },
    'categories: canonical taxonomy seeded',
  );
  return { upserted, total: flat.length };
}
