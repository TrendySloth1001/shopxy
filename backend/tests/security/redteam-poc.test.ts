/**
 * RED-TEAM PROOF-OF-CONCEPT — AUTH-1 / AUTH-INVITE-1
 * ===================================================
 * Live, in-sandbox exploit for the unverified-email TEAM-invite hijack.
 *
 * THREAT: a merchant invites a real new hire (or links a customer/vendor) by
 * email. The backend's `register()` claims a pending TEAM invitation purely by
 * matching `toEmail` — there is NO email-ownership verification anywhere in the
 * system. So ANY unauthenticated attacker who knows or guesses the invited
 * email can register that address with a password THEY control and is
 * atomically provisioned as STAFF of the victim's shop with the invited
 * permission set — and the real invitee is permanently locked out.
 *
 * This test fires the attack over the real HTTP wire against the in-process
 * `buildApp()` (no external network, no real money, self-cleaning rows). If it
 * PASSES, the exploit is confirmed. After we ship the fix, this test should
 * FLIP — the attacker register must NOT yield a victim-shop membership.
 *
 * Run ONLY this file (the wider suite has ~44 pre-existing env failures):
 *   npx vitest run tests/security/redteam-poc.test.ts
 */
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

  // The merchant invites a real new hire at `invitedEmail` as a MANAGER with a
  // broad, sensitive permission set. This is the legitimate, expected action.
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

    // ── ATTACK ── No auth header. Attacker supplies the victim's invited email
    // but a password THEY choose, posing as a normal merchant signup.
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

    // The request still creates a plain SHOPLESS account (201) — but it must
    // grant NO access to the victim's shop. (Pre-fix this returned a live
    // session bound to a STAFF/Manager seat in the victim shop — the exploit.)
    expect(res.status).toBe(201);
    const attackerUserId: number = res.body.user.id;
    cleanupUserIds.push(attackerUserId);

    // 1) NO PRIVILEGE GRANT — the attacker is a member of NO shop at all.
    const membership = await prisma.shopMember.findUnique({
      where: { userId: attackerUserId },
      select: { shopId: true, role: true },
    });
    expect(membership).toBeNull();

    // 2) NO own shop either (shopless, so a legit token accept isn't blocked).
    const ownShop = await prisma.shop.findUnique({
      where: { ownerUserId: attackerUserId },
      select: { id: true },
    });
    expect(ownShop).toBeNull();

    // 3) The pending invite is UNTOUCHED — still PENDING, still unbound, so it
    //    can only be claimed by presenting the token from the invite link.
    const invite = await prisma.invitation.findFirst({
      where: { toEmail: invitedEmail.toLowerCase() },
      select: { status: true, toUserId: true },
    });
    expect(invite!.status).toBe('PENDING');
    expect(invite!.toUserId).toBeNull();

    // 4) The attacker's token grants NO access to the victim tenant. With no
    //    membership there is no shop to resolve, so the merchant API does NOT
    //    return 200 victim data (pre-fix this was a 200 catalog read).
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
