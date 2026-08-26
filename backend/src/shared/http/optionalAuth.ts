import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AuthPayload } from './requireAuth.js';
import { JWT_ACCESS_SECRET as ACCESS_SECRET } from '../authSecrets.js';

export function optionalAuth(req: Request, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    next();
    return;
  }
  const token = header.slice(7);
  try {
    req.user = jwt.verify(token, ACCESS_SECRET, {
      algorithms: ['HS256'],
    }) as unknown as AuthPayload;
  } catch {
  }
  next();
}
