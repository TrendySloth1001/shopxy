import prisma from '../../infra/db/prisma.js';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';
import { embeddingService } from './embedding.service.js';

const HINTS_CACHE_KEY = 'search:hints:top10';
const HINTS_CACHE_TTL = 300;

interface SearchHit {
  id: number;
  name: string;
  sku: string;
  selling_price: string;
  rating_avg: string | null;
  rating_count: number;
  image_url: string | null;
  shop_id: number;
  shop_name: string;
  shop_slug: string;
  rank: number;
  semantic_score?: number;
  fts_score?: number;
}

export interface SearchResult {
  query: string;
  semantic: boolean;
  results: Array<{
    id: number;
    name: string;
    sku: string;
    sellingPrice: number;
    ratingAvg: number | null;
    ratingCount: number;
    imageUrl: string | null;
    shop: { id: number; name: string; slug: string };
    rank: number;
    semanticScore?: number;
    ftsScore?: number;
  }>;
}

export interface SearchFilters {
  categoryId?: number | null;
  shopId?: number | null;
}

function canon(term: string): string {
  return term.trim().toLowerCase().slice(0, 80);
}

export class SearchService {
  async search(
    rawQuery: string,
    filters: SearchFilters,
    actor: { userId?: number | null; sessionId?: string | null },
  ): Promise<SearchResult> {
    const query = canon(rawQuery);
    if (query.length < 2) {
      return { query, semantic: false, results: [] };
    }

    const queryVector = await embeddingService.embedQuery(query);
    const useSemantic = queryVector !== null;

    const rows = useSemantic
      ? await this._hybridSearch(query, queryVector!, filters)
      : await this._ftsSearch(query, filters);

    try {
      await this._recordSearch({
        query,
        resultCount: rows.length,
        userId: actor.userId ?? null,
        sessionId: actor.sessionId ?? null,
      });
    } catch (err) {
      logger.warn(
        { err: (err as Error).message },
        'search analytics write failed',
      );
    }

    return {
      query,
      semantic: useSemantic,
      results: rows.map((r) => ({
        id: r.id,
        name: r.name,
        sku: r.sku,
        sellingPrice: Number(r.selling_price),
        ratingAvg: r.rating_avg !== null ? Number(r.rating_avg) : null,
        ratingCount: r.rating_count,
        imageUrl: r.image_url,
        shop: { id: r.shop_id, name: r.shop_name, slug: r.shop_slug },
        rank: Number(r.rank),
        semanticScore: r.semantic_score == null ? undefined : Number(r.semantic_score),
        ftsScore: r.fts_score == null ? undefined : Number(r.fts_score),
      })),
    };
  }

  private async _hybridSearch(
    query: string,
    queryVector: string,
    filters: SearchFilters,
  ): Promise<SearchHit[]> {
    const categoryId = filters.categoryId ?? null;
    const shopId = filters.shopId ?? null;
    return prisma.$queryRawUnsafe<SearchHit[]>(
      `
      WITH q AS (
        SELECT $1::vector AS qv,
               plainto_tsquery('english', $2) AS tsq
      ),
      sem AS (
        SELECT p.id,
               1 - (p.embedding <=> q.qv) AS sem_score
        FROM products p, q
        WHERE p.embedding IS NOT NULL
          AND p.is_published = true
          AND p.is_active    = true
          AND ($3::int IS NULL OR p.category_id = $3)
          AND ($4::int IS NULL OR p.shop_id     = $4)
        ORDER BY p.embedding <=> q.qv
        LIMIT 100
      ),
      fts AS (
        SELECT p.id,
               ts_rank(p.search_vector, q.tsq) AS fts_score
        FROM products p, q
        WHERE p.is_published = true
          AND p.is_active    = true
          AND p.search_vector @@ q.tsq
          AND ($3::int IS NULL OR p.category_id = $3)
          AND ($4::int IS NULL OR p.shop_id     = $4)
        ORDER BY fts_score DESC
        LIMIT 100
      ),
      candidates AS (
        SELECT id FROM sem UNION SELECT id FROM fts
      ),
      scored AS (
        SELECT c.id,
               COALESCE(s.sem_score, 0)               AS semantic_score,
               COALESCE(f.fts_score, 0)               AS fts_score,
               0.6 * COALESCE(s.sem_score, 0)
                 + 0.4 * LEAST(1.0, COALESCE(f.fts_score, 0) / 0.5)
                                                      AS combined_rank
        FROM candidates c
        LEFT JOIN sem s ON s.id = c.id
        LEFT JOIN fts f ON f.id = c.id
      )
      SELECT
        p.id              AS id,
        p.name            AS name,
        p.sku             AS sku,
        p.selling_price   AS selling_price,
        p.rating_avg      AS rating_avg,
        p.rating_count    AS rating_count,
        (
          SELECT pi.url FROM product_images pi
          WHERE pi.product_id = p.id
          ORDER BY pi.sort_order ASC LIMIT 1
        )                 AS image_url,
        s.id              AS shop_id,
        s.name            AS shop_name,
        s.slug            AS shop_slug,
        sc.combined_rank  AS rank,
        sc.semantic_score AS semantic_score,
        sc.fts_score      AS fts_score
      FROM scored sc
      JOIN products p ON p.id = sc.id
      JOIN shops    s ON s.id = p.shop_id
      WHERE p.is_published = true AND p.is_active = true AND s.is_published = true
      ORDER BY sc.combined_rank DESC, p.rating_count DESC, p.id ASC
      LIMIT 50
      `,
      queryVector,
      query,
      categoryId,
      shopId,
    );
  }

