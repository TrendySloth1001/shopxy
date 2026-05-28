import { Prisma } from '@prisma/client';
import { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';
import { logger } from '../logging/logger.js';

/// Typed domain error services can throw to return a non-2xx without
/// the controller writing status-mapping boilerplate. Always reaches
/// the response via errorHandler so the envelope shape stays uniform.
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

/// Canonical error envelope. Every backend response with a non-2xx
/// status code carries this shape so the Flutter apps can branch on a
/// stable machine code instead of pattern-matching English strings.
///
/// `error` is kept as a redundant alias of `code` for one release to
/// avoid breaking existing clients that look at `body.error`. After
/// both apps have shipped a build that prefers `code`, drop the alias.
export interface ApiErrorBody {
  /// Machine-readable code, SCREAMING_SNAKE. Stable across releases.
  code: string;
  /// Human-readable message. Subject to copy changes.
  message: string;
  /// Optional structured payload — per-field issues for validation,
  /// per-line corrections for PRICE_DRIFT, etc.
  details?: unknown;
  /// @deprecated Alias of `code`; remove once both apps prefer `code`.
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
  // In non-production envs surface the underlying error message in the
  // response body so the merchant editor's snackbar shows something
  // useful instead of a generic "Internal error". Production still
  // returns the bare envelope to avoid leaking internals.
  const isProd = process.env.NODE_ENV === 'production';
  const detail = !isProd && err instanceof Error ? err.message : undefined;
  res
    .status(500)
    .json(envelope('INTERNAL_ERROR', 'Internal server error', detail));
}
