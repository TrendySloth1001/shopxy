import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { authService } from '../../src/modules/auth/auth.service.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

describe('auth — device-remember token', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('mints a session from a remembered token and rotates it (single-use)', async () => {
    const ctx = await createTestUser();
    try {
      const { rememberToken } = await authService.issueRememberToken(ctx.userId, 'mac-desktop');
      expect(rememberToken).toHaveLength(64);

      const session = await authService.login(ctx.email, ctx.password);
      if ('error' in session) throw new Error(session.error);
      await authService.logout(session.refreshToken);

      const res = await authService.rememberLogin(rememberToken);
      if ('error' in res) throw new Error(res.error);
      expect(res.user.id).toBe(ctx.userId);
      expect(res.accessToken).toBeTruthy();
      expect(res.refreshToken).toBeTruthy();
      expect(res.rememberToken).not.toBe(rememberToken);

      const replay = await authService.rememberLogin(rememberToken);
      expect('error' in replay).toBe(true);

      const again = await authService.rememberLogin(res.rememberToken);
      expect('error' in again).toBe(false);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('forget revokes the token', async () => {
    const ctx = await createTestUser();
    try {
      const { rememberToken } = await authService.issueRememberToken(ctx.userId);
      await authService.forgetRememberToken(rememberToken);
      const res = await authService.rememberLogin(rememberToken);
      expect('error' in res).toBe(true);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('sign-out-everywhere and password change revoke remembered devices', async () => {
    const ctx = await createTestUser();
    try {
      const a = await authService.issueRememberToken(ctx.userId);
      await authService.logoutAll(ctx.userId);
      expect('error' in (await authService.rememberLogin(a.rememberToken))).toBe(true);

      const b = await authService.issueRememberToken(ctx.userId);
      await authService.changePassword(ctx.userId, ctx.password, 'NewPassw0rd!');
      expect('error' in (await authService.rememberLogin(b.rememberToken))).toBe(true);
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});
