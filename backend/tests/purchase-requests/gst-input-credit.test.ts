import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { purchaseRequestsService } from '../../src/modules/purchase-requests/purchase-requests.service.js';
import { meService } from '../../src/modules/me/me.service.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

/// A buyer's own GSTIN, correctly checksummed (see tests/shared/gstin.test.ts).
const BUYER_GSTIN = '19AAACI1681G1ZM'; // state 19 = West Bengal
const BUYER_LEGAL_NAME = 'Indus Trading Co Pvt Ltd';

async function createBuyer() {
  return createTestUser({ role: 'CUSTOMER' as never });
}

/// A shop that can actually issue a tax invoice: REGULAR registration with a
/// GSTIN, published so checkout accepts it. Maharashtra (27).
async function createGstMerchant() {
  const merchant = await createTestUser();
  await prisma.user.update({
    where: { id: merchant.userId },
    data: {
      shopGstin: '27ABCDE1234F1Z5',
      shopStateCode: '27',
      registrationType: 'REGULAR',
    },
  });
  await prisma.shop.update({
    where: { id: merchant.shopId },
    data: { isPublished: true },
  });
  return merchant;
}

async function saveGstProfile(userId: number) {
  const saved = await meService.updateGstProfile(userId, {
    gstin: BUYER_GSTIN,
    legalName: BUYER_LEGAL_NAME,
  });
  if ('error' in saved) throw new Error(`profile save failed: ${saved.error}`);
  return saved;
}

describe('GST input credit — buyer profile', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('saves a valid GSTIN, upper-cased and trimmed', async () => {
    const buyer = await createBuyer();
    try {
      const saved = await meService.updateGstProfile(buyer.userId, {
        gstin: `  ${BUYER_GSTIN.toLowerCase()}  `,
        legalName: `  ${BUYER_LEGAL_NAME}  `,
      });
      expect(saved).toEqual({
        gstin: BUYER_GSTIN,
        legalName: BUYER_LEGAL_NAME,
      });
      expect(await meService.gstProfile(buyer.userId)).toEqual({
        gstin: BUYER_GSTIN,
        legalName: BUYER_LEGAL_NAME,
      });
    } finally {
      await cleanupTestUser(buyer);
    }
  });

  it('rejects a GSTIN that fails the checksum, leaving the profile untouched', async () => {
    const buyer = await createBuyer();
    try {
      const result = await meService.updateGstProfile(buyer.userId, {
        gstin: '19AAACI1681G1ZX',
        legalName: BUYER_LEGAL_NAME,
      });
      expect(result).toEqual({ error: 'INVALID_GSTIN' });
      expect(await meService.gstProfile(buyer.userId)).toEqual({
        gstin: null,
        legalName: null,
      });
    } finally {
      await cleanupTestUser(buyer);
    }
  });

  it('refuses a GSTIN with no registered name — Rule 46 needs both', async () => {
    const buyer = await createBuyer();
    try {
      const result = await meService.updateGstProfile(buyer.userId, {
        gstin: BUYER_GSTIN,
        legalName: '   ',
      });
      expect(result).toEqual({ error: 'LEGAL_NAME_REQUIRED' });
    } finally {
      await cleanupTestUser(buyer);
    }
  });

  it('clears both fields when the GSTIN is nulled — back to B2C', async () => {
    const buyer = await createBuyer();
    try {
      await saveGstProfile(buyer.userId);
      const cleared = await meService.updateGstProfile(buyer.userId, {
        gstin: null,
      });
      expect(cleared).toEqual({ gstin: null, legalName: null });
    } finally {
      await cleanupTestUser(buyer);
    }
  });
});

