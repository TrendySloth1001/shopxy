import { rateLimit, ipKeyGenerator } from 'express-rate-limit';

export interface AppLimiters {
  auth: ReturnType<typeof rateLimit>;
  public: ReturnType<typeof rateLimit>;
  image: ReturnType<typeof rateLimit>;
  upload: ReturnType<typeof rateLimit>;
  events: ReturnType<typeof rateLimit>;
  carouselWrite: ReturnType<typeof rateLimit>;
  webhook: ReturnType<typeof rateLimit>;
  perUser: ReturnType<typeof rateLimit>;
}

const perUserKeyGen = (
  req: { user?: { sub?: number | null } | null; ip?: string | null },
): string =>
  req.user?.sub != null
    ? `u:${req.user.sub}`
    : ipKeyGenerator(req.ip ?? '', 56);

export function buildLimiters(): AppLimiters {
  return {
    auth: rateLimit({
      windowMs: 60_000,
      max: 10,
      skipSuccessfulRequests: true,
      standardHeaders: true,
      legacyHeaders: false,
    }),
    public: rateLimit({
      windowMs: 60_000,
      max: 200,
      standardHeaders: true,
      legacyHeaders: false,
    }),
    image: rateLimit({
      windowMs: 60_000,
      max: 1000,
      standardHeaders: true,
      legacyHeaders: false,
    }),
    upload: rateLimit({
      windowMs: 60_000,
      max: 30,
      standardHeaders: true,
      legacyHeaders: false,
      keyGenerator: perUserKeyGen as never,
    }),
    events: rateLimit({
      windowMs: 60_000,
      max: 600,
      standardHeaders: true,
      legacyHeaders: false,
      keyGenerator: perUserKeyGen as never,
    }),
    carouselWrite: rateLimit({
      windowMs: 60_000,
      max: 60,
      standardHeaders: true,
      legacyHeaders: false,
      keyGenerator: perUserKeyGen as never,
    }),
    webhook: rateLimit({
      windowMs: 60_000,
      max: 300,
      standardHeaders: true,
      legacyHeaders: false,
    }),
    perUser: rateLimit({
      windowMs: 60_000,
      max: 600,
      standardHeaders: true,
      legacyHeaders: false,
      keyGenerator: perUserKeyGen as never,
    }),
  };
}
