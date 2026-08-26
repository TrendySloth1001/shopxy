import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { request as httpsRequest } from 'https';
import {
  uploadImageWithVariants,
  urlFor,
  deleteImageVariants,
  ensureBucket,
} from '../../src/modules/upload/upload.service.js';
import prisma from '../../src/infra/db/prisma.js';

async function fetchBuffer(url: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    httpsRequest(url, (res) => {
      const chunks: Buffer[] = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    })
      .on('error', reject)
      .end();
  });
}

const SOURCE_URL =
  'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=1200&q=85';

describe('image pipeline', () => {
  let sourceBuffer: Buffer;
  const createdIds: string[] = [];

  beforeAll(async () => {
    await ensureBucket();
    sourceBuffer = await fetchBuffer(SOURCE_URL);
    expect(sourceBuffer.length).toBeGreaterThan(50_000);
  }, 30_000);

  afterAll(async () => {
    await Promise.all(createdIds.map((id) => deleteImageVariants(id)));
    await prisma.$disconnect();
  });

  it('produces three WebP variants with the right size shape', async () => {
    const result = await uploadImageWithVariants(sourceBuffer, 'phone.jpg');
    createdIds.push(result.id);

    expect(result.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(result.url).toBe(result.variants.md);
    for (const v of ['sm', 'md', 'lg'] as const) {
      expect(result.variants[v]).toBe(`/images/${result.id}-${v}.webp`);
    }
  });

  it('shrinks bytes substantially — sm < md < lg < source', async () => {
    const result = await uploadImageWithVariants(sourceBuffer, 'phone.jpg');
    createdIds.push(result.id);

    const { getFileStream } = await import(
      '../../src/modules/upload/upload.service.js'
    );

    async function bytes(key: string): Promise<number> {
      const file = await getFileStream(key);
      if (!file) throw new Error(`missing ${key}`);
      const chunks: Buffer[] = [];
      for await (const chunk of file.stream) chunks.push(chunk as Buffer);
      return Buffer.concat(chunks).length;
    }

    const [sm, md, lg] = await Promise.all([
      bytes(`${result.id}-sm.webp`),
      bytes(`${result.id}-md.webp`),
      bytes(`${result.id}-lg.webp`),
    ]);

    expect(sm).toBeLessThan(md);
    expect(md).toBeLessThan(lg);
    expect(lg).toBeLessThan(sourceBuffer.length);
    expect(lg).toBeLessThan(sourceBuffer.length * 0.7);
  });

  it('urlFor swaps the size token without re-querying storage', () => {
    const md = '/images/abc-123-md.webp';
    expect(urlFor(md, 'sm')).toBe('/images/abc-123-sm.webp');
    expect(urlFor(md, 'lg')).toBe('/images/abc-123-lg.webp');
    expect(urlFor(md, 'md')).toBe(md);
  });

  it('urlFor passes through legacy / non-variant URLs unchanged', () => {
    const legacy = '/images/legacy-image.jpg';
    expect(urlFor(legacy, 'sm')).toBe(legacy);

    const external = 'https://cdn.example.com/x.png';
    expect(urlFor(external, 'lg')).toBe(external);
  });
});
