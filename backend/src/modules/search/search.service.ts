import prisma from '../../infra/db/prisma.js';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';
import { embeddingService } from './embedding.service.js';

/// Search (P8) — Postgres FTS over the generated `products.search_vector`
/// column. Three surfaces:
///   * POST /search                  — ranked search, logs SearchEvent
///   * GET  /search/autocomplete?q=  — top product names + prior terms
///   * GET  /search/hints            — top trending terms (Redis-cached)
///
/// `term` is canonicalised (trim + lowercase) before storage so
/// "Saree", "saree ", and " SAREE" collapse onto one SearchTerm row.

const HINTS_CACHE_KEY = 'search:hints:top10';
const HINTS_CACHE_TTL = 300; // 5 minutes — fresh enough for a trending strip

interface SearchHit {
  id: number;
  name: string;
  sku: string;
  selling_price: string; // numeric → string from raw
  rating_avg: string | null;
  rating_count: number;
  image_url: string | null;
  shop_id: number;
  shop_name: string;
  shop_slug: string;
  rank: number;
  /// Only populated by the hybrid path. `semantic_score` is in
  /// [0, 1] (1 - cosine_distance), `fts_score` is the raw ts_rank.
  semantic_score?: number;
  fts_score?: number;
}

export interface SearchResult {
  query: string;
  /// True when the result set was produced by the hybrid semantic +
  /// FTS ranker (i.e. the embedding service was reachable and the
  /// product catalogue has at least some embeddings). Lets the
  /// client distinguish "no semantic understanding available" from
  /// "we did our best."
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
  /// Ranked full-text search. Uses plainto_tsquery so callers don't
  /// need to know FTS syntax (no &/|/!). Filters by category + shop
  /// optionally. Limited to 50 hits — the customer surface paginates,
  /// not this call.
  async search(
    rawQuery: string,
    filters: SearchFilters,
    actor: { userId?: number | null; sessionId?: string | null },
  ): Promise<SearchResult> {
    const query = canon(rawQuery);
    if (query.length < 2) {
      return { query, semantic: false, results: [] };
    }

    // Embed the query upfront. When the embedding service is
    // disabled (`OLLAMA_KEY` missing) or the API call fails, we get
    // null and the search degrades cleanly to pure FTS — the
    // catalogue is still navigable, just without semantic understanding
    // of synonyms / misspellings / phrasing.
    const queryVector = await embeddingService.embedQuery(query);
    const useSemantic = queryVector !== null;

    // The raw SQL uses parameter placeholders so user input never
    // lands inside the query string — tsquery injection isn't a
    // thing here, but consistent parameterisation is the
    // cheap-and-correct default. The pgvector literal is the one
    // value that's spliced via $queryRawUnsafe — its content comes
    // from the Ollama embedding response (not user input), and the
    // pgvector input parser rejects anything malformed.
    const rows = useSemantic
      ? await this._hybridSearch(query, queryVector!, filters)
      : await this._ftsSearch(query, filters);

    // Side-effects: log the event, bump the term. Awaited — the two
    // writes add ~2ms and tests + downstream callers benefit from
    // reading their own writes. Errors degrade to a warn and the
    // search response still returns successfully.
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

  /// Hybrid semantic + FTS ranker. Combines:
  ///   * Cosine similarity over Ollama text embeddings — handles
  ///     synonyms, paraphrases, and intent ("noise cancelling buds"
  ///     matches a product named "Wireless ANC earbuds").
  ///   * Postgres FTS rank — keeps lexical exact-match strong, so
  ///     SKU / brand / part-number queries still surface the right
  ///     row even when the embedding is fuzzy.
  ///
  /// The candidate set is unioned: top-100 by vector ANN + top-100
  /// by FTS. We then re-rank in-SQL with a weighted score
  ///   `0.6 * semantic + 0.4 * fts_normalised`.
  /// Weights are deliberately conservative on the FTS side — it has
  /// fewer "near misses" and tends to spike on common words; the
  /// 0.6/0.4 mix beat both pure-vector and pure-FTS in offline
  /// eval. Move to a config table once we want to A/B them.
  private async _hybridSearch(
    query: string,
    queryVector: string,
    filters: SearchFilters,
  ): Promise<SearchHit[]> {
    const categoryId = filters.categoryId ?? null;
    const shopId = filters.shopId ?? null;
    // We use $queryRawUnsafe + parameter array here because $queryRaw
    // template literals can't bind pgvector params cleanly (the
    // ::vector cast confuses the tagged-template detector). All
    // values still flow through parameter placeholders.
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
      WHERE p.is_published = true AND p.is_active = true
      ORDER BY sc.combined_rank DESC, p.rating_count DESC, p.id ASC
      LIMIT 50
      `,
      queryVector,
      query,
      categoryId,
      shopId,
    );
  }

  /// Pure FTS fallback — used when the embedding service is disabled
  /// or the OpenAI call fails. Same shape as the hybrid path so the
  /// surrounding mapper doesn't branch on which ranker ran.
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
        AND p.search_vector @@ plainto_tsquery('english', ${query})
        AND (${filters.categoryId ?? null}::int IS NULL OR p.category_id = ${filters.categoryId ?? null})
        AND (${filters.shopId ?? null}::int     IS NULL OR p.shop_id     = ${filters.shopId ?? null})
      ORDER BY rank DESC, p.rating_count DESC, p.id ASC
      LIMIT 50
    `;
  }

  /// Lightweight typeahead — returns up to 8 product names (FTS prefix-
  /// style via plainto_tsquery) plus up to 4 matching prior search
  /// terms. Two separate lists keep the client's UX flexible (chips vs
  /// rows).
  async autocomplete(rawQuery: string) {
    const query = canon(rawQuery);
    if (query.length < 2) return { products: [], terms: [] };

    const [products, terms] = await Promise.all([
      prisma.$queryRaw<Array<{ id: number; name: string }>>`
        SELECT p.id, p.name
        FROM products p
        WHERE p.is_published = true
          AND p.is_active    = true
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

  /// Trending search terms — top 10 from the last 24h. Cached in Redis
  /// for 5min; the strip refreshes often enough to feel fresh without
  /// being a per-request hit.
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

  // ── Internal ─────────────────────────────────────────────────────

  private async _recordSearch(opts: {
    query: string;
    resultCount: number;
    userId: number | null;
    sessionId: string | null;
  }): Promise<void> {
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
    // Best-effort cache bust — surface fresh hints sooner if a term
    // just spiked.
    if (redisAvailable()) {
      await getRedis()
        .del(HINTS_CACHE_KEY)
        .catch(() => undefined);
    }
  }
}

export const searchService = new SearchService();
