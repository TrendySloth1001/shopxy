import { describe, it, expect, afterAll, beforeEach, afterEach } from 'vitest';
import crypto from 'crypto';
import prisma from '../../src/infra/db/prisma.js';
import { authService } from '../../src/modules/auth/auth.service.js';

describe('signup — the email-OTP gate is mandatory', () => {
  const created: number[] = [];
  const original = process.env.ALLOW_UNVERIFIED_SIGNUP;

  beforeEach(() => {
    delete process.env.ALLOW_UNVERIFIED_SIGNUP;
  });
  afterEach(() => {
    if (original === undefined) delete process.env.ALLOW_UNVERIFIED_SIGNUP;
    else process.env.ALLOW_UNVERIFIED_SIGNUP = original;
    delete process.env.NODE_ENV_OVERRIDDEN_BY_TEST;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: { in: created } } });
    await prisma.$disconnect();
  });

  function freshEmail() {
    return `otpgate+${crypto.randomBytes(6).toString('hex')}@shopxy.test`;
  }

  it('refuses the signup when verification is unavailable — and writes NO user row', async () => {
    const email = freshEmail();
    const result = await authService.register({
      email,
      name: 'OTP Gate',
      password: 'S0me-Str0ng-Passw0rd!x9',
      role: 'OWNER',
    });

    expect('error' in result).toBe(true);
    if ('error' in result) expect(result.error).toBe('verification_unavailable');

    const user = await prisma.user.findUnique({ where: { email } });
    expect(user).toBeNull();
  });

  it('will not honour ALLOW_UNVERIFIED_SIGNUP in production', async () => {
    const email = freshEmail();
    const prevNodeEnv = process.env.NODE_ENV;
    process.env.ALLOW_UNVERIFIED_SIGNUP = 'true';
    process.env.NODE_ENV = 'production';
    try {
      const result = await authService.register({
        email,
        name: 'OTP Gate Prod',
        password: 'S0me-Str0ng-Passw0rd!x9',
        role: 'OWNER',
      });
      expect('error' in result).toBe(true);
      if ('error' in result) expect(result.error).toBe('verification_unavailable');
      expect(await prisma.user.findUnique({ where: { email } })).toBeNull();
    } finally {
      if (prevNodeEnv === undefined) delete process.env.NODE_ENV;
      else process.env.NODE_ENV = prevNodeEnv;
    }
  });

  it('the dev escape hatch still works outside production, so local signup is possible', async () => {
    const email = freshEmail();
    const prevNodeEnv = process.env.NODE_ENV;
    process.env.ALLOW_UNVERIFIED_SIGNUP = 'true';
    process.env.NODE_ENV = 'test';
    try {
      const result = await authService.register({
        email,
        name: 'OTP Gate Dev',
        password: 'S0me-Str0ng-Passw0rd!x9',
        role: 'OWNER',
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      expect(result.user?.email).toBe(email);
      if (result.user?.id) created.push(result.user.id);
    } finally {
      if (prevNodeEnv === undefined) delete process.env.NODE_ENV;
      else process.env.NODE_ENV = prevNodeEnv;
    }
  });
});
