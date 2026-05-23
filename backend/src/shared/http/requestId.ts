import { Request, Response, NextFunction } from 'express';
import { nanoid } from 'nanoid';
import { logger } from '../logging/logger.js';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      id?: string;
      log?: ReturnType<typeof logger.child>;
    }
  }
}

export function requestId(req: Request, res: Response, next: NextFunction): void {
  const id = (req.headers['x-request-id'] as string | undefined) ?? nanoid(12);
  req.id = id;
  req.log = logger.child({ reqId: id, method: req.method, url: req.url });
  res.setHeader('x-request-id', id);
  const start = Date.now();
  res.on('finish', () => {
    req.log?.info({ status: res.statusCode, ms: Date.now() - start }, 'request');
  });
  next();
}
