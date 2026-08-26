import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import prisma from '../../src/infra/db/prisma.js';
import { buildApp } from '../../src/infra/http/app.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

describe('auth — GET and PATCH /auth/me return the same shape', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

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

      expect(after.body.name).toBe('Renamed Owner');
      expect(after.body.shopRole).toBe('OWNER');
      expect(after.body.shopId).toBe(before.body.shopId);
      expect(after.body.shopRoleName).toBe(before.body.shopRoleName);
      expect(after.body.shopPermissions).toEqual(before.body.shopPermissions);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

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
