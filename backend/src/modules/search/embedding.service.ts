import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';

/// Dim for Ollama's `nomic-embed-text` model. Hard-coded because the
/// pgvector column type `vector(768)` is fixed at migration time —
/// switching dims is a schema change, not a code change. Override the
/// model via `OLLAMA_EMBED_MODEL` only if its dim *also* matches 768.
export const EMBEDDING_DIM = 768;
const DEFAULT_MODEL = 'nomic-embed-text';
const DEFAULT_BASE_URL = 'https://ollama.com';

/// Embedding generator backed by Ollama's `/api/embed` endpoint. We
/// target Ollama Cloud by default (`https://ollama.com`, bearer auth)
/// but `OLLAMA_BASE_URL` can point at a self-hosted instance
/// (e.g. `http://localhost:11434`) — the wire shape is identical.
///
/// Env-gated by `OLLAMA_KEY`: if it's missing the service short-
/// circuits and returns `null`, and the rest of the search stack
/// degrades cleanly to FTS-only.
///
/// Throws on transport-level failures (network down, 5xx, malformed
/// JSON) so callers can backoff. Returns null only when intentionally
/// disabled — that distinction matters for the cron, which treats
/// "no embedding for this batch" as a permanent state rather than
/// "retry in 5 minutes."
export class EmbeddingService {
  private get apiKey(): string | null {
    return process.env.OLLAMA_KEY?.trim() || null;
  }

  private get baseUrl(): string {
    return (process.env.OLLAMA_BASE_URL?.trim() || DEFAULT_BASE_URL).replace(/\/+$/, '');
  }

  private get model(): string {
    return process.env.OLLAMA_EMBED_MODEL?.trim() || DEFAULT_MODEL;
  }

  get isEnabled(): boolean {
    return this.apiKey !== null;
  }

  /// Embed a batch of inputs in one API call. Ollama's `/api/embed`
  /// accepts a string OR a string[] in the `input` field and returns
  /// `embeddings: number[][]` aligned by index — no sort step needed.
  /// Returns null when the service is disabled by env.
  async embedBatch(texts: string[]): Promise<number[][] | null> {
    if (!this.isEnabled || texts.length === 0) return texts.length === 0 ? [] : null;
    const res = await fetch(`${this.baseUrl}/api/embed`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: this.model,
        input: texts.map((t) => t.slice(0, 8000)),
      }),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`Ollama embeddings ${res.status}: ${body.slice(0, 200)}`);
    }
    const json = (await res.json()) as {
      embeddings?: number[][];
      // Self-hosted Ollama on older builds returned `embedding`
      // (singular) for single-input calls. Tolerate both shapes.
      embedding?: number[];
    };
    if (Array.isArray(json.embeddings)) return json.embeddings;
    if (Array.isArray(json.embedding)) return [json.embedding];
    throw new Error('Ollama embeddings: response missing `embeddings` field');
  }

  /// One-shot helper for query-time use: returns the query vector
  /// formatted as a pgvector literal string (`'[0.1,0.2,…]'`) so the
  /// caller can splice it into a `$queryRaw` without a second round
  /// trip. Null when disabled or on hard failure.
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

  /// Build the canonical embedding source for a product. Concatenates
  /// the columns that carry semantic intent (name + description +
  /// tags + highlights + spec rows + category name). Labelled markers
  /// stop the model from blending unrelated text together; keeping
  /// the build deterministic means a re-embed of an unchanged row
  /// produces the same vector (saves a write).
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
    // Flatten the spec JSON into "title: label=value, ..." lines.
    // Defensive: anything that doesn't match the expected shape is
    // silently skipped so a bad write can't poison the embedding.
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

  /// Embed up to [limit] products that have no embedding yet. Run
  /// from the cron tick or invoked ad-hoc from an admin endpoint.
  /// Returns the count actually processed; 0 when nothing pending
  /// or the service is disabled.
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

    // pgvector's input parser accepts the `'[v1,v2,…]'` literal. We
    // update one row at a time (the volume is bounded by `limit`).
    // A bulk UPDATE … FROM (VALUES …) is possible but the per-row
    // cost is dominated by the embedding call anyway, so the simpler
    // form wins on readability.
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

  /// Force a re-embed for one product. Called inline when the
  /// merchant edits name / description / tags so search reflects
  /// the change without waiting for the cron sweep. Idempotent —
  /// re-running is a no-op for unchanged content (same vector).
  /// Failures are logged + swallowed: a flaky embedding call must
  /// not block the underlying product write.
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

/// Pgvector's input parser is `'[0.1,0.2,...]'` (no spaces matter).
/// Exported for tests; safe to splice into `$queryRaw` because the
/// values come from the Ollama response, not user input.
///
/// SHM-1: enforce the "number-only" invariant rather than merely
/// documenting it — assert every element is a finite number before
/// formatting, so a future change that let a non-numeric value reach
/// this splice fails loudly instead of becoming an injection vector.
export function toPgVectorLiteral(v: number[]): string {
  for (const x of v) {
    if (typeof x !== 'number' || !Number.isFinite(x)) {
      throw new Error('toPgVectorLiteral: embedding contains a non-finite element');
    }
  }
  return `[${v.join(',')}]`;
}

export const embeddingService = new EmbeddingService();
