import { logger } from '../../shared/logging/logger.js';

export const EMBEDDING_DIM = 768;

export interface EmbeddingProvider {
  readonly name: string;
  readonly isEnabled: boolean;
  embedBatch(texts: string[]): Promise<number[][] | null>;
}

function normalize(v: number[]): number[] {
  let sum = 0;
  for (const x of v) sum += x * x;
  const len = Math.sqrt(sum);
  if (!Number.isFinite(len) || len === 0) return v;
  return v.map((x) => x / len);
}

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
        throw new Error(
          `Gemini embeddings: expected ${EMBEDDING_DIM} dims, got ${v.length}. ` +
            `Set GEMINI_EMBED_MODEL to a model that supports outputDimensionality.`,
        );
      }
    }
    return raw.map(normalize);
  }
}

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
    const raw = json.embeddings ?? (json.embedding ? [json.embedding] : null);
    if (!raw) throw new Error('Ollama embeddings: response missing `embeddings`');
    return raw.map(normalize);
  }
}

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

export function describeProvider(): { name: string; enabled: boolean } {
  const p = activeProvider();
  if (!warned) {
    warned = true;
    logger.info({ provider: p.name, enabled: p.isEnabled, dim: EMBEDDING_DIM }, 'embeddings: provider selected');
  }
  return { name: p.name, enabled: p.isEnabled };
}
