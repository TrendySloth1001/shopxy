import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';
import { activeProvider, EMBEDDING_DIM } from './embedding.providers.js';

export { EMBEDDING_DIM };

export class EmbeddingService {
  get isEnabled(): boolean {
    return activeProvider().isEnabled;
  }

  get providerName(): string {
    return activeProvider().name;
  }

  async embedBatch(texts: string[]): Promise<number[][] | null> {
    return activeProvider().embedBatch(texts);
  }

  async embedQuery(query: string): Promise<string | null> {
    if (!this.isEnabled || query.trim().length === 0) return null;
    try {
      const [v] = (await this.embedBatch([query])) ?? [];
      return v ? toPgVectorLiteral(v) : null;
    } catch (e) {
      logger.warn({ err: (e as Error).message }, 'embedQuery failed; degrading to FTS');
      return null;
    }
  }

  buildProductText(p: {
    name: string;
    description: string | null;
    tags: string[];
    highlights?: string[];
    specs?: unknown;
    category?: { name: string } | null;
  }): string {
    const parts = [p.name];
    if (p.description && p.description.trim().length > 0) {
      parts.push(p.description.trim());
    }
    if (p.tags.length > 0) parts.push(`tags: ${p.tags.join(', ')}`);
    if (p.highlights && p.highlights.length > 0) {
      parts.push(`highlights: ${p.highlights.join('; ')}`);
    }
    if (Array.isArray(p.specs)) {
      for (const group of p.specs as Array<{ title?: string; rows?: Array<{ label?: string; value?: string }> }>) {
        if (!group || !Array.isArray(group.rows)) continue;
        const pairs = group.rows
          .filter((r) => typeof r?.label === 'string' && typeof r?.value === 'string')
          .map((r) => `${r.label}=${r.value}`)
          .join(', ');
        if (pairs) parts.push(`${group.title ?? 'specs'}: ${pairs}`);
      }
    }
    if (p.category?.name) parts.push(`category: ${p.category.name}`);
    return parts.join('\n');
  }

  async embedPendingProducts(limit = 50): Promise<{ embedded: number }> {
    if (!this.isEnabled) return { embedded: 0 };
    const candidates = await prisma.product.findMany({
      where: {
        isActive: true,
        embeddedAt: null,
      },
      orderBy: { updatedAt: 'desc' },
      take: limit,
      select: {
        id: true,
        name: true,
        description: true,
        tags: true,
        highlights: true,
        specs: true,
        category: { select: { name: true } },
      },
    });
    if (candidates.length === 0) return { embedded: 0 };

    const texts = candidates.map((p) => this.buildProductText(p));
    const vectors = await this.embedBatch(texts);
    if (!vectors) return { embedded: 0 };

    const now = new Date();
    for (let i = 0; i < candidates.length; i++) {
      const literal = toPgVectorLiteral(vectors[i]);
      await prisma.$executeRawUnsafe(
        `UPDATE products SET embedding = $1::vector, embedded_at = $2 WHERE id = $3`,
        literal,
        now,
        candidates[i].id,
      );
    }
    logger.info({ count: candidates.length }, 'embedding: batch done');
    return { embedded: candidates.length };
  }

  async reembedProduct(productId: number): Promise<void> {
    if (!this.isEnabled) return;
    try {
      const row = await prisma.product.findUnique({
        where: { id: productId },
        select: {
          name: true,
          description: true,
          tags: true,
          highlights: true,
          specs: true,
          category: { select: { name: true } },
        },
      });
      if (!row) return;
      const text = this.buildProductText(row);
      const vectors = await this.embedBatch([text]);
      if (!vectors || vectors.length === 0) return;
      const literal = toPgVectorLiteral(vectors[0]);
      await prisma.$executeRawUnsafe(
        `UPDATE products SET embedding = $1::vector, embedded_at = NOW() WHERE id = $2`,
        literal,
        productId,
      );
    } catch (e) {
      logger.warn(
        { productId, err: (e as Error).message },
        'reembedProduct failed; will be retried by cron',
      );
    }
  }
}

export function toPgVectorLiteral(v: number[]): string {
  for (const x of v) {
    if (typeof x !== 'number' || !Number.isFinite(x)) {
      throw new Error('toPgVectorLiteral: embedding contains a non-finite element');
    }
  }
  return `[${v.join(',')}]`;
}

export const embeddingService = new EmbeddingService();
