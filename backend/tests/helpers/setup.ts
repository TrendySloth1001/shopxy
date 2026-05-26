import 'dotenv/config';
import crypto from 'crypto';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { Role } from '@prisma/client';
import prisma from '../../src/infra/db/prisma.js';

/// Tests share the dev Postgres. To stay isolated:
///   - every fixture user gets a `test+<uuid>@shopxy.test` email
///   - every fixture shop slug is suffixed with the same uuid
///   - tracked rows are returned to the caller and deleted on cleanup
///
/// `withTestData` is the standard wrapper: gives you a populated
/// `ctx` (user, shop, accessToken), runs your test, deletes the rows.
/// Failures still trigger cleanup (try/finally) so flaky tests don't
/// leave junk behind.

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
  const passwordHash = await bcrypt.hash(PASSWORD, 4); // low cost: speed > strength in tests
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

  // Every OWNER gets a shop — same pattern as the prod backfill.
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

/// Hard-delete a fixture user + cascade everything that belongs to them.
/// Order matters: invoices RESTRICT on products, and products RESTRICT
/// on shops, so we wipe invoices+items first, then parties, then
/// products. Flash sales cascade from product so they ride along.
/// Idempotent — safe in `finally` after partial setup.
export async function cleanupTestUser(ctx: TestUserCtx): Promise<void> {
  // 1. Invoices issued to parties this user is linked to (buyer side).
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

  // 2. Products this user's shop owns. Wipes images via cascade.
  if (ctx.shopId > 0) {
    await prisma.product
      .deleteMany({ where: { shopId: ctx.shopId } })
      .catch(() => undefined);
  }

  // 3. The user row itself — cascades Shop, ProductReview, etc.
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

/// Insert a product directly via Prisma for a given shop. Tests that
/// need to verify listing/filtering behaviour seed without going
/// through the HTTP layer first.
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

/// Records a CONFIRMED invoice for a buyer-Party that's linked to a
/// User, with a line for the given product. Lets review-gate tests
/// simulate a real purchase without going through the invoice creation
/// pipeline. Returns the invoice + party ids so cleanup helpers can
/// tear them down. NOTE: skips ledger entries — this is fixture data,
/// stock-quantity correctness is not under test here.
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
