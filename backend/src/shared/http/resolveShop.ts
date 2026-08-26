import { Request, Response, NextFunction } from 'express';
import prisma from '../../infra/db/prisma.js';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      shopId?: number;
    }
  }
}

export async function loadShopMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (typeof req.shopId === 'number') {
    next();
    return;
  }

  const userId = req.user?.sub;
  if (!userId) {
    res.status(401).json({ error: 'Authentication required' });
    return;
  }
  if (typeof req.user?.shopId === 'number') {
    req.shopId = req.user.shopId;
    next();
    return;
  }
  const membership = await prisma.shopMember.findUnique({
    where: { userId },
    select: { shopId: true },
  });
  if (!membership) {
    res.status(404).json({ error: 'No shop linked to this account' });
    return;
  }
  req.shopId = membership.shopId;
  next();
}

export const resolveShop = loadShopMiddleware;
