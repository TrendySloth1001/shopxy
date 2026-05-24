import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';
import { CANONICAL_CATEGORIES, flattenCanonical } from './catalog.seed.js';

/// Boot-time idempotent upsert of the canonical taxonomy. Runs on
/// every server start so a manifest edit ships with the next deploy —
/// no separate migration step. Safe to call concurrently because each
/// upsert is keyed on the unique `slug` column.
///
/// Two-pass:
///   1. Upsert all rows with `parentId = null` so every node exists
///      and has a real database id we can reference.
///   2. Backfill `parentId` from the manifest's `parentSlug` field.
///
/// Removed entries are NOT deleted (deleting a category would break
/// the FK from products); instead callers can mark them `isActive=false`
/// out of band and the customer-side filters drop them.
export async function seedCanonicalCategories(): Promise<{
  upserted: number;
  total: number;
}> {
  const flat = Array.from(flattenCanonical());
  let upserted = 0;

  // Pass 1: ensure every node exists, ignoring parentage.
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

  // Pass 2: lookup ids, then wire parents. Doing it after pass 1
  // means a brand-new install gets parent links on the very first
  // boot without us having to topologically pre-sort the manifest.
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
