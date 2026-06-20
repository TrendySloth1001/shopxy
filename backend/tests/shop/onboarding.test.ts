import { describe, it, expect, afterAll } from 'vitest';
import crypto from 'crypto';
import prisma from '../../src/infra/db/prisma.js';
import { authService } from '../../src/modules/auth/auth.service.js';
import { shopService } from '../../src/modules/shop/shop.service.js';

/// Two-step onboarding: register makes a shopless OWNER, then
/// createMyShop seeds the Shop + owner membership + starter roles. A user
/// who's already on a team can't create a shop (one membership per user).

describe('shop onboarding — createMyShop', () => {
  const cleanupUserIds: number[] = [];
  const cleanupShopIds: number[] = [];

  afterAll(async () => {
    await prisma.teamRole.deleteMany({ where: { shopId: { in: cleanupShopIds } } });
    await prisma.shopMember.deleteMany({ where: { userId: { in: cleanupUserIds } } });
    await prisma.shop.deleteMany({ where: { id: { in: cleanupShopIds } } });
    await prisma.user.deleteMany({ where: { id: { in: cleanupUserIds } } });
    await prisma.$disconnect();
  });

  async function registerShoplessOwner() {
    const id = crypto.randomBytes(6).toString('hex');
    const result = await authService.register({
      email: `owner+${id}@shopxy.test`,
      name: `Owner ${id}`,
      password: 'Passw0rd!',
      role: 'OWNER',
    });
    if ('error' in result) throw new Error(`register failed: ${result.error}`);
    cleanupUserIds.push(result.user.id);
    return result.user.id;
  }

  it('creates the shop, the owner membership, and seeds starter roles', async () => {
    const userId = await registerShoplessOwner();

    const out = await shopService.createMyShop(userId, {
      name: 'Corner Store',
      shopCity: 'Pune',
      shopState: 'Maharashtra',
      phoneNumber: '9876543210',
    });
    if ('error' in out) throw new Error(out.error);
    expect(out.shop?.name).toBe('Corner Store');
    cleanupShopIds.push(out.shop!.id);

    const membership = await prisma.shopMember.findUnique({
      where: { userId },
      select: { shopId: true, role: true },
    });
    expect(membership?.shopId).toBe(out.shop!.id);
    expect(membership?.role).toBe('OWNER');

    // Starter roles seeded (Manager/Stockist/Cashier or similar).
    const roleCount = await prisma.teamRole.count({ where: { shopId: out.shop!.id } });
    expect(roleCount).toBeGreaterThan(0);

    // Details mirrored onto the user for invoice headers.
    const user = await prisma.user.findUnique({ where: { id: userId }, select: { shopName: true, shopCity: true } });
    expect(user?.shopName).toBe('Corner Store');
    expect(user?.shopCity).toBe('Pune');
  });

  it('refuses a second shop once the owner already has one', async () => {
    const userId = await registerShoplessOwner();
    const first = await shopService.createMyShop(userId, { name: 'First Shop' });
    if ('error' in first) throw new Error(first.error);
    cleanupShopIds.push(first.shop!.id);

    const second = await shopService.createMyShop(userId, { name: 'Second Shop' });
    expect('error' in second).toBe(true);
  });
});
