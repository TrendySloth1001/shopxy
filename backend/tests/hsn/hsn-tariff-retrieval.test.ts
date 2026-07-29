import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { seedHsnMaster } from '../../src/modules/hsn/hsn.seed.js';
import { classifyService } from '../../src/modules/hsn/classify.service.js';
import { matchAliasesInText } from '../../src/modules/hsn/hsn.copy.js';
import { retrieve } from '../../src/modules/hsn/hsn.retrieval.js';

/// Searching the whole tariff, and offering the codes that carry no rate.
///
/// Two defects met here and made a general store unsearchable:
///
///   - The retrieval index was built only from the 101-entry copy catalogue,
///     so "keyboard" and "tyre" — words that appear in the imported tariff and
///     nowhere in the curated copy — found nothing at all.
///   - Suggestions were hydrated through `describeCodes`, which answers only
///     for `isRatable` rows. Rice, tea, shampoo, biscuits, pens and lamps are
///     all headings the import left unrated, so all of them vanished.
///
/// The fix for the second must never become "pick a plausible rate". Every
/// assertion about an unrated code below checks that the rate is **absent**.

const top = async (name: string, limit = 3) =>
  (await classifyService.suggestForName({ name, limit })).suggestions;

describe('hsn — retrieval over the official tariff', () => {
  beforeAll(async () => {
    await seedHsnMaster();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  // ── Defect A: the index covers the master, not just the catalogue ────────

  it('finds words that exist only in the official tariff', async () => {
    // None of these appear in any of the 101 curated entries. All of them
    // appear in the imported descriptions, which is the whole point.
    // "keyboard" and "tyre" used to sit here and no longer can: both have
    // since been given curated entries, which is the better outcome — the
    // tariff's word for a computer keyboard is "input or output units", so
    // the tariff layer could only ever land it on chapter 92's pianos. These
    // three are still tariff-only, and asserted absent from the catalogue in
    // the test below so they can't silently become curated either.
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
    // "chappal" and "kameez" are reviewed merchant words. The tariff has its
    // own footwear and shirt prose, and it must never be allowed to answer
    // first for a term someone deliberately curated.
    for (const [name, code] of [
      ['chappal', '6402'],
      ['qameez', '6205'],
      ['sarson ka tel 1L', '1514'],
    ] as const) {
      const hits = retrieve(name, 5);
      expect(hits[0]?.code, `"${name}"`).toBe(code);
      expect(hits[0]?.layer, `"${name}"`).toBe('CURATED');
    }
    // And where both corpora answer, every curated hit precedes every tariff
    // one — the ordering is a rule, not an accident of scoring.
    const mixed = retrieve('biscuit', 6);
    const lastCurated = mixed.map((h) => h.layer).lastIndexOf('CURATED');
    const firstTariff = mixed.map((h) => h.layer).indexOf('TARIFF');
    if (lastCurated >= 0 && firstTariff >= 0) expect(lastCurated).toBeLessThan(firstTariff);
  });

  it('offers the heading rather than four of its own sub-headings', async () => {
    // The schedule repeats itself at every depth: 9201 and 920190 both say
    // "keyboard stringed instruments". Returning both crowds out every other
    // answer, and the heading is where the notified rate lives.
    const hits = retrieve('keyboard', 8);
    expect(hits.map((h) => h.code)).toContain('9201');
    expect(hits.map((h) => h.code)).not.toContain('920190');
  });

  it('does not index the tariff pointing at itself', async () => {
    // "n.e.c. in item no. 8471.30" is drafting, not description. Neither the
    // boilerplate nor the cross-referenced digits may be searchable, or one
    // heading scores every heading that happens to cite it.
    for (const noise of ['elsewhere specified', 'chapter section', '8471 30']) {
      const hits = retrieve(noise, 5).filter((h) => h.layer === 'TARIFF');
      expect(hits, `"${noise}"`).toHaveLength(0);
    }
  });

  // ── Defect B: a code with no rate is still an answer ─────────────────────

  it('suggests a condition-split code, with the condition attached', async () => {
    // Rice. Nil loose, 5% pre-packaged — so heading 1006 carries no single
    // rate, and hiding it left a kirana merchant unable to find rice at all.
    for (const name of ['rice', 'chawal']) {
      const hits = await top(name, 3);
      expect(hits[0]?.code, `"${name}"`).toBe('1006');
      expect(hits[0]?.rateStatus, `"${name}"`).toBe('CONDITIONAL');
      // The schedule's own words, so the merchant can answer the question.
      expect(hits[0]?.rateNote, `"${name}"`).toMatch(/pre-packaged/i);
    }
  });

  it('suggests a heading nothing on its ladder rates', async () => {
    // Shampoo, toothpaste, tea, pens, biscuits, lamps: all headings whose rate
    // the import left in sub-headings it did not rate. Every one of them is a
    // shelf in a real shop.
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
    // The one rule that outranks being helpful. `null` is the only honest
    // answer, and a stand-in 0 would be an under-charged invoice nobody was
    // ever asked about.
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
    // Not every unrated row is unbillable: a navigation row inherits, and that
    // inherited rate is the master's own answer, not a guess. It has to keep
    // arriving as RESOLVED or the merchant is asked a question with an answer.
    const hits = await top('t-shirt', 3);
    expect(hits[0]?.code).toBe('6109');
    expect(hits[0]?.rateStatus).toBe('RESOLVED');
    expect(hits[0]?.gstRate).toBe(5);
  });

  it('ranks the longest matching alias, not the first one indexed', async () => {
    // 9608 owns "pen" and "ball pen"; 9506 owns "ball". Keeping whichever
    // alias the index happened to reach first scored 9608 at the length of
    // "pen" (3) and handed "ball pen" to sports equipment.
    expect(matchAliasesInText('ball pen')[0]).toBe('9608');
    expect((await top('ball pen', 2))[0]?.code).toBe('9608');
  });

  // ── The noise 7,000 short documents would otherwise let in ───────────────

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
    // `wireless` occurs in fewer tariff lines than `keyboard`, so BM25 alone
    // put smartphones above every keyboard in the schedule. Rarity is not
    // aboutness: the last word is what the product *is*.
    const hits = await top('wireless keyboard', 3);
    expect(hits.length).toBeGreaterThan(0);
    expect(hits[0].code.startsWith('8517')).toBe(false);
  });

  it('still refuses the biscuits coincidence at 68× the corpus', async () => {
    // `breed` and `bread` fold to the same consonant skeleton. Adding ~6,900
    // short documents is exactly the condition under which that class of
    // mistake multiplies — and the tariff, which is formal English, is not
    // folded at all.
    const hits = await top('live horses for breeding', 5);
    expect(hits.map((h) => h.code)).not.toContain('1905');
    expect(hits[0]?.code.slice(0, 2)).toBe('01');
  });
});
