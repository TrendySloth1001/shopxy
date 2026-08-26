import prisma from '../../infra/db/prisma.js';
import { revokeSession } from '../../shared/sessionRevocation.js';
import { deviceLabel } from './deviceContext.js';

export interface SessionView {
  id: number;
  device: string;
  where: string | null;
  createdAt: Date;
  lastUsedAt: Date | null;
  current: boolean;
}

export const sessionsService = {
  async list(userId: number, currentSid?: string): Promise<SessionView[]> {
    const rows = await prisma.refreshToken.findMany({
      where: { userId, expiresAt: { gt: new Date() } },
      orderBy: [{ lastUsedAt: 'desc' }, { createdAt: 'desc' }],
      select: {
        id: true,
        family: true,
        userAgent: true,
        deviceName: true,
        ipMasked: true,
        createdAt: true,
        lastUsedAt: true,
      },
    });
    return rows.map((r) => ({
      id: r.id,
      device: r.deviceName ?? deviceLabel(r.userAgent),
      where: r.ipMasked,
      createdAt: r.createdAt,
      lastUsedAt: r.lastUsedAt,
      current: !!currentSid && r.family === currentSid,
    }));
  },

  async revoke(userId: number, sessionId: number): Promise<boolean> {
    const row = await prisma.refreshToken.findFirst({
      where: { id: sessionId, userId },
      select: { family: true },
    });
    if (!row) return false;
    await prisma.refreshToken.deleteMany({ where: { userId, family: row.family } });
    await revokeSession(row.family);
    return true;
  },

  async revokeOthers(userId: number, currentSid?: string): Promise<number> {
    const rows = await prisma.refreshToken.findMany({
      where: { userId, ...(currentSid ? { family: { not: currentSid } } : {}) },
      select: { family: true },
    });
    const families = [...new Set(rows.map((r) => r.family))];
    if (families.length === 0) return 0;
    await prisma.refreshToken.deleteMany({ where: { userId, family: { in: families } } });
    await Promise.all(families.map((f) => revokeSession(f)));
    return families.length;
  },
};
