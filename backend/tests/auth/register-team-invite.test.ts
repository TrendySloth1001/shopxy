import { describe, it, expect, afterAll } from 'vitest';
import crypto from 'crypto';
import prisma from '../../src/infra/db/prisma.js';
import { authService } from '../../src/modules/auth/auth.service.js';

async function makeInvitingShop() {
  const id = crypto.randomBytes(6).toString('hex');
  const owner = await prisma.user.create({
    data: { email: `owner+${id}@shopxy.test`, name: `Owner ${id}`, passwordHash: 'x', role: 'OWNER', acceptedAt: new Date() },
    select: { id: true },
  });
  const shop = await prisma.shop.create({
    data: { ownerUserId: owner.id, name: `Shop ${id}`, slug: `shop-${id}` },
    select: { id: true },
  });
  await prisma.shopMember.create({ data: { shopId: shop.id, userId: owner.id, role: 'OWNER' } });
  return { ownerId: owner.id, shopId: shop.id, suffix: id };
}

describe('register — pending TEAM invite takes precedence over shop creation', () => {
  const cleanupUserIds: number[] = [];
  const cleanupShopIds: number[] = [];

  afterAll(async () => {
    await prisma.shopMember.deleteMany({ where: { userId: { in: cleanupUserIds } } });
    await prisma.invitation.deleteMany({ where: { fromUserId: { in: cleanupUserIds } } });
    await prisma.shop.deleteMany({ where: { id: { in: cleanupShopIds } } });
    await prisma.user.deleteMany({ where: { id: { in: cleanupUserIds } } });
    await prisma.$disconnect();
  });

  it('does NOT auto-join the team from an email match — shopless account, invite stays PENDING (AUTH-1)', async () => {
    const { ownerId, shopId, suffix } = await makeInvitingShop();
    cleanupUserIds.push(ownerId);
    cleanupShopIds.push(shopId);

    const inviteeEmail = `cashier+${suffix}@shopxy.test`;
    await prisma.invitation.create({
      data: {
        shopId,
        fromUserId: ownerId,
        toEmail: inviteeEmail,
        linkType: 'TEAM',
        teamRole: 'CASHIER',
        teamRoleName: 'Cashier',
        teamPermissions: ['invoices:manage'],
        status: 'PENDING',
        token: `tok-${suffix}`,
        expiresAt: new Date(Date.now() + 86_400_000),
      },
    });

    const result = await authService.register({
      email: inviteeEmail,
      name: 'New Cashier',
      password: 'Passw0rd!',
      role: 'OWNER',
      shopName: 'Their Own Shop',
    });
    if ('error' in result) throw new Error(`register failed: ${result.error}`);
    cleanupUserIds.push(result.user.id);

    const membership = await prisma.shopMember.findUnique({
      where: { userId: result.user.id },
      select: { id: true },
    });
    expect(membership).toBeNull();

    const ownedShop = await prisma.shop.findUnique({ where: { ownerUserId: result.user.id }, select: { id: true } });
    expect(ownedShop).toBeNull();

    const invite = await prisma.invitation.findFirst({ where: { toEmail: inviteeEmail }, select: { status: true, toUserId: true } });
    expect(invite?.status).toBe('PENDING');
    expect(invite?.toUserId).toBeNull();
  });

  it('creates a SHOPLESS owner when no shopName is sent (two-step onboarding)', async () => {
    const id = crypto.randomBytes(6).toString('hex');
    const result = await authService.register({
      email: `noshop+${id}@shopxy.test`,
      name: 'Pending Owner',
      password: 'Passw0rd!',
      role: 'OWNER',
    });
    if ('error' in result) throw new Error(`register failed: ${result.error}`);
    cleanupUserIds.push(result.user.id);

    expect(result.user.role).toBe('OWNER');
    const ownedShop = await prisma.shop.findUnique({ where: { ownerUserId: result.user.id }, select: { id: true } });
    expect(ownedShop).toBeNull();
    const membership = await prisma.shopMember.findUnique({ where: { userId: result.user.id }, select: { id: true } });
    expect(membership).toBeNull();
  });

  it('still creates a shop for an OWNER signup with no pending invite', async () => {
    const id = crypto.randomBytes(6).toString('hex');
    const result = await authService.register({
      email: `solo+${id}@shopxy.test`,
      name: 'Solo Owner',
      password: 'Passw0rd!',
      role: 'OWNER',
      shopName: `Solo Shop ${id}`,
    });
    if ('error' in result) throw new Error(`register failed: ${result.error}`);
    cleanupUserIds.push(result.user.id);

    const ownedShop = await prisma.shop.findUnique({ where: { ownerUserId: result.user.id }, select: { id: true } });
    expect(ownedShop).not.toBeNull();
    if (ownedShop) cleanupShopIds.push(ownedShop.id);

    const membership = await prisma.shopMember.findUnique({ where: { userId: result.user.id }, select: { role: true } });
    expect(membership?.role).toBe('OWNER');
  });
});
