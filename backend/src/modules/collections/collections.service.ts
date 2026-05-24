import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';

/// Editorial collections (P4) — admin-curated product lists rendered as
/// rails / dedicated pages on the customer surface. Slug-keyed for
/// stable URLs across title edits; uniqueness is enforced by an index
/// and the auto-suffix loop in `uniqueSlug`.

function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

async function uniqueSlug(base: string, excludeId?: number): Promise<string> {
  let candidate = base || 'collection';
  let suffix = 1;
  for (;;) {
    const existing = await prisma.collection.findUnique({
      where: { slug: candidate },
      select: { id: true },
    });
    if (!existing || existing.id === excludeId) return candidate;
    suffix += 1;
    candidate = `${base}-${suffix}`;
  }
}

const adminSelect = {
  id: true,
  slug: true,
  title: true,
  eyebrow: true,
  subtitle: true,
  ctaText: true,
  ctaTarget: true,
  coverImageUrl: true,
  bgColor: true,
  isPublished: true,
  sortOrder: true,
  createdAt: true,
  updatedAt: true,
  _count: { select: { items: true } },
} as const;

const itemPublicSelect = {
  id: true,
  position: true,
  product: {
    select: {
      id: true,
      name: true,
      sku: true,
      mrp: true,
      sellingPrice: true,
      ratingAvg: true,
      ratingCount: true,
      isPublished: true,
      shop: { select: { id: true, name: true, slug: true } },
      images: {
        select: { id: true, url: true, sortOrder: true },
        orderBy: { sortOrder: 'asc' },
      },
    },
  },
} as const;

export interface CreateCollectionInput {
  title: string;
  slug?: string;
  eyebrow?: string | null;
  subtitle?: string | null;
  ctaText?: string | null;
  ctaTarget?: string | null;
  coverImageUrl?: string | null;
  bgColor?: string | null;
  isPublished?: boolean;
  sortOrder?: number;
}

export interface UpdateCollectionInput extends Partial<CreateCollectionInput> {}

export class CollectionsService {
  // ── Admin CRUD ───────────────────────────────────────────────────

  async listForAdmin(opts: { cursor?: number; limit?: number } = {}) {
    const limit = Math.min(100, Math.max(1, opts.limit ?? 50));
    const rows = await prisma.collection.findMany({
      orderBy: [{ sortOrder: 'asc' }, { id: 'desc' }],
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
      take: limit + 1,
      select: adminSelect,
    });
    const hasMore = rows.length > limit;
    const data = hasMore ? rows.slice(0, limit) : rows;
    return { data, nextCursor: hasMore ? data[data.length - 1].id : null };
  }

  async getByIdForAdmin(id: number) {
    return prisma.collection.findUnique({
      where: { id },
      select: {
        ...adminSelect,
        items: {
          orderBy: [{ position: 'asc' }, { id: 'asc' }],
          select: itemPublicSelect,
        },
      },
    });
  }

  async create(input: CreateCollectionInput) {
    const base = input.slug ? slugify(input.slug) : slugify(input.title);
    const slug = await uniqueSlug(base);
    return prisma.collection.create({
      data: {
        slug,
        title: input.title,
        eyebrow: input.eyebrow ?? null,
        subtitle: input.subtitle ?? null,
        ctaText: input.ctaText ?? null,
        ctaTarget: input.ctaTarget ?? null,
        coverImageUrl: input.coverImageUrl ?? null,
        bgColor: input.bgColor ?? null,
        isPublished: input.isPublished ?? false,
        sortOrder: input.sortOrder ?? 0,
      },
      select: adminSelect,
    });
  }

  async update(id: number, input: UpdateCollectionInput) {
    const existing = await prisma.collection.findUnique({
      where: { id },
      select: { title: true, slug: true },
    });
    if (!existing) return null;

    // Slug only changes if explicitly supplied — title edits don't
    // re-slug (we don't want URL churn the way categories do).
    let slug: string | undefined;
    if (input.slug !== undefined) {
      const base = slugify(input.slug);
      slug = await uniqueSlug(base, id);
    }

    return prisma.collection.update({
      where: { id },
      data: {
        ...(slug !== undefined && { slug }),
        ...(input.title !== undefined && { title: input.title }),
        ...(input.eyebrow !== undefined && { eyebrow: input.eyebrow }),
        ...(input.subtitle !== undefined && { subtitle: input.subtitle }),
        ...(input.ctaText !== undefined && { ctaText: input.ctaText }),
        ...(input.ctaTarget !== undefined && { ctaTarget: input.ctaTarget }),
        ...(input.coverImageUrl !== undefined && { coverImageUrl: input.coverImageUrl }),
        ...(input.bgColor !== undefined && { bgColor: input.bgColor }),
        ...(input.isPublished !== undefined && { isPublished: input.isPublished }),
        ...(input.sortOrder !== undefined && { sortOrder: input.sortOrder }),
      },
      select: adminSelect,
    });
  }