  private async _ftsSearch(
    query: string,
    filters: SearchFilters,
  ): Promise<SearchHit[]> {
    return prisma.$queryRaw<SearchHit[]>`
      SELECT
        p.id              AS id,
        p.name            AS name,
        p.sku             AS sku,
        p.selling_price   AS selling_price,
        p.rating_avg      AS rating_avg,
        p.rating_count    AS rating_count,
        (
          SELECT pi.url FROM product_images pi
          WHERE pi.product_id = p.id
          ORDER BY pi.sort_order ASC LIMIT 1
        )                 AS image_url,
        s.id              AS shop_id,
        s.name            AS shop_name,
        s.slug            AS shop_slug,
        ts_rank(p.search_vector, plainto_tsquery('english', ${query})) AS rank
      FROM products p
      JOIN shops s ON s.id = p.shop_id
      WHERE p.is_published = true
        AND p.is_active    = true
        AND s.is_published = true
        AND p.search_vector @@ plainto_tsquery('english', ${query})
        AND (${filters.categoryId ?? null}::int IS NULL OR p.category_id = ${filters.categoryId ?? null})
        AND (${filters.shopId ?? null}::int     IS NULL OR p.shop_id     = ${filters.shopId ?? null})
      ORDER BY rank DESC, p.rating_count DESC, p.id ASC
      LIMIT 50
    `;
  }

  async autocomplete(rawQuery: string) {
    const query = canon(rawQuery);
    if (query.length < 2) return { products: [], terms: [] };

    const [products, terms] = await Promise.all([
      prisma.$queryRaw<Array<{ id: number; name: string }>>`
        SELECT p.id, p.name
        FROM products p
        JOIN shops s ON s.id = p.shop_id
        WHERE p.is_published = true
          AND p.is_active    = true
          AND s.is_published = true
          AND p.search_vector @@ plainto_tsquery('english', ${query})
        ORDER BY ts_rank(p.search_vector, plainto_tsquery('english', ${query})) DESC
        LIMIT 8
      `,
      prisma.searchTerm.findMany({
        where: { term: { contains: query } },
        orderBy: [{ queryCount: 'desc' }, { lastSearchedAt: 'desc' }],
        take: 4,
        select: { term: true, queryCount: true },
      }),
    ]);

    return { products, terms };
  }

  async listHints(): Promise<Array<{ term: string; queryCount: number }>> {
    if (redisAvailable()) {
      try {
        const cached = await getRedis().get(HINTS_CACHE_KEY);
        if (cached) {
          return JSON.parse(cached) as Array<{ term: string; queryCount: number }>;
        }
      } catch (err) {
        logger.warn(
          { err: (err as Error).message },
          'search hints cache read failed',
        );
      }
    }

    const since = new Date(Date.now() - 24 * 3_600_000);
    const rows = await prisma.searchTerm.findMany({
      where: { lastSearchedAt: { gte: since } },
      orderBy: [{ queryCount: 'desc' }, { lastSearchedAt: 'desc' }],
      take: 10,
      select: { term: true, queryCount: true },
    });

    if (redisAvailable()) {
      try {
        await getRedis().set(
          HINTS_CACHE_KEY,
          JSON.stringify(rows),
          'EX',
          HINTS_CACHE_TTL,
        );
      } catch (err) {
        logger.warn(
          { err: (err as Error).message },
          'search hints cache write failed',
        );
      }
    }

    return rows;
  }

  private readonly _recentSearches = new Map<string, number>();
  private static readonly _SEARCH_DEDUPE_MS = 2_000;
  private static readonly _SEARCH_DEDUPE_MAX = 10_000;
  private static readonly _ANON_SAMPLE_RATE = 0.1;

  private _shouldRecordSearch(key: string): boolean {
    const now = Date.now();
    const last = this._recentSearches.get(key);
    if (last && now - last < SearchService._SEARCH_DEDUPE_MS) {
      return false;
    }
    if (this._recentSearches.size >= SearchService._SEARCH_DEDUPE_MAX) {
      const drop = Math.floor(SearchService._SEARCH_DEDUPE_MAX / 10);
      const iter = this._recentSearches.keys();
      for (let i = 0; i < drop; i++) {
        const k = iter.next();
        if (k.done) break;
        this._recentSearches.delete(k.value);
      }
    }
    this._recentSearches.set(key, now);
    return true;
  }

  private async _recordSearch(opts: {
    query: string;
    resultCount: number;
    userId: number | null;
    sessionId: string | null;
  }): Promise<void> {
    if (opts.userId !== null || opts.sessionId !== null) {
      const actorKey =
        opts.userId !== null ? `u:${opts.userId}` : `s:${opts.sessionId}`;
      const dedupeKey = `${actorKey}|${opts.query}`;
      if (!this._shouldRecordSearch(dedupeKey)) return;
    } else if (Math.random() >= SearchService._ANON_SAMPLE_RATE) {
      return;
    }

    await Promise.all([
      prisma.searchEvent.create({
        data: {
          userId: opts.userId,
          sessionId: opts.sessionId,
          query: opts.query,
          resultCount: opts.resultCount,
        },
      }),
      prisma.searchTerm.upsert({
        where: { term: opts.query },
        create: { term: opts.query, queryCount: 1 },
        update: {
          queryCount: { increment: 1 },
          lastSearchedAt: new Date(),
        },
      }),
    ]);
    if (redisAvailable()) {
      await getRedis()
        .del(HINTS_CACHE_KEY)
        .catch(() => undefined);
    }
  }
}

export const searchService = new SearchService();
