import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import { codesWithCopy, embeddingTextFor } from '../modules/hsn/hsn.copy.js';
import { embeddingService } from '../modules/search/embedding.service.js';
import { EMBEDDING_DIM } from '../modules/search/embedding.providers.js';

/// Generate the precomputed HSN code vectors used for semantic suggestions.
///
///   npm run hsn:embed
///
/// Run this offline whenever the copy catalogues change, and commit the
/// result. Embedding ~100 codes is one batched API call; doing it at boot
/// instead would mean every instance of every deploy paying for the same
/// vectors, and a cold start that depends on a third-party API being up.
///
/// The output is deterministic given the same input and model — codes are
/// sorted, floats are written at fixed precision — so a re-run with no copy
/// changes produces a byte-identical file and an empty diff.
///
/// Requires an embedding key (`GEMINI_API_KEY`, or `OLLAMA_KEY` for the older
/// backend). Without one the script exits without writing, and semantic
/// suggestions simply stay off — the alias index still answers the queries
/// that matter most, so this is a genuine nice-to-have rather than a blocker.
///
/// **On quota:** `batchEmbedContents` bills one request *per input*, so a free
/// key's per-minute and per-day ceilings arrive fast. The batch size and pacing
/// below are set for a free tier; if you hit a daily limit, wait for the reset
/// and re-run — the script is all-or-nothing (it writes only after every batch
/// succeeds), so a re-run starts clean rather than leaving a half-built file.

const OUT_PATH = path.join(__dirname, '..', 'modules', 'hsn', 'copy', 'hsn.vectors.json');

/// Batch size. Kept small because a `batchEmbedContents` call bills one
/// request *per input* against the quota, so a 64-item batch trips the free
/// tier's per-minute limit immediately. Override with HSN_EMBED_BATCH.
const BATCH = Number(process.env.HSN_EMBED_BATCH) || 8;

/// Gap between batches, to stay under the per-minute request ceiling.
const PACE_MS = Number(process.env.HSN_EMBED_PACE_MS) || 1500;

/// Retries for a 429. Quota resets on a rolling window, so backing off and
/// retrying is the difference between "works on a free key" and "needs
/// billing enabled".
const MAX_RETRIES = 5;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/// Embed one batch, backing off on quota errors. Anything that isn't a 429
/// throws immediately — a bad key or a wrong model won't fix itself by
/// waiting, and silently retrying would just hide it.
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

/// 6 decimals is well below the noise floor of a normalised embedding and
/// roughly halves the file versus full float printing.
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
      // Misalignment would silently attach the wrong vector to a code, which
      // is worse than no vectors at all.
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
