import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import crypto from 'crypto';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';

const app = buildApp();

const cleanupUserIds: number[] = [];
const cleanupShopIds: number[] = [];

afterAll(async () => {
  await prisma.shopMember.deleteMany({ where: { userId: { in: cleanupUserIds } } }).catch(() => {});
  await prisma.invitation.deleteMany({ where: { fromUserId: { in: cleanupUserIds } } }).catch(() => {});
  await prisma.notification.deleteMany({ where: { userId: { in: cleanupUserIds } } }).catch(() => {});
  await prisma.shop.deleteMany({ where: { id: { in: cleanupShopIds } } }).catch(() => {});
  await prisma.user.deleteMany({ where: { id: { in: cleanupUserIds } } }).catch(() => {});
  await prisma.$disconnect();
});

async function makeVictimShopWithPendingInvite(invitedEmail: string) {
  const id = crypto.randomBytes(6).toString('hex');
  const owner = await prisma.user.create({
    data: { email: `victim-owner+${id}@shopxy.test`, name: `Victim Owner ${id}`, passwordHash: 'x', role: 'OWNER', acceptedAt: new Date() },
    select: { id: true },
  });
  cleanupUserIds.push(owner.id);
  const shop = await prisma.shop.create({
    data: { ownerUserId: owner.id, name: `Victim Shop ${id}`, slug: `victim-shop-${id}` },
    select: { id: true },
  });
  cleanupShopIds.push(shop.id);
  await prisma.shopMember.create({ data: { shopId: shop.id, userId: owner.id, role: 'OWNER' } });

  await prisma.invitation.create({
    data: {
      shopId: shop.id,
      fromUserId: owner.id,
      toEmail: invitedEmail.toLowerCase(),
      linkType: 'TEAM',
      teamRole: 'MANAGER',
      teamRoleName: 'Manager',
      teamPermissions: ['invoices:manage', 'parties:manage', 'products:manage', 'reports:view'],
      status: 'PENDING',
      token: `tok-${id}`,
      expiresAt: new Date(Date.now() + 86_400_000),
    },
  });
  return { ownerId: owner.id, shopId: shop.id };
}

describe('RED-TEAM regression — TEAM invite hijack via unverified email (AUTH-1) is BLOCKED', () => {
  it('an attacker who registers an invited email gets NO membership, NO victim-shop access; invite stays PENDING', async () => {
    const invitedEmail = `newhire-${crypto.randomBytes(4).toString('hex')}@victim-corp.test`;
    const { shopId } = await makeVictimShopWithPendingInvite(invitedEmail);

    const attackerPassword = 'Att4cker!Owned';
    const res = await request(app)
      .post('/auth/register')
      .send({
        email: invitedEmail,
        name: 'Mallory The Attacker',
        password: attackerPassword,
        role: 'OWNER',
        shopName: 'Decoy Shop',
        acceptedTerms: true,
        acceptedPrivacy: true,
      });

    expect(res.status).toBe(201);
    const attackerUserId: number = res.body.user.id;
    cleanupUserIds.push(attackerUserId);

    const membership = await prisma.shopMember.findUnique({
      where: { userId: attackerUserId },
      select: { shopId: true, role: true },
    });
    expect(membership).toBeNull();

    const ownShop = await prisma.shop.findUnique({
      where: { ownerUserId: attackerUserId },
      select: { id: true },
    });
    expect(ownShop).toBeNull();

    const invite = await prisma.invitation.findFirst({
      where: { toEmail: invitedEmail.toLowerCase() },
      select: { status: true, toUserId: true },
    });
    expect(invite!.status).toBe('PENDING');
    expect(invite!.toUserId).toBeNull();

    if (res.body.accessToken) {
      const apiRes = await request(app)
        .get('/products?limit=5')
        .set('Authorization', `Bearer ${res.body.accessToken}`);
      expect(apiRes.status).not.toBe(200);
      void shopId;
    }

    // eslint-disable-next-line no-console
    console.log(
      `\n  [FIX VERIFIED] attacker user #${attackerUserId} registered the invited email but received ` +
        `NO shop membership, the invite stayed PENDING/unbound, and the token cannot read victim shop #${shopId}.\n`,
    );
  });
});
