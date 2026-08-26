import { Prisma } from '@prisma/client';
import { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';
import { logger } from '../logging/logger.js';

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

export interface ApiErrorBody {
  code: string;
  message: string;
  details?: unknown;
  error: string;
}

function envelope(code: string, message: string, details?: unknown): ApiErrorBody {
  const body: ApiErrorBody = { code, message, error: code };
  if (details !== undefined) body.details = details;
  return body;
}

export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (err instanceof HttpError) {
    res.status(err.status).json(envelope(err.code, err.message, err.details));
    return;
  }

  if (err instanceof ZodError) {
    res.status(400).json(
      envelope(
        'VALIDATION_ERROR',
        'Validation failed',
        err.errors.map((issue) => ({
          path: issue.path.join('.'),
          message: issue.message,
        })),
      ),
    );
    return;
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    switch (err.code) {
      case 'P2002': {
        const target = (err.meta?.target as string[]) ?? [];
        res
          .status(409)
          .json(
            envelope(
              'DUPLICATE',
              `Duplicate value for: ${target.join(', ')}`,
              { target },
            ),
          );
        return;
      }
      case 'P2025':
        res.status(404).json(envelope('NOT_FOUND', 'Record not found'));
        return;
      case 'P2003':
        res
          .status(400)
          .json(envelope('FK_VIOLATION', 'Related record not found'));
        return;
    }
  }

  logger.error({ err }, 'unhandled error in request');
  const isProd = process.env.NODE_ENV === 'production';
  const detail = !isProd && err instanceof Error ? err.message : undefined;
  res
    .status(500)
    .json(envelope('INTERNAL_ERROR', 'Internal server error', detail));
}
