import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { authService } from '../../src/modules/auth/auth.service.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

describe('auth.service.updateProfile — GST effective date guard', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('first-time GSTIN with no effective date is rejected', async () => {
    const ctx = await createTestUser();
    try {
      const result = await authService.updateProfile(ctx.userId, {
        shopGstin: '27ABCDE1234F1Z5',
      });
      expect(result).toEqual({ error: 'GST_EFFECTIVE_DATE_REQUIRED' });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('first-time GSTIN with an effective date succeeds', async () => {
    const ctx = await createTestUser();
    try {
      const result = await authService.updateProfile(ctx.userId, {
        shopGstin: '27ABCDE1234F1Z5',
        gstEffectiveFrom: '2026-08-10',
      });
      expect(result && 'error' in result).toBe(false);
      const row = await prisma.user.findUniqueOrThrow({ where: { id: ctx.userId } });
      expect(row.shopGstin).toBe('27ABCDE1234F1Z5');
      expect(row.registrationType).toBe('REGULAR');
      expect(row.gstEffectiveFrom?.toISOString().slice(0, 10)).toBe('2026-08-10');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('an unrelated edit on an already-registered shop succeeds without the field', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: {
          shopGstin: '27ABCDE1234F1Z5',
          registrationType: 'REGULAR',
          gstEffectiveFrom: new Date('2026-08-10'),
        },
      });
      const result = await authService.updateProfile(ctx.userId, { shopCity: 'Pune' });
      expect(result && 'error' in result).toBe(false);
      const row = await prisma.user.findUniqueOrThrow({ where: { id: ctx.userId } });
      expect(row.shopCity).toBe('Pune');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('changing an existing GSTIN to a different value with no date is rejected', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', registrationType: 'REGULAR' },
      });
      const result = await authService.updateProfile(ctx.userId, {
        shopGstin: '29ABCDE1234F1Z5',
      });
      expect(result).toEqual({ error: 'GST_EFFECTIVE_DATE_REQUIRED' });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('an explicit null effective date alongside a new GSTIN is rejected, not treated as bypassing the guard', async () => {
    const ctx = await createTestUser();
    try {
      const result = await authService.updateProfile(ctx.userId, {
        shopGstin: '27ABCDE1234F1Z5',
        gstEffectiveFrom: null,
      });
      expect(result).toEqual({ error: 'GST_EFFECTIVE_DATE_REQUIRED' });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('a new GSTIN registering as COMPOSITION does not require an effective date', async () => {
    const ctx = await createTestUser();
    try {
      const result = await authService.updateProfile(ctx.userId, {
        shopGstin: '27ABCDE1234F1Z5',
        registrationType: 'COMPOSITION',
      });
      expect(result && 'error' in result).toBe(false);
      const row = await prisma.user.findUniqueOrThrow({ where: { id: ctx.userId } });
      expect(row.registrationType).toBe('COMPOSITION');
      expect(row.gstEffectiveFrom).toBeNull();
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('clearing the GSTIN back to null never requires an effective date', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: {
          shopGstin: '27ABCDE1234F1Z5',
          registrationType: 'REGULAR',
          gstEffectiveFrom: new Date('2026-08-10'),
        },
      });
      const result = await authService.updateProfile(ctx.userId, { shopGstin: null });
      expect(result && 'error' in result).toBe(false);
      const row = await prisma.user.findUniqueOrThrow({ where: { id: ctx.userId } });
      expect(row.shopGstin).toBeNull();
      expect(row.registrationType).toBe('UNREGISTERED');
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});
