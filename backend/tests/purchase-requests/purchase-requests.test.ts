import { describe, it, expect, afterAll } from 'vitest';
import crypto from 'crypto';
import prisma from '../../src/infra/db/prisma.js';
import { purchaseRequestsService } from '../../src/modules/purchase-requests/purchase-requests.service.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

/// Smoke tests for purchase-requests.service. The file is 1494 LOC and
/// the cart-checkout flow (createForCustomer, 463 LOC) is the riskiest
/// surface — price drift, idempotency, cross-shop checks. These pin the
/// canonical behaviours so the planned refactor (split into staged
/// private methods) can land without breaking checkout.

async function createBuyer() {
  // A second user (not an OWNER's shop) that acts as the customer.
  return createTestUser({ role: 'CUSTOMER' as never });
}

describe('purchase-requests.service — smoke', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('createForCustomer — happy path creates a CustomerOrder + per-shop child', async () => {
    const merchant = await createTestUser();
    const buyer = await createBuyer();
    try {
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 100,
      });
      const result = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        items: [
          { productId: product.id, quantity: 2, expectedUnitPrice: 100 },
        ],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      expect(result.order.shopOrders).toHaveLength(1);
      expect(result.order.shopOrders[0].shopId).toBe(merchant.shopId);
      await prisma.customerOrder.delete({ where: { id: result.order.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('createForCustomer — rejects when expectedUnitPrice has drifted', async () => {
    const merchant = await createTestUser();
    const buyer = await createBuyer();
    try {
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 100,
      });
      // Client believes price is ₹50 but live price is ₹100 → drift.
      const result = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        items: [
          { productId: product.id, quantity: 1, expectedUnitPrice: 50 },
        ],
      });
      expect('error' in result).toBe(true);
      if (!('error' in result)) return;
      expect(result.error).toBe('PRICE_DRIFT');
      expect(result.priceDrift?.[0].productId).toBe(product.id);
      expect(Number(result.priceDrift?.[0].actualUnitPrice)).toBe(100);
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('createForCustomer — second call with same idempotencyKey replays the first', async () => {
    const merchant = await createTestUser();
    const buyer = await createBuyer();
    try {
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 100,
      });
      const idempotencyKey = `test-${crypto.randomBytes(4).toString('hex')}`;
      const first = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        idempotencyKey,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 100 }],
      });
      const second = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        idempotencyKey,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 100 }],
      });
      if ('error' in first || 'error' in second) {
        throw new Error('idempotent calls should not error');
      }
      expect(second.order.id).toBe(first.order.id);
      expect(second.deduplicated).toBe(true);
      await prisma.customerOrder.delete({ where: { id: first.order.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('createForCustomer — rejects buyer ordering from their own shop', async () => {
    const owner = await createTestUser();
    try {
      const product = await createTestProduct(owner.shopId, {
        sellingPrice: 100,
      });
      // Same user is both owner and buyer — explicitly disallowed.
      const result = await purchaseRequestsService.createForCustomer({
        customerUserId: owner.userId,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 100 }],
      });
      expect('error' in result).toBe(true);
      if (!('error' in result)) return;
      expect(result.error).toBe('OWN_SHOP_ITEM');
    } finally {
      await cleanupTestUser(owner);
    }
  });
});
