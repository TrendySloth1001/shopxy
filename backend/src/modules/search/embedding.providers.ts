import { logger } from '../../shared/logging/logger.js';

/// Pluggable embedding backends behind one interface.
///
/// The pgvector column is `vector(768)` and its width is fixed at migration
/// time, so **every provider here must emit 768 dimensions**. That's not a
/// stylistic constraint: a provider returning 1024 would fail every insert at
/// runtime rather than at startup. Gemini's embedding model takes an explicit
/// output width, which is why it can slot in beside Ollama's `nomic-embed-text`
/// without re-embedding the entire product catalogue.

export const EMBEDDING_DIM = 768;

export interface EmbeddingProvider {
  readonly name: string;
  readonly isEnabled: boolean;
  /// Embed a batch in one call. Order-preserving. Throws on transport failure
  /// so callers can back off; returns null only when disabled by config, which
  /// is a permanent state rather than something to retry.
  embedBatch(texts: string[]): Promise<number[][] | null>;
}

/// Reducing an embedding's width truncates it, which leaves the vector no
/// longer unit-length. Cosine similarity doesn't care about magnitude, but the
/// stored vectors are also compared with pgvector's `<=>`, and mixing
/// normalised and un-normalised rows would make distances incomparable across
/// providers. Normalising everything on the way out removes the question.
function normalize(v: number[]): number[] {
  let sum = 0;
  for (const x of v) sum += x * x;
  const len = Math.sqrt(sum);
  if (!Number.isFinite(len) || len === 0) return v;
  return v.map((x) => x / len);
}

/// Google Gemini embeddings via the Generative Language API.
///
/// `outputDimensionality` is pinned to 768 to match the column. The response
/// shape differs between the single and batch endpoints (and has changed
/// across API versions), so both `embedding.values` and `embeddings[].values`
/// are accepted rather than assuming one.
export class GeminiEmbeddingProvider implements EmbeddingProvider {
  readonly name = 'gemini';

  private get apiKey(): string | null {
    return process.env.GEMINI_API_KEY?.trim() || null;
  }

  private get model(): string {
    return process.env.GEMINI_EMBED_MODEL?.trim() || 'gemini-embedding-001';
  }

  private get baseUrl(): string {
    return (
      process.env.GEMINI_BASE_URL?.trim() || 'https://generativelanguage.googleapis.com/v1beta'
    ).replace(/\/+$/, '');
  }

  get isEnabled(): boolean {
    return this.apiKey !== null;
  }

  async embedBatch(texts: string[]): Promise<number[][] | null> {
    if (texts.length === 0) return [];
    if (!this.isEnabled) return null;

    const model = `models/${this.model.replace(/^models\//, '')}`;
    const res = await fetch(`${this.baseUrl}/${model}:batchEmbedContents`, {
      method: 'POST',
      headers: {
        'x-goog-api-key': this.apiKey!,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        requests: texts.map((t) => ({
          model,
          // 8k chars is well inside the model's token budget and stops a
          // pathological description from blowing the request up.
          content: { parts: [{ text: t.slice(0, 8000) }] },
          outputDimensionality: EMBEDDING_DIM,
        })),
      }),
    });

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`Gemini embeddings ${res.status}: ${body.slice(0, 200)}`);
    }
    const json = (await res.json()) as {
      embeddings?: Array<{ values?: number[] }>;
      embedding?: { values?: number[] };
    };
    const raw = json.embeddings
      ? json.embeddings.map((e) => e.values ?? [])
      : json.embedding?.values
        ? [json.embedding.values]
        : null;
    if (!raw) throw new Error('Gemini embeddings: response missing `embeddings`');

    for (const v of raw) {
      if (v.length !== EMBEDDING_DIM) {
        // Fail loudly here rather than at the pgvector insert, where the error
        // would surface as an opaque type mismatch far from the cause.
        throw new Error(
          `Gemini embeddings: expected ${EMBEDDING_DIM} dims, got ${v.length}. ` +
            `Set GEMINI_EMBED_MODEL to a model that supports outputDimensionality.`,
        );
      }
    }
    return raw.map(normalize);
  }
}

/// Ollama (cloud or self-hosted), the original backend. Kept so an existing
/// deployment keeps working untouched when no Gemini key is configured.
export class OllamaEmbeddingProvider implements EmbeddingProvider {
  readonly name = 'ollama';

  private get apiKey(): string | null {
    return process.env.OLLAMA_KEY?.trim() || null;
  }

  private get baseUrl(): string {
    return (process.env.OLLAMA_BASE_URL?.trim() || 'https://ollama.com').replace(/\/+$/, '');
  }

  private get model(): string {
    return process.env.OLLAMA_EMBED_MODEL?.trim() || 'nomic-embed-text';
  }

  get isEnabled(): boolean {
    return this.apiKey !== null;
  }

  async embedBatch(texts: string[]): Promise<number[][] | null> {
    if (texts.length === 0) return [];
    if (!this.isEnabled) return null;
    const res = await fetch(`${this.baseUrl}/api/embed`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ model: this.model, input: texts.map((t) => t.slice(0, 8000)) }),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`Ollama embeddings ${res.status}: ${body.slice(0, 200)}`);
    }
    const json = (await res.json()) as { embeddings?: number[][]; embedding?: number[] };
    // Older self-hosted builds return `embedding` (singular) for one input.
    const raw = json.embeddings ?? (json.embedding ? [json.embedding] : null);
    if (!raw) throw new Error('Ollama embeddings: response missing `embeddings`');
    return raw.map(normalize);
  }
}

/// Gemini wins when its key is set; Ollama is the fallback; neither configured
/// means embeddings are off and every caller degrades to lexical matching.
/// Resolved per call rather than cached so a key added to the environment on a
/// dev restart takes effect without a code change.
export function activeProvider(): EmbeddingProvider {
  const gemini = new GeminiEmbeddingProvider();
  if (gemini.isEnabled) return gemini;
  const ollama = new OllamaEmbeddingProvider();
  if (ollama.isEnabled) return ollama;
  return {
    name: 'disabled',
    isEnabled: false,
    async embedBatch(texts: string[]) {
      return texts.length === 0 ? [] : null;
    },
  };
}

let warned = false;

/// One place for "is this on, and which one is it" so callers don't each
/// re-derive it. Logs the choice once per process.
export function describeProvider(): { name: string; enabled: boolean } {
  const p = activeProvider();
  if (!warned) {
    warned = true;
    logger.info({ provider: p.name, enabled: p.isEnabled, dim: EMBEDDING_DIM }, 'embeddings: provider selected');
  }
  return { name: p.name, enabled: p.isEnabled };
}
