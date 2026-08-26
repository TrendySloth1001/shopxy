import { describe, it, expect, afterAll } from 'vitest';
import crypto from 'crypto';
import bcrypt from 'bcrypt';
import prisma from '../../src/infra/db/prisma.js';
import { authService } from '../../src/modules/auth/auth.service.js';

const PASSWORD = 'Or1ginal-Passw0rd!x9';
const NEW_PASSWORD = 'Br4nd-New-Passw0rd!z7';

describe('auth — forgotten password reset', () => {
  const created: number[] = [];

  afterAll(async () => {
    await prisma.refreshToken.deleteMany({ where: { userId: { in: created } } });
    await prisma.rememberToken.deleteMany({ where: { userId: { in: created } } });
    await prisma.notification.deleteMany({ where: { userId: { in: created } } });
    await prisma.user.deleteMany({ where: { id: { in: created } } });
    await prisma.$disconnect();
  });

  async function makeUser() {
    const id = crypto.randomBytes(6).toString('hex');
    const email = `pwreset+${id}@shopxy.test`;
    const user = await prisma.user.create({
      data: {
        email,
        name: `Reset ${id}`,
        passwordHash: await bcrypt.hash(PASSWORD, 12),
        role: 'OWNER',
        acceptedAt: new Date(),
      },
      select: { id: true, email: true, passwordHash: true },
    });
    created.push(user.id);
    return user;
  }

  it('reports success for an address with no account — no enumeration oracle', async () => {
    const result = await authService.requestPasswordReset(
      `nobody+${crypto.randomBytes(6).toString('hex')}@shopxy.test`,
    );
    expect(result.ok).toBe(true);
  });

  it('reports the same success for an address that DOES exist', async () => {
    const user = await makeUser();
    const result = await authService.requestPasswordReset(user.email);
    expect(result.ok).toBe(true);
  });

  it('refuses to reset with a code that was never issued — password untouched', async () => {
    const user = await makeUser();
    const result = await authService.resetPassword(user.email, '000000', NEW_PASSWORD);

    expect('error' in result).toBe(true);

    const after = await prisma.user.findUnique({
      where: { id: user.id },
      select: { passwordHash: true },
    });
    expect(after?.passwordHash).toBe(user.passwordHash);
    expect(await bcrypt.compare(PASSWORD, after!.passwordHash)).toBe(true);
  });

  it('refuses a malformed / unknown account without touching anything', async () => {
    const result = await authService.resetPassword(
      `ghost+${crypto.randomBytes(6).toString('hex')}@shopxy.test`,
      '123456',
      NEW_PASSWORD,
    );
    expect('error' in result).toBe(true);
  });

  it('a failed reset leaves live sessions alone', async () => {
    const user = await makeUser();
    await prisma.refreshToken.create({
      data: {
        token: crypto.randomBytes(16).toString('hex'),
        family: crypto.randomUUID(),
        userId: user.id,
        expiresAt: new Date(Date.now() + 86_400_000),
      },
    });

    await authService.resetPassword(user.email, '000000', NEW_PASSWORD);

    const sessions = await prisma.refreshToken.count({ where: { userId: user.id } });
    expect(sessions).toBe(1);
  });
});
