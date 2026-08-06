import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import { numberingService } from '../../src/modules/numbering/numbering.service.js';
import { ALL_SERIES } from '../../src/shared/numbering/sequences.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

describe('numberingService', () => {
  it('lists all 7 series with system defaults when nothing is customized', async () => {
    const ctx = await createTestUser();
    try {
      const schemes = await numberingService.listSchemesForShop(ctx.shopId);
      expect(schemes.map((s) => s.series).sort()).toEqual([...ALL_SERIES].sort());
      for (const s of schemes) {
        expect(s.isCustom).toBe(false);
        expect(s.nextPreview.endsWith('00001')).toBe(true);
      }
      const saleInvoice = schemes.find((s) => s.series === 'SALE_INVOICE')!;
      expect(saleInvoice.prefix).toBe('INV');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('upsertScheme saves a partial patch merged onto the current (default) scheme', async () => {
    const ctx = await createTestUser();
    try {
      const updated = await numberingService.upsertScheme(ctx.shopId, 'SALE_INVOICE', {
        prefix: 'SALE',
        padding: 6,
      });
      expect(updated.prefix).toBe('SALE');
      expect(updated.padding).toBe(6);
      // Untouched fields keep the default.
      expect(updated.separator).toBe('/');
      expect(updated.resetYearly).toBe(true);
      expect(updated.isCustom).toBe(true);

      // A second partial patch merges onto the SAVED row, not the default.
      const again = await numberingService.upsertScheme(ctx.shopId, 'SALE_INVOICE', {
        suffix: 'IN',
      });
      expect(again.prefix).toBe('SALE'); // preserved from the first save
      expect(again.suffix).toBe('IN');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('setNextNumber overrides the running counter for a series', async () => {
    const ctx = await createTestUser();
    try {
      const result = await numberingService.setNextNumber(ctx.shopId, 'DEBIT_NOTE', 1000);
      expect(result.nextPreview.endsWith('01000')).toBe(true);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('GET /numbering is registered and wired (not a 404)', async () => {
    // Merchant-area routing smoke check — same harness limitation noted in
    // challans.test.ts (a bare test token 403s past resolveShop-less
    // routes), so this only proves the route is mounted; behavior above
    // is covered at the service layer.
    const app = buildApp();
    const ctx = await createTestUser();
    try {
      const res = await request(app)
        .get('/numbering')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      expect(res.status).not.toBe(404);
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});
