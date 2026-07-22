import prisma from '../../infra/db/prisma.js';
import { revokeSession } from '../../shared/sessionRevocation.js';
import { deviceLabel } from './deviceContext.js';

/**
 * "Your devices" — read + revoke the sessions behind a user's account.
 *
 * A session == a refresh-token *family* (the `sid` an access token carries).
 * Rotation keeps one live token per family, so each active row is one session.
 * Revoking deletes the family's token AND calls {@link revokeSession} so the
 * paired access token dies immediately, not just at its 15-min TTL.
 */

export interface SessionView {
  id: number;
  device: string; // friendly label parsed from the user-agent
  where: string | null; // masked IP captured at sign-in
  createdAt: Date;
  lastUsedAt: Date | null;
  current: boolean; // the session making this request
}

export const sessionsService = {
  /** Active sessions for the user, newest-used first; flags the current one. */
  async list(userId: number, currentSid?: string): Promise<SessionView[]> {
    const rows = await prisma.refreshToken.findMany({
      where: { userId, expiresAt: { gt: new Date() } },
      orderBy: [{ lastUsedAt: 'desc' }, { createdAt: 'desc' }],
      select: {
        id: true,
        family: true,
        userAgent: true,
        ipMasked: true,
        createdAt: true,
        lastUsedAt: true,
      },
    });
    return rows.map((r) => ({
      id: r.id,
      device: deviceLabel(r.userAgent),
      where: r.ipMasked,
      createdAt: r.createdAt,
      lastUsedAt: r.lastUsedAt,
      current: !!currentSid && r.family === currentSid,
    }));
  },

  /**
   * Revoke one session by row id (must belong to the caller). Kills the whole
   * family + its access token. Returns false if it isn't the user's session.
   */
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

  /** Revoke every session except the current one. Returns how many were revoked. */
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
