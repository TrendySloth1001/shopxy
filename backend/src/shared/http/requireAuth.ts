import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface AuthPayload {
  sub: number;
  email: string;
  role: string;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthPayload;
    }
  }
}

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`${name} is required — refusing to start with a default secret`);
  return v;
}

const ACCESS_SECRET = requireEnv('JWT_ACCESS_SECRET');

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Authentication required' });
    return;
  }
  const token = header.slice(7);
  try {
    req.user = jwt.verify(token, ACCESS_SECRET) as unknown as AuthPayload;
    next();
  } catch {
    res.status(401).json({ error: 'Token expired or invalid' });
  }
}
