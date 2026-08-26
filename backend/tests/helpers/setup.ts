import 'dotenv/config';
import crypto from 'crypto';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { Role } from '@prisma/client';
import prisma from '../../src/infra/db/prisma.js';

export interface TestUserCtx {
  userId: number;
  shopId: number;
  shopSlug: string;
  email: string;
  password: string;
  accessToken: string;
}

const PASSWORD = 'TestPassw0rd!';

export async function createTestUser(opts: { role?: Role; isPlatformAdmin?: boolean } = {}): Promise<TestUserCtx> {
  const id = crypto.randomBytes(6).toString('hex');
  const email = `test+${id}@shopxy.test`;
  const passwordHash = await bcrypt.hash(PASSWORD, 4);
  const user = await prisma.user.create({
    data: {
      email,
      name: `Test User ${id}`,
      passwordHash,
      role: opts.role ?? Role.OWNER,
      isPlatformAdmin: opts.isPlatformAdmin ?? false,
      acceptedAt: new Date(),
    },
  });

  let shopId = -1;
  let shopSlug = '';
  if (user.role === Role.OWNER) {
    const slug = `test-shop-${id}`;
    const shop = await prisma.shop.create({
      data: {
        ownerUserId: user.id,
        name: `Test Shop ${id}`,
        slug,
      },
    });
    shopId = shop.id;
    shopSlug = slug;
  }

  const secret = process.env.JWT_ACCESS_SECRET!;
  const accessToken = jwt.sign(
    { sub: user.id, email: user.email, role: user.role, isPlatformAdmin: user.isPlatformAdmin },
    secret,
    { expiresIn: '15m' },
  );

  return { userId: user.id, shopId, shopSlug, email, password: PASSWORD, accessToken };
}

export async function cleanupTestUser(ctx: TestUserCtx): Promise<void> {
  const parties = await prisma.party.findMany({
    where: { linkedUserId: ctx.userId },
    select: { id: true },
  });
  const partyIds = parties.map((p) => p.id);
  if (partyIds.length > 0) {
    await prisma.invoice
      .deleteMany({ where: { partyId: { in: partyIds } } })
      .catch(() => undefined);
    await prisma.party
      .deleteMany({ where: { id: { in: partyIds } } })
      .catch(() => undefined);
  }

  if (ctx.shopId > 0) {
    await prisma.product
      .deleteMany({ where: { shopId: ctx.shopId } })
      .catch(() => undefined);
    await prisma.outboxEvent
      .deleteMany({ where: { shopId: ctx.shopId } })
      .catch(() => undefined);
  }

  await prisma.user
    .delete({ where: { id: ctx.userId } })
    .catch(() => undefined);
}

export async function withTestUser<T>(
  fn: (ctx: TestUserCtx) => Promise<T>,
  opts: { role?: Role; isPlatformAdmin?: boolean } = {},
): Promise<T> {
  const ctx = await createTestUser(opts);
  try {
    return await fn(ctx);
  } finally {
    await cleanupTestUser(ctx);
  }
}

export async function createTestProduct(
  shopId: number,
  overrides: Partial<{
    name: string;
    sku: string;
    mrp: number;
    sellingPrice: number;
    purchasePrice: number;
    stockQuantity: number;
    lowStockThreshold: number;
    isActive: boolean;
    isPublished: boolean;
  }> = {},
) {
  const id = crypto.randomBytes(4).toString('hex');
  return prisma.product.create({
    data: {
      name: overrides.name ?? `Test Product ${id}`,
      sku: overrides.sku ?? `SKU-${id}`,
      mrp: overrides.mrp ?? 100,
      sellingPrice: overrides.sellingPrice ?? 90,
      purchasePrice: overrides.purchasePrice ?? 70,
      stockQuantity: overrides.stockQuantity ?? 10,
      lowStockThreshold: overrides.lowStockThreshold ?? 5,
      isActive: overrides.isActive ?? true,
      isPublished: overrides.isPublished ?? false,
      shopId,
    },
  });
}

export async function recordTestPurchase(args: {
  shopId: number;
  buyerUserId: number;
  productId: number;
  quantity?: number;
}) {
  const id = crypto.randomBytes(4).toString('hex');
  const party = await prisma.party.create({
    data: {
      shopId: args.shopId,
      name: `Test Party ${id}`,
      linkedUserId: args.buyerUserId,
    },
  });
  const product = await prisma.product.findUniqueOrThrow({
    where: { id: args.productId },
    select: { name: true, sku: true, sellingPrice: true, unit: true },
  });
  const qty = args.quantity ?? 1;
  const unitPrice = Number(product.sellingPrice);
  const taxable = unitPrice * qty;

  const invoice = await prisma.invoice.create({
    data: {
      shopId: args.shopId,
      invoiceNo: `TEST/${id}`,
      type: 'SALE',
      financialYear: '25-26',
      status: 'CONFIRMED',
      partyId: party.id,
      subtotal: taxable,
      taxableValue: taxable,
      total: taxable,
      items: {
        create: {
          productId: args.productId,
          productName: product.name,
          productSku: product.sku,
          unit: product.unit,
          quantity: qty,
          unitPrice,
          taxableValue: taxable,
          total: taxable,
        },
      },
    },
    include: { items: true },
  });
  return { invoice, party };
}
