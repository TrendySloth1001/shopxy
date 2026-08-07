import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import prisma from '../../src/infra/db/prisma.js';
import { buildApp } from '../../src/infra/http/app.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

/// `GET /auth/me` and `PATCH /auth/me` describe the same resource, and clients
/// assign either response straight onto their session user. They must agree on
/// shape.
///
/// They didn't. PATCH returned the bare profile row — no `shopRole`/`shopId`/
/// `shopPermissions`, since those live on ShopMember rather than User and are
/// re-attached per request. A client can't tell a missing field from a
/// genuinely shopless account, so the Flutter merchant app's auth gate read
/// `shopRole: null` after a profile save and dropped a shop owner onto the
/// "set up your shop" screen. Losing `shopPermissions` would have blanked
/// every permission-gated tile at the same time.

describe('auth — GET and PATCH /auth/me return the same shape', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  /// `createTestUser` makes a User + Shop but no ShopMember, and the team scope
  /// is hydrated from ShopMember alone — without this the fixture's `shopRole`
  /// is null on BOTH responses and the regression hides.
  async function makeOwner() {
    const ctx = await createTestUser();
    await prisma.shopMember.create({
      data: {
        shopId: ctx.shopId,
        userId: ctx.userId,
        role: 'OWNER',
        roleName: null,
        permissions: [],
      },
    });
    return ctx;
  }

  it('PATCH keeps the team scope that GET reports', async () => {
    const app = buildApp();
    const ctx = await makeOwner();
    try {
      const auth = { Authorization: `Bearer ${ctx.accessToken}` };

      const before = await request(app).get('/auth/me').set(auth);
      expect(before.status).toBe(200);
      expect(before.body.shopRole).toBe('OWNER');
      expect(before.body.shopId).toBeTruthy();

      const after = await request(app)
        .patch('/auth/me')
        .set(auth)
        .send({ name: 'Renamed Owner' });
      expect(after.status).toBe(200);

      // The edit landed…
      expect(after.body.name).toBe('Renamed Owner');
      // …and the team scope survived it. This is the bug: `shopRole` going
      // null here is what bounced an owner to the onboarding screen.
      expect(after.body.shopRole).toBe('OWNER');
      expect(after.body.shopId).toBe(before.body.shopId);
      expect(after.body.shopRoleName).toBe(before.body.shopRoleName);
      expect(after.body.shopPermissions).toEqual(before.body.shopPermissions);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // The invariant behind the specific fields above: if a future field is added
  // to one handler and not the other, a client assigning the PATCH response
  // silently loses it. Comparing key sets catches that without this test
  // needing to know what the field is.
  it('PATCH returns no fewer keys than GET', async () => {
    const app = buildApp();
    const ctx = await makeOwner();
    try {
      const auth = { Authorization: `Bearer ${ctx.accessToken}` };
      const before = await request(app).get('/auth/me').set(auth);
      const after = await request(app)
        .patch('/auth/me')
        .set(auth)
        .send({ name: 'Renamed Owner' });

      const missing = Object.keys(before.body).filter(
        (k) => !(k in after.body),
      );
      expect(missing, `PATCH /auth/me dropped: ${missing.join(', ')}`).toEqual(
        [],
      );
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // A staffer's grants are what gate the merchant UI's write affordances —
  // losing them on a profile save would silently read as "you may do nothing".
  it('preserves a staff member’s granted permissions', async () => {
    const app = buildApp();
    const ctx = await createTestUser();
    try {
      await prisma.shopMember.create({
        data: {
          shopId: ctx.shopId,
          userId: ctx.userId,
          role: 'STAFF',
          roleName: 'Cashier',
          permissions: ['products:view', 'invoices:manage'],
        },
      });
      const auth = { Authorization: `Bearer ${ctx.accessToken}` };

      const after = await request(app)
        .patch('/auth/me')
        .set(auth)
        .send({ name: 'Renamed Staff' });

      expect(after.status).toBe(200);
      expect(after.body.shopRole).toBe('STAFF');
      expect(after.body.shopRoleName).toBe('Cashier');
      expect(after.body.shopPermissions).toEqual([
        'products:view',
        'invoices:manage',
      ]);
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});
