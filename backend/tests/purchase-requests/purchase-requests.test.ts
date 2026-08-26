import { describe, it, expect, afterAll } from 'vitest';
import crypto from 'crypto';
import prisma from '../../src/infra/db/prisma.js';
import { purchaseRequestsService } from '../../src/modules/purchase-requests/purchase-requests.service.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

async function createBuyer() {
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

  it('confirmRequest — a TAX_EXCLUSIVE (default) product is billed exclusive at checkout, not inclusive', async () => {
    const merchant = await createTestUser();
    const buyer = await createBuyer();
    try {
      await prisma.user.update({
        where: { id: merchant.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      await prisma.shop.update({ where: { id: merchant.shopId }, data: { isPublished: true } });
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 100,
        isPublished: true,
      });
      await prisma.product.update({ where: { id: product.id }, data: { taxPercent: 18 } });
      const created = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 100 }],
      });
      expect('error' in created).toBe(false);
      if ('error' in created) return;
      const requestId = created.order.shopOrders[0].id;
      const result = await purchaseRequestsService.confirmRequest({
        shopId: merchant.shopId,
        requestId,
        decidedById: merchant.userId,
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const invoice = await prisma.invoice.findUniqueOrThrow({ where: { id: result.invoice.id } });
      expect(Number(invoice.taxableValue)).toBeCloseTo(100, 2);
      expect(Number(invoice.total)).toBeCloseTo(118, 2);
      await prisma.invoice.delete({ where: { id: invoice.id } });
      await prisma.customerOrder.delete({ where: { id: created.order.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('confirmRequest — a TAX_INCLUSIVE product still backs GST out of the snapshot price at checkout', async () => {
    const merchant = await createTestUser();
    const buyer = await createBuyer();
    try {
      await prisma.user.update({
        where: { id: merchant.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      await prisma.shop.update({ where: { id: merchant.shopId }, data: { isPublished: true } });
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 118,
        mrp: 118,
        isPublished: true,
      });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18, pricingMode: 'TAX_INCLUSIVE' },
      });
      const created = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 118 }],
      });
      expect('error' in created).toBe(false);
      if ('error' in created) return;
      const requestId = created.order.shopOrders[0].id;
      const result = await purchaseRequestsService.confirmRequest({
        shopId: merchant.shopId,
        requestId,
        decidedById: merchant.userId,
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const invoice = await prisma.invoice.findUniqueOrThrow({ where: { id: result.invoice.id } });
      expect(Number(invoice.taxableValue)).toBeCloseTo(100, 2);
      expect(Number(invoice.total)).toBeCloseTo(118, 2);
      await prisma.invoice.delete({ where: { id: invoice.id } });
      await prisma.customerOrder.delete({ where: { id: created.order.id } });
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

  it('createForCustomer — placing an order links the buyer to the shop', async () => {
    const merchant = await createTestUser();
    const buyer = await createBuyer();
    try {
      await prisma.shop.update({
        where: { id: merchant.shopId },
        data: { isPublished: true },
      });
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 100,
      });
      const before = await prisma.party.count({
        where: { shopId: merchant.shopId, linkedUserId: buyer.userId },
      });
      expect(before).toBe(0);

      const result = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 100 }],
      });
      if ('error' in result) throw new Error(`unexpected ${result.error}`);

      const party = await prisma.party.findFirst({
        where: { shopId: merchant.shopId, linkedUserId: buyer.userId },
        select: { id: true, isActive: true },
      });
      expect(party).not.toBeNull();
      expect(party!.isActive).toBe(true);
      const child = await prisma.purchaseRequest.findFirstOrThrow({
        where: { customerOrderId: result.order.id },
        select: { partyId: true, status: true },
      });
      expect(child.partyId).toBe(party!.id);
      expect(child.status).toBe('PENDING');

      await prisma.customerOrder.delete({ where: { id: result.order.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('createForCustomer — a repeat order reuses the same party row', async () => {
    const merchant = await createTestUser();
    const buyer = await createBuyer();
    try {
      await prisma.shop.update({
        where: { id: merchant.shopId },
        data: { isPublished: true },
      });
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 100,
      });
      const first = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 100 }],
      });
      const second = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        items: [{ productId: product.id, quantity: 2, expectedUnitPrice: 100 }],
      });
      if ('error' in first || 'error' in second) {
        throw new Error('orders should not error');
      }
      const parties = await prisma.party.count({
        where: { shopId: merchant.shopId, linkedUserId: buyer.userId },
      });
      expect(parties).toBe(1);

      await prisma.customerOrder.delete({ where: { id: second.order.id } });
      await prisma.customerOrder.delete({ where: { id: first.order.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });
});