  async delete(id: number): Promise<boolean> {
    try {
      await prisma.collection.delete({ where: { id } });
      return true;
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2025') return false;
      throw e;
    }
  }

  // ── Items ────────────────────────────────────────────────────────

  /// Replace the full item list in one transaction. Simpler + safer
  /// than diffing on the client: small N (curated lists rarely exceed
  /// a few dozen) makes the cost trivial.
  async replaceItems(
    collectionId: number,
    items: Array<{ productId: number; position: number }>,
  ) {
    const exists = await prisma.collection.findUnique({
      where: { id: collectionId },
      select: { id: true },
    });
    if (!exists) return null;

    // Verify every product exists; surface a 400 (via thrown error) if
    // any is missing — the admin UI shouldn't be picking ghost ids.
    const productIds = items.map((i) => i.productId);
    if (productIds.length > 0) {
      const found = await prisma.product.findMany({
        where: { id: { in: productIds } },
        select: { id: true },
      });
      if (found.length !== new Set(productIds).size) {
        const err = new Error('One or more productIds do not exist');
        (err as Error & { code?: string }).code = 'INVALID_PRODUCTS';
        throw err;
      }
    }

    await prisma.$transaction([
      prisma.collectionItem.deleteMany({ where: { collectionId } }),
      ...(items.length > 0
        ? [
            prisma.collectionItem.createMany({
              data: items.map((i) => ({
                collectionId,
                productId: i.productId,
                position: i.position,
              })),
            }),
          ]
        : []),
    ]);

    return prisma.collectionItem.findMany({
      where: { collectionId },
      orderBy: [{ position: 'asc' }, { id: 'asc' }],
      select: itemPublicSelect,
    });
  }

  // ── Public ───────────────────────────────────────────────────────

  async listPublished() {
    return prisma.collection.findMany({
      where: { isPublished: true },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
      select: {
        id: true,
        slug: true,
        title: true,
        eyebrow: true,
        subtitle: true,
        ctaText: true,
        ctaTarget: true,
        coverImageUrl: true,
        bgColor: true,
        _count: { select: { items: true } },
      },
    });
  }

  /// Public detail by slug. Only published collections are visible; an
  /// unpublished collection looks identical to a non-existent one
  /// (no info leak). Items paged via `cursor` on the item id.
  async getBySlug(slug: string, opts: { cursor?: number; limit?: number } = {}) {
    const collection = await prisma.collection.findUnique({
      where: { slug },
      select: {
        id: true,
        slug: true,
        title: true,
        eyebrow: true,
        subtitle: true,
        ctaText: true,
        ctaTarget: true,
        coverImageUrl: true,
        bgColor: true,
        isPublished: true,
      },
    });
    if (!collection || !collection.isPublished) return null;

    const limit = Math.min(100, Math.max(1, opts.limit ?? 30));
    const items = await prisma.collectionItem.findMany({
      where: { collectionId: collection.id },
      orderBy: [{ position: 'asc' }, { id: 'asc' }],
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
      take: limit + 1,
      select: itemPublicSelect,
    });
    const hasMore = items.length > limit;
    const data = hasMore ? items.slice(0, limit) : items;

    const { isPublished: _unused, ...publicMeta } = collection;
    return {
      ...publicMeta,
      items: data,
      nextCursor: hasMore ? data[data.length - 1].id : null,
    };
  }

  /// Cross-shop product search for the admin curator. Returns light
  /// product summaries (id, name, sku, shop name) so the editor's
  /// autocomplete picker can show one row per match without separate
  /// joins on the client. Limited to 20 hits per query — the picker is
  /// a "find the right one" UX, not a browse surface.
  async adminSearchProducts(q: string) {
    const needle = q.trim();
    if (needle.length < 2) return [];
    return prisma.product.findMany({
      where: {
        OR: [
          { name: { contains: needle, mode: 'insensitive' } },
          { sku: { contains: needle, mode: 'insensitive' } },
        ],
        isActive: true,
      },
      orderBy: [{ name: 'asc' }],
      take: 20,
      select: {
        id: true,
        name: true,
        sku: true,
        sellingPrice: true,
        isPublished: true,
        shop: { select: { id: true, name: true, slug: true } },
        images: {
          select: { url: true, sortOrder: true },
          orderBy: { sortOrder: 'asc' },
          take: 1,
        },
      },
    });
  }
}

export const collectionsService = new CollectionsService();