describe('GST input credit — checkout to tax invoice', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('claiming credit puts the buyer GSTIN and legal name on the tax invoice', async () => {
    const merchant = await createGstMerchant();
    const buyer = await createBuyer();
    try {
      await saveGstProfile(buyer.userId);
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 1000,
        isPublished: true,
      });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18 },
      });

      const created = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        claimGst: true,
        items: [
          { productId: product.id, quantity: 1, expectedUnitPrice: 1000 },
        ],
      });
      if ('error' in created) throw new Error(`unexpected ${created.error}`);

      // Snapshotted onto the order and mirrored to the shop's slice.
      const parent = await prisma.customerOrder.findUniqueOrThrow({
        where: { id: created.order.id },
        select: { buyerGstin: true, buyerLegalName: true },
      });
      expect(parent.buyerGstin).toBe(BUYER_GSTIN);
      expect(parent.buyerLegalName).toBe(BUYER_LEGAL_NAME);

      const requestId = created.order.shopOrders[0].id;
      const child = await prisma.purchaseRequest.findUniqueOrThrow({
        where: { id: requestId },
        select: { buyerGstin: true, partyId: true },
      });
      expect(child.buyerGstin).toBe(BUYER_GSTIN);

      // The party the merchant sees is the registered business, carrying the
      // GSTIN — that is what makes it a B2B customer in their ledger.
      const party = await prisma.party.findUniqueOrThrow({
        where: { id: child.partyId! },
        select: { name: true, gstin: true },
      });
      expect(party.gstin).toBe(BUYER_GSTIN);
      expect(party.name).toBe(BUYER_LEGAL_NAME);

      const confirmed = await purchaseRequestsService.confirmRequest({
        shopId: merchant.shopId,
        requestId,
        decidedById: merchant.userId,
      });
      if ('error' in confirmed) throw new Error(`confirm failed: ${confirmed.error}`);

      const invoice = await prisma.invoice.findUniqueOrThrow({
        where: { id: confirmed.invoice.id },
      });
      expect(invoice.documentType).toBe('TAX_INVOICE');
      expect(invoice.customerGstin).toBe(BUYER_GSTIN);
      expect(invoice.customerName).toBe(BUYER_LEGAL_NAME);
      // Tax actually charged — an invoice with no GST on it is nothing to
      // claim credit against.
      expect(Number(invoice.taxAmount)).toBeGreaterThan(0);

      await prisma.invoice.delete({ where: { id: invoice.id } });
      await prisma.customerOrder.delete({ where: { id: created.order.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('place of supply follows the delivery address, not the buyer GSTIN state', async () => {
    // IGST Sec 10(1)(a): for goods the place of supply is where the movement
    // terminates. A West-Bengal-registered (19) buyer taking delivery in
    // Maharashtra (27) from a Maharashtra seller is an INTRA-state supply —
    // deriving it from the GSTIN prefix would wrongly charge IGST.
    const merchant = await createGstMerchant();
    const buyer = await createBuyer();
    try {
      await saveGstProfile(buyer.userId);
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 1000,
        isPublished: true,
      });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18 },
      });
      const address = await prisma.userAddress.create({
        data: {
          userId: buyer.userId,
          label: 'Warehouse',
          fullName: BUYER_LEGAL_NAME,
          phone: '9876543210',
          line1: '1 Dock Road',
          city: 'Mumbai',
          state: 'Maharashtra',
          pincode: '400001',
        },
        select: { id: true },
      });

      const created = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        claimGst: true,
        addressId: address.id,
        items: [
          { productId: product.id, quantity: 1, expectedUnitPrice: 1000 },
        ],
      });
      if ('error' in created) throw new Error(`unexpected ${created.error}`);

      const confirmed = await purchaseRequestsService.confirmRequest({
        shopId: merchant.shopId,
        requestId: created.order.shopOrders[0].id,
        decidedById: merchant.userId,
      });
      if ('error' in confirmed) throw new Error(`confirm failed: ${confirmed.error}`);

      const invoice = await prisma.invoice.findUniqueOrThrow({
        where: { id: confirmed.invoice.id },
      });
      expect(invoice.customerGstin).toBe(BUYER_GSTIN);
      expect(invoice.placeOfSupplyStateCode).toBe('27');
      expect(invoice.isInterstate).toBe(false);
      expect(Number(invoice.igstAmount)).toBe(0);
      expect(Number(invoice.cgstAmount)).toBeGreaterThan(0);

      await prisma.invoice.delete({ where: { id: invoice.id } });
      await prisma.customerOrder.delete({ where: { id: created.order.id } });
      await prisma.userAddress.delete({ where: { id: address.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('an order placed without claiming stays B2C', async () => {
    const merchant = await createGstMerchant();
    const buyer = await createBuyer();
    try {
      await saveGstProfile(buyer.userId);
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 500,
        isPublished: true,
      });

      const created = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 500 }],
      });
      if ('error' in created) throw new Error(`unexpected ${created.error}`);

      const parent = await prisma.customerOrder.findUniqueOrThrow({
        where: { id: created.order.id },
        select: { buyerGstin: true, buyerLegalName: true },
      });
      // A saved GSTIN is not consent to use it — the customer opts in per order.
      expect(parent.buyerGstin).toBeNull();
      expect(parent.buyerLegalName).toBeNull();

      const child = await prisma.purchaseRequest.findFirstOrThrow({
        where: { customerOrderId: created.order.id },
        select: { partyId: true },
      });
      const party = await prisma.party.findUniqueOrThrow({
        where: { id: child.partyId! },
        select: { gstin: true },
      });
      expect(party.gstin).toBeNull();

      await prisma.customerOrder.delete({ where: { id: created.order.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('refuses to place the order when the account has no GST profile', async () => {
    const merchant = await createGstMerchant();
    const buyer = await createBuyer();
    try {
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 500,
        isPublished: true,
      });
      const result = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        claimGst: true,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 500 }],
      });
      // Silently dropping the claim would hand the buyer a B2C invoice they
      // only discover is unclaimable at filing time.
      expect(result).toEqual({ error: 'GST_PROFILE_MISSING' });
      const orders = await prisma.customerOrder.count({
        where: { customerUserId: buyer.userId },
      });
      expect(orders).toBe(0);
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('an unregistered seller issues a bill of supply, with no GST to claim', async () => {
    // The buyer can ask, but a seller outside GST cannot charge output tax
    // (CGST Sec 32) — the document downgrades and there is no credit.
    const merchant = await createTestUser();
    await prisma.shop.update({
      where: { id: merchant.shopId },
      data: { isPublished: true },
    });
    const buyer = await createBuyer();
    try {
      await saveGstProfile(buyer.userId);
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 1000,
        isPublished: true,
      });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18 },
      });

      const created = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        claimGst: true,
        items: [
          { productId: product.id, quantity: 1, expectedUnitPrice: 1000 },
        ],
      });
      if ('error' in created) throw new Error(`unexpected ${created.error}`);

      const confirmed = await purchaseRequestsService.confirmRequest({
        shopId: merchant.shopId,
        requestId: created.order.shopOrders[0].id,
        decidedById: merchant.userId,
      });
      if ('error' in confirmed) throw new Error(`confirm failed: ${confirmed.error}`);

      const invoice = await prisma.invoice.findUniqueOrThrow({
        where: { id: confirmed.invoice.id },
      });
      expect(invoice.documentType).toBe('BILL_OF_SUPPLY');
      expect(Number(invoice.taxAmount)).toBe(0);
      // The recipient GSTIN is still recorded — the buyer asked, and the
      // document says who it was billed to — it just carries no tax.
      expect(invoice.customerGstin).toBe(BUYER_GSTIN);

      await prisma.invoice.delete({ where: { id: invoice.id } });
      await prisma.customerOrder.delete({ where: { id: created.order.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('a repeat B2B order backfills the GSTIN onto a party created before it', async () => {
    const merchant = await createGstMerchant();
    const buyer = await createBuyer();
    try {
      const product = await createTestProduct(merchant.shopId, {
        sellingPrice: 500,
        isPublished: true,
      });
      // First order: personal, so the party is created without a GSTIN.
      const first = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 500 }],
      });
      if ('error' in first) throw new Error(`unexpected ${first.error}`);

      // The customer registers for GST, then orders again claiming credit.
      await saveGstProfile(buyer.userId);
      const second = await purchaseRequestsService.createForCustomer({
        customerUserId: buyer.userId,
        claimGst: true,
        items: [{ productId: product.id, quantity: 1, expectedUnitPrice: 500 }],
      });
      if ('error' in second) throw new Error(`unexpected ${second.error}`);

      const parties = await prisma.party.findMany({
        where: { shopId: merchant.shopId, linkedUserId: buyer.userId },
        select: { gstin: true },
      });
      // Still one customer, now recognised as registered.
      expect(parties).toHaveLength(1);
      expect(parties[0].gstin).toBe(BUYER_GSTIN);

      await prisma.customerOrder.delete({ where: { id: second.order.id } });
      await prisma.customerOrder.delete({ where: { id: first.order.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });
});
