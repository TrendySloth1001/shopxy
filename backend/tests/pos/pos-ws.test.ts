import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import * as pos from '../../src/modules/pos/pos.service.js';
import { handlePosCommand } from '../../src/modules/pos/pos.ws.js';
import type { WsAuthCtx } from '../../src/modules/scan-console/scan-console.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

/// The WS command router dispatches to the (separately-tested) functional
/// service and replies under reqId. These pin the wire protocol.

// Minimal fake socket: captures the next sent frame as a resolved promise.
function fakeWs() {
  let resolve!: (v: Record<string, unknown>) => void;
  const next = new Promise<Record<string, unknown>>((r) => (resolve = r));
  const ws = { readyState: 1 /* WebSocket.OPEN */, send: (s: string) => resolve(JSON.parse(s)) };
  return { ws, next };
}

function snap(r: unknown) {
  if (r && typeof r === 'object' && 'error' in (r as Record<string, unknown>)) {
    throw new Error(`expected snapshot, got ${(r as { error: string }).error}`);
  }
  return r as { sale: { id: number } };
}

describe('pos.ws — command dispatch', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('routes a command to the service and replies under reqId', async () => {
    const ctx0 = await createTestUser();
    try {
      const sale = snap(await pos.openSale(ctx0.shopId, ctx0.userId));
      const ctx: WsAuthCtx = { shopId: ctx0.shopId, userId: ctx0.userId, shopRole: 'OWNER', permissions: [] };

      // Unknown scan → ok:true with { unknown }.
      const a = fakeWs();
      handlePosCommand(a.ws as never, ctx, { t: 'cmd', reqId: 'r1', op: 'scan', saleId: sale.sale.id, code: 'NO-SUCH' });
      expect(await a.next).toMatchObject({ t: 'res', reqId: 'r1', ok: true, data: { unknown: true, code: 'NO-SUCH' } });

      // Real product scan → ok:true with a snapshot.
      const product = await createTestProduct(ctx0.shopId, { sellingPrice: 25, stockQuantity: 5 });
      const b = fakeWs();
      handlePosCommand(b.ws as never, ctx, { t: 'cmd', reqId: 'r2', op: 'scan', saleId: sale.sale.id, code: product.sku });
      const res = (await b.next) as { ok: boolean; data: { lines: unknown[] } };
      expect(res.ok).toBe(true);
      expect(res.data.lines).toHaveLength(1);
    } finally {
      await cleanupTestUser(ctx0);
    }
  });

  it('rejects an invalid command and gates quick-add on products:manage', async () => {
    const ctx0 = await createTestUser();
    try {
      const sale = snap(await pos.openSale(ctx0.shopId, ctx0.userId));

      // Bad args → ok:false invalid.
      const bad = fakeWs();
      handlePosCommand(bad.ws as never, { shopId: ctx0.shopId, userId: ctx0.userId, permissions: [] }, {
        t: 'cmd',
        reqId: 'r3',
        op: 'setQty',
        saleId: sale.sale.id,
        // missing productId/quantity
      });
      expect(await bad.next).toMatchObject({ t: 'res', reqId: 'r3', ok: false });

      // quick-add without products:manage → 403-equivalent.
      const denied = fakeWs();
      handlePosCommand(denied.ws as never, { shopId: ctx0.shopId, userId: ctx0.userId, shopRole: 'CASHIER', permissions: ['invoices:manage'] }, {
        t: 'cmd',
        reqId: 'r4',
        op: 'quickAdd',
        saleId: sale.sale.id,
        code: 'QA-WS',
        name: 'X',
        sellingPrice: 10,
      });
      const res = (await denied.next) as { ok: boolean; error: string };
      expect(res.ok).toBe(false);
      expect(res.error).toMatch(/product management/i);
    } finally {
      await cleanupTestUser(ctx0);
    }
  });
});
