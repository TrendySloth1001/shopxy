import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { seedHsnMaster } from '../../src/modules/hsn/hsn.seed.js';
import { classifyService } from '../../src/modules/hsn/classify.service.js';
import { matchAliasesInText } from '../../src/modules/hsn/hsn.copy.js';
import { retrieve } from '../../src/modules/hsn/hsn.retrieval.js';

const top = async (name: string, limit = 3) =>
  (await classifyService.suggestForName({ name, limit })).suggestions;

describe('hsn — retrieval over the official tariff', () => {
  beforeAll(async () => {
    await seedHsnMaster();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('finds words that exist only in the official tariff', async () => {
    for (const [name, chapter] of [
      ['padlock', '83'],
      ['tarpaulin', '63'],
      ['umbrella', '66'],
    ] as const) {
      const hits = await top(name, 3);
      expect(hits.length, `"${name}" found nothing`).toBeGreaterThan(0);
      expect(hits[0].code.slice(0, 2), `"${name}"`).toBe(chapter);
    }
  });

  it('keeps curated vocabulary above official wording', async () => {
    for (const [name, code] of [
      ['chappal', '6402'],
      ['qameez', '6205'],
      ['sarson ka tel 1L', '1514'],
    ] as const) {
      const hits = retrieve(name, 5);
      expect(hits[0]?.code, `"${name}"`).toBe(code);
      expect(hits[0]?.layer, `"${name}"`).toBe('CURATED');
    }
    const mixed = retrieve('biscuit', 6);
    const lastCurated = mixed.map((h) => h.layer).lastIndexOf('CURATED');
    const firstTariff = mixed.map((h) => h.layer).indexOf('TARIFF');
    if (lastCurated >= 0 && firstTariff >= 0) expect(lastCurated).toBeLessThan(firstTariff);
  });

  it('offers the heading rather than four of its own sub-headings', async () => {
    const hits = retrieve('keyboard', 8);
    expect(hits.map((h) => h.code)).toContain('9201');
    expect(hits.map((h) => h.code)).not.toContain('920190');
  });

  it('does not index the tariff pointing at itself', async () => {
    for (const noise of ['elsewhere specified', 'chapter section', '8471 30']) {
      const hits = retrieve(noise, 5).filter((h) => h.layer === 'TARIFF');
      expect(hits, `"${noise}"`).toHaveLength(0);
    }
  });

  it('suggests a condition-split code, with the condition attached', async () => {
    for (const name of ['rice', 'chawal']) {
      const hits = await top(name, 3);
      expect(hits[0]?.code, `"${name}"`).toBe('1006');
      expect(hits[0]?.rateStatus, `"${name}"`).toBe('CONDITIONAL');
      expect(hits[0]?.rateNote, `"${name}"`).toMatch(/pre-packaged/i);
    }
  });

  it('suggests a heading nothing on its ladder rates', async () => {
    for (const [name, code] of [
      ['shampoo', '3305'],
      ['toothpaste', '3306'],
      ['tea', '0902'],
      ['ball pen', '9608'],
      ['biscuit', '1905'],
      ['led bulb', '9405'],
    ] as const) {
      const hits = await top(name, 3);
      expect(hits[0]?.code, `"${name}"`).toBe(code);
      expect(hits[0]?.rateStatus, `"${name}"`).toBe('NO_RATE_ON_FILE');
    }
  });

  it('never invents a rate for a code that has none', async () => {
    for (const name of ['rice', 'shampoo', 'tea', 'ball pen', 'biscuit', 'notebook', 'toothpaste']) {
      for (const hit of await top(name, 5)) {
        if (hit.rateStatus === 'RESOLVED') {
          expect(typeof hit.gstRate, `"${name}" ${hit.code}`).toBe('number');
        } else {
          expect(hit.gstRate, `"${name}" ${hit.code}`).toBeNull();
          expect(hit.cessRate, `"${name}" ${hit.code}`).toBeNull();
        }
      }
    }
  });

  it('still reports a rate the code inherits from its parent heading', async () => {
    const hits = await top('t-shirt', 3);
    expect(hits[0]?.code).toBe('6109');
    expect(hits[0]?.rateStatus).toBe('RESOLVED');
    expect(hits[0]?.gstRate).toBe(5);
  });

  it('ranks the longest matching alias, not the first one indexed', async () => {
    expect(matchAliasesInText('ball pen')[0]).toBe('9608');
    expect((await top('ball pen', 2))[0]?.code).toBe('9608');
  });

  it('answers nonsense with nothing', async () => {
    for (const junk of [
      'asdfgh',
      'qwertyuiop',
      'zzzzzzzz',
      'aaaaaaa bbbbbbb',
      'blah blah blah',
      'xyzzy plugh',
      'flying purple elephant',
      'thing that goes fast',
    ]) {
      expect(await top(junk, 3), `"${junk}"`).toHaveLength(0);
    }
  });

  it('does not let one rare modifier decide a two-word name', async () => {
    const hits = await top('wireless keyboard', 3);
    expect(hits.length).toBeGreaterThan(0);
    expect(hits[0].code.startsWith('8517')).toBe(false);
  });

  it('still refuses the biscuits coincidence at 68× the corpus', async () => {
    const hits = await top('live horses for breeding', 5);
    expect(hits.map((h) => h.code)).not.toContain('1905');
    expect(hits[0]?.code.slice(0, 2)).toBe('01');
  });
});
