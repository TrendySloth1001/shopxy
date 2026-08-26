import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import { codesWithCopy, embeddingTextFor } from '../modules/hsn/hsn.copy.js';
import { embeddingService } from '../modules/search/embedding.service.js';
import { EMBEDDING_DIM } from '../modules/search/embedding.providers.js';

const OUT_PATH = path.join(__dirname, '..', 'modules', 'hsn', 'copy', 'hsn.vectors.json');

const BATCH = Number(process.env.HSN_EMBED_BATCH) || 8;

const PACE_MS = Number(process.env.HSN_EMBED_PACE_MS) || 1500;

const MAX_RETRIES = 5;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function embedWithRetry(texts: string[]): Promise<number[][] | null> {
  let delay = 4000;
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      return await embeddingService.embedBatch(texts);
    } catch (e) {
      const message = (e as Error).message;
      const isQuota = message.includes('429') || message.toLowerCase().includes('quota');
      if (!isQuota || attempt === MAX_RETRIES) throw e;
      console.log(`  rate limited; waiting ${Math.round(delay / 1000)}s…`);
      await sleep(delay);
      delay = Math.min(delay * 2, 60000);
    }
  }
  return null;
}

const PRECISION = 6;

async function main(): Promise<void> {
  if (!embeddingService.isEnabled) {
    console.error(
      'No embedding provider configured. Set GEMINI_API_KEY (preferred) or OLLAMA_KEY in backend/.env.',
    );
    process.exit(1);
  }

  const codes = codesWithCopy();
  if (codes.length === 0) {
    console.error('No codes carry copy — nothing to embed.');
    process.exit(1);
  }

  console.log(`Embedding ${codes.length} codes via ${embeddingService.providerName}…`);
  const vectors: Record<string, number[]> = {};

  for (let i = 0; i < codes.length; i += BATCH) {
    if (i > 0) await sleep(PACE_MS);
    const slice = codes.slice(i, i + BATCH);
    const texts = slice.map((c) => embeddingTextFor(c));
    const embedded = await embedWithRetry(texts);
    if (!embedded) {
      console.error('Provider returned no embeddings; aborting without writing.');
      process.exit(1);
    }
    if (embedded.length !== slice.length) {
      console.error(
        `Provider returned ${embedded.length} vectors for ${slice.length} inputs; aborting.`,
      );
      process.exit(1);
    }
    slice.forEach((code, j) => {
      vectors[code] = Array.from(embedded[j], (v) => Number(v.toFixed(PRECISION)));
    });
    console.log(`  ${Math.min(i + BATCH, codes.length)}/${codes.length}`);
  }

  const payload = {
    model: embeddingService.providerName,
    dim: EMBEDDING_DIM,
    generatedFrom: 'hsn.copy.*.json',
    vectors: Object.fromEntries(Object.keys(vectors).sort().map((c) => [c, vectors[c]])),
  };
  fs.writeFileSync(OUT_PATH, `${JSON.stringify(payload)}\n`);
  const kb = Math.round(fs.statSync(OUT_PATH).size / 1024);
  console.log(`Wrote ${Object.keys(vectors).length} vectors to ${OUT_PATH} (${kb} KB).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
