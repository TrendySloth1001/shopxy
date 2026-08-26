import { describe, it, expect } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import {
  formatDocNo,
  nextDocNo,
  resolveScheme,
  previewNextDocNo,
  setCounterStart,
  DEFAULT_SCHEMES,
  type SchemeFields,
} from '../../src/shared/numbering/sequences.js';
import { withTestUser } from '../helpers/setup.js';

const scheme = (overrides: Partial<SchemeFields> = {}): SchemeFields => ({
  prefix: 'INV',
  suffix: '',
  separator: '/',
  padding: 5,
  resetYearly: true,
  ...overrides,
});

describe('formatDocNo (pure)', () => {
  it('default scheme reproduces the pre-customization format exactly', () => {
    expect(formatDocNo(scheme(), 1, '25-26')).toBe('INV/25-26/00001');
  });

  it('applies a custom prefix, suffix and separator', () => {
    expect(
      formatDocNo(scheme({ prefix: 'SALE', suffix: 'IN', separator: '-' }), 7, '25-26'),
    ).toBe('SALE-25-26-00007-IN');
  });

  it('padding is a minimum width, never truncates a larger sequence number', () => {
    expect(formatDocNo(scheme({ padding: 3 }), 1200, '25-26')).toBe('INV/25-26/1200');
  });

  it('resetYearly: false omits the financial-year segment entirely', () => {
    expect(formatDocNo(scheme({ resetYearly: false }), 42, '25-26')).toBe('INV/00042');
  });

  it('a blank prefix is omitted rather than leaving a stray separator', () => {
    expect(formatDocNo(scheme({ prefix: '' }), 1, '25-26')).toBe('25-26/00001');
  });
});

describe('nextDocNo / scheme resolution (DB-backed)', () => {
  it('a shop with no saved scheme allocates the same format as before customization existed', async () => {
    await withTestUser(async (ctx) => {
      const resolved = await resolveScheme(ctx.shopId, 'SALE_INVOICE', prisma);
      expect(resolved).toEqual(DEFAULT_SCHEMES.SALE_INVOICE);

      const first = await prisma.$transaction((tx) =>
        nextDocNo(ctx.shopId, 'SALE_INVOICE', new Date('2026-08-05'), tx),
      );
      expect(first.docNo).toMatch(/^INV\/\d{2}-\d{2}\/00001$/);

      const second = await prisma.$transaction((tx) =>
        nextDocNo(ctx.shopId, 'SALE_INVOICE', new Date('2026-08-05'), tx),
      );
      expect(second.docNo).toMatch(/^INV\/\d{2}-\d{2}\/00002$/);
    });
  });

  it('renaming a scheme prefix does NOT reset the running sequence', async () => {
    await withTestUser(async (ctx) => {
      const date = new Date('2026-08-05');
      const first = await prisma.$transaction((tx) => nextDocNo(ctx.shopId, 'CHALLAN', date, tx));
      expect(first.docNo).toMatch(/^CH\/\d{2}-\d{2}\/00001$/);

      await prisma.numberingScheme.create({
        data: { shopId: ctx.shopId, series: 'CHALLAN', prefix: 'DEL', suffix: '', separator: '/', padding: 5, resetYearly: true },
      });

      const second = await prisma.$transaction((tx) => nextDocNo(ctx.shopId, 'CHALLAN', date, tx));
      expect(second.docNo).toMatch(/^DEL\/\d{2}-\d{2}\/00002$/);
    });
  });

  it('toggling resetYearly changes the counter key (documented behavior)', async () => {
    await withTestUser(async (ctx) => {
      const date = new Date('2026-08-05');
      const first = await prisma.$transaction((tx) => nextDocNo(ctx.shopId, 'QUOTATION', date, tx));
      expect(first.docNo).toMatch(/00001$/);

      await prisma.numberingScheme.create({
        data: { shopId: ctx.shopId, series: 'QUOTATION', prefix: 'QUO', suffix: '', separator: '/', padding: 5, resetYearly: false },
      });

      const second = await prisma.$transaction((tx) => nextDocNo(ctx.shopId, 'QUOTATION', date, tx));
      expect(second.docNo).toBe('QUO/00001');
    });
  });

  it('previewNextDocNo reads the next value without allocating it', async () => {
    await withTestUser(async (ctx) => {
      const before = await previewNextDocNo(ctx.shopId, 'DEBIT_NOTE', prisma);
      expect(before).toMatch(/00001$/);
      const again = await previewNextDocNo(ctx.shopId, 'DEBIT_NOTE', prisma);
      expect(again).toBe(before);

      const allocated = await prisma.$transaction((tx) =>
        nextDocNo(ctx.shopId, 'DEBIT_NOTE', new Date('2026-08-05'), tx),
      );
      expect(allocated.docNo).toBe(before);

      const after = await previewNextDocNo(ctx.shopId, 'DEBIT_NOTE', prisma);
      expect(after).toMatch(/00002$/);
    });
  });

  it('setCounterStart makes the next allocation continue from an explicit number', async () => {
    await withTestUser(async (ctx) => {
      await setCounterStart(ctx.shopId, 'ESTIMATE', 500, prisma);
      const preview = await previewNextDocNo(ctx.shopId, 'ESTIMATE', prisma);
      expect(preview).toMatch(/00500$/);

      const allocated = await prisma.$transaction((tx) =>
        nextDocNo(ctx.shopId, 'ESTIMATE', new Date('2026-08-05'), tx),
      );
      expect(allocated.docNo).toMatch(/00500$/);

      const next = await previewNextDocNo(ctx.shopId, 'ESTIMATE', prisma);
      expect(next).toMatch(/00501$/);
    });
  });

  it('a rolled-back transaction does not burn a sequence number (the fixed gap-on-failure bug)', async () => {
    await withTestUser(async (ctx) => {
      const date = new Date('2026-08-05');
      await expect(
        prisma.$transaction(async (tx) => {
          await nextDocNo(ctx.shopId, 'CREDIT_NOTE', date, tx);
          throw new Error('simulated failure after allocation');
        }),
      ).rejects.toThrow('simulated failure');

      const preview = await previewNextDocNo(ctx.shopId, 'CREDIT_NOTE', prisma);
      expect(preview).toMatch(/00001$/);
    });
  });
});
