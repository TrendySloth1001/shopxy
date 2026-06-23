import { rateLimit, ipKeyGenerator } from 'express-rate-limit';

/// All Express rate-limiters in one place. Built once at app start by
/// `buildLimiters()` and threaded through `buildApp` so the route
/// mounting stays focused on URL → router glue. Limits are tuned by
/// surface; bump them here, not at the mount site.

export interface AppLimiters {
  /// Aggressive cap on /auth: brute-force / credential-stuffing guard.
  auth: ReturnType<typeof rateLimit>;
  /// Per-IP read budget for unauth surfaces (home feed, search, browse).
  /// 200/min accommodates a home cold-start (~10 parallel rails) plus a
  /// burst of product detail pulls; scrape patterns trip the cap.
  public: ReturnType<typeof rateLimit>;
  /// Image reads — cached for an hour, so the cap is loosened to not
  /// punish a single product gallery with ~20 images.
  image: ReturnType<typeof rateLimit>;
  /// Per-user write limiter for /me/upload. Sharp re-encode + S3 PUT is
  /// expensive; key on req.user.sub (post-auth) with an ipKey fallback.
  upload: ReturnType<typeof rateLimit>;
  /// Per-user limiter for /v1/events ingestion — bounded at a comfortable
  /// browse ceiling, bots that exceed get 429s.
  events: ReturnType<typeof rateLimit>;
  /// Per-user limiter for merchant carousel writes (and the legacy
  /// /me/banners shim). 60/min is far above an editor session and trips
  /// scripted abuse.
  carouselWrite: ReturnType<typeof rateLimit>;
  /// Per-IP limiter for the UNAUTHENTICATED payment webhook. Each request
  /// runs an HMAC verify before fail-closed, so an unsigned flood is a CPU
  /// sink (PR-L2). 300/min/IP is well above any real provider delivery rate
  /// (Razorpay retries are sparse) but caps a single-source flood.
  webhook: ReturnType<typeof rateLimit>;
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
      // Don't 429 a legit provider with a banner the gateway won't read; the
      // limiter still drops the excess. Per-IP (no user on this surface).
      standardHeaders: true,
      legacyHeaders: false,
    }),
  };
}
