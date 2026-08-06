import express, { Request, Response } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { buildLimiters } from './limiters.js';
import { encodeIdsDeep } from '../../shared/ids/publicId.js';
import prisma from '../db/prisma.js';
import authRouter from '../../modules/auth/auth.routes.js';
import categoriesRouter from '../../modules/categories/categories.routes.js';
import hsnRouter from '../../modules/hsn/hsn.routes.js';
import productsRouter from '../../modules/products/products.routes.js';
import stockRouter from '../../modules/stock/stock.routes.js';
import stockAdjustmentsRouter from '../../modules/stock-adjustments/stock-adjustments.routes.js';
import dashboardRouter from '../../modules/dashboard/dashboard.routes.js';
import vendorsRouter from '../../modules/vendors/vendors.routes.js';
import partiesRouter from '../../modules/parties/parties.routes.js';
import quotationsRouter from '../../modules/quotations/quotations.routes.js';
import invoicesRouter from '../../modules/invoices/invoices.routes.js';
import numberingRouter from '../../modules/numbering/numbering.routes.js';
import pdfTemplatesRouter from '../../modules/pdfTemplates/pdfTemplates.routes.js';
import challansRouter from '../../modules/challans/challans.routes.js';
import uploadRouter from '../../modules/upload/upload.routes.js';
import avatarUploadRouter from '../../modules/upload/upload-avatar.routes.js';
import invitationsRouter from '../../modules/invitations/invitations.routes.js';
import notificationsRouter from '../../modules/notifications/notifications.routes.js';
import reportsRouter from '../../modules/reports/reports.routes.js';
import meRouter from '../../modules/me/me.routes.js';
import paymentsRouter from '../../modules/payments/payments.routes.js';
import customFieldsRouter from '../../modules/customFields/customFields.routes.js';
import shopRouter, {
  adminShopRouter,
  shopOnboardingRouter,
} from '../../modules/shop/shop.routes.js';
import shopPublicRouter from '../../modules/shop/shop.public.routes.js';
import {
  reviewsPublicRouter,
  reviewsAuthRouter,
  myReviewsRouter,
} from '../../modules/reviews/reviews.routes.js';
import {
  bannersPublicRouter,
  bannersAdminRouter,
  bannersMerchantRouter,
} from '../../modules/banners/banners.routes.js';
import { scanConsoleMerchantRouter } from '../../modules/scan-console/scan-console.routes.js';
import { posMerchantRouter } from '../../modules/pos/pos.routes.js';
import { cashierMerchantRouter } from '../../modules/cashier/cashier.routes.js';
import { platformBankOffersAdminRouter } from '../../modules/platform-bank-offers/platform-bank-offers.routes.js';
import {
  eventsIngestRouter,
  recentlyViewedRouter,
} from '../../modules/events/events.routes.js';
import {
  trendingPublicRouter,
  recommendationsRouter,
} from '../../modules/trending/trending.routes.js';
import {
  homePublicRouter,
  homePersonalRouter,
} from '../../modules/home/home.routes.js';
import {
  marketplaceProductRouter,
  marketplaceShopRouter,
  marketplaceCategoryRouter,
} from '../../modules/marketplace/marketplace.routes.js';
import addressesRouter from '../../modules/addresses/addresses.routes.js';
import cartRouter from '../../modules/cart/cart.routes.js';
import analyticsRouter from '../../modules/analytics/analytics.routes.js';
import {
  customerReturnsRouter,
  customerOrderReturnsSubmitRouter,
  merchantReturnsRouter,
} from '../../modules/returns/returns.routes.js';
import { customerWalletRouter } from '../../modules/wallet/wallet.routes.js';
import {
  walletTopUpRouter,
  paymentGatewayPublicRouter,
} from '../../modules/payment-gateway/payment-gateway.routes.js';
import {
  customerCouponsRouter,
  merchantCouponsRouter,
} from '../../modules/coupons/coupons.routes.js';
import searchRouter from '../../modules/search/search.routes.js';
import linkedAccountsRouter from '../../modules/linked-accounts/linked-accounts.routes.js';
import { requirePlatformAdmin } from '../../shared/http/requireRole.js';
import {
  ordersRouter,
  customerOrdersRouter,
} from '../../modules/purchase-requests/purchase-requests.routes.js';
import { getFileStream } from '../../modules/upload/upload.service.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import { requireRole } from '../../shared/http/requireRole.js';
import { requireArea } from '../../shared/http/permissions.js';
import { MERCHANT_AREAS } from '../../shared/http/merchantAreas.js';
import { resolveShop } from '../../shared/http/resolveShop.js';
import teamRouter from '../../modules/team/team.routes.js';
import { optionalAuth } from '../../shared/http/optionalAuth.js';
import { errorHandler } from '../../shared/http/errorHandler.js';
import { requestId } from '../../shared/http/requestId.js';

/// Builds the Express application without starting it. Pure factory so
/// supertest / integration tests can mount it on an ephemeral port and
/// the production entry point (`server.ts`) is just thin lifecycle glue.
export function buildApp(): express.Express {
  const app = express();

  app.set('trust proxy', 1);
  app.use(helmet());
  app.use(requestId);

  // CORS must be explicit. We refuse to fall back to `origin: true` with
  // `credentials: true` — that combination reflects ANY origin and lets a
  // hostile page on `attacker.com` issue authenticated requests with the
  // victim's browser session. In production we require CORS_ORIGINS;
  // otherwise we use a fixed local-dev origin list (no wildcard).
  const corsOriginsEnv = (process.env.CORS_ORIGINS ?? '').split(',').filter(Boolean);
  const allowedOrigins =
    corsOriginsEnv.length > 0
      ? corsOriginsEnv
      : (() => {
          if (process.env.NODE_ENV === 'production') {
            throw new Error(
              'CORS_ORIGINS is required in production — refusing to start with a permissive default. ' +
                'Set CORS_ORIGINS to a comma-separated origin list.',
            );
          }
          return [
            'http://localhost:3000',
            'http://localhost:5173',
            'http://localhost:8080',
          ];
        })();
  app.use(
    cors({
      origin: allowedOrigins,
      credentials: true,
      // Let browser clients read the perms-version header for live re-sync.
      exposedHeaders: ['X-Shop-Perms'],
    }),
  );

  // All rate limiters live in ./limiters so this file stays focused on
  // middleware order + route mounting. Tune limits there, not here. Built
  // here (before the webhook mount) so the unauthenticated webhook can carry
  // its own per-IP limiter (PR-L2).
  const {
    auth: authLimiter,
    public: publicLimiter,
    image: imageLimiter,
    upload: uploadLimiter,
    events: eventsLimiter,
    carouselWrite: carouselWriteLimiter,
    webhook: webhookLimiter,
    perUser: perUserLimiter,
  } = buildLimiters();

  // Payment-gateway webhooks + meta. MOUNTED BEFORE express.json so the
  // webhook handler sees the raw bytes (it carries its own express.raw) — HMAC
  // signature verification fails if the body is reparsed. Unauthenticated:
  // trust comes from the provider signature, so it's also before requireAuth.
  // PR-L2 — a per-IP rate limiter caps the unsigned-flood CPU sink (each
  // request runs an HMAC verify before fail-closed) without dropping the
  // sparse legit provider deliveries.
  app.use('/payment-gateway', webhookLimiter, paymentGatewayPublicRouter);

  app.use(express.json({ limit: '2mb' }));

  // OUTPUT side of opaque public IDs — the single source of truth for the whole
  // API. Controllers serialise raw Prisma rows (no DTO layer), so rather than
  // wrap every `res.json` in 25 modules, we override it once here to run every
  // JSON body through `encodeIdsDeep`, which tokenises `id`/`*Id` fields (money
  // Decimals, Dates and string ids left intact). Mounted AFTER the payment
  // gateway webhooks (line above) so provider-facing responses stay raw, and
  // gated by the PUBLIC_IDS flag inside `encodeIdsDeep` (off ⇒ identity ⇒ no
  // cost, no change). This closes the sequential-id leak across every endpoint
  // at once; per-route INPUT decoding is wired module-by-module (products first)
  // and only bites once the flag is flipped.
  app.use((_req: Request, res: Response, next) => {
    const originalJson = res.json.bind(res);
    res.json = (body: unknown) => originalJson(encodeIdsDeep(body));
    next();
  });

  app.get('/health', async (_req, res) => {
    try {
      await prisma.$queryRaw`SELECT 1`;
      res.status(200).json({ status: 'ok' });
    } catch {
      res.status(503).json({ status: 'degraded', db: 'down' });
    }
  });

  app.use('/auth', authLimiter, authRouter);
  app.use('/shops', publicLimiter, shopPublicRouter);

  // Public read of marketplace reviews. Must be registered before the
  // OWNER-gated /products mount below so this specific sub-path wins
  // and customers / unauthenticated visitors can read reviews.
  app.use('/products/:id/reviews', publicLimiter, reviewsPublicRouter);

  // Public read of marketplace banners (home feed surfaces).
  app.use('/banners', publicLimiter, bannersPublicRouter);

  // Public search — anyone can hit /search; the service attributes
  // to req.user.sub if the JWT happens to be present (we don't gate).
  app.use('/search', publicLimiter, searchRouter);

  // Public trending — anyone can hit /products/trending. Mounted
  // before the OWNER-gated /products router below so this sub-path
  // takes precedence for unauthenticated callers.
  app.use('/products', publicLimiter, trendingPublicRouter);

  // Customer home feed aggregator — one round trip for the whole page.
  // Mounted before requireAuth so the unauthenticated app can prime
  // the home tab and only escalate to personalised endpoints after
  // login.
  app.use('/home', publicLimiter, homePublicRouter);

  // Public marketplace reads: product detail + per-shop product list.
  // Namespaced under /marketplace/ to avoid colliding with the
  // OWNER-gated `/products/:id` PATCH/DELETE mounted after requireAuth,
  // which would otherwise be shadowed by a public GET that returns
  // 404 for unpublished items (breaking the merchant editor).
  // optionalAuth hydrates req.user when a Bearer token is present so
  // the own-shop guard can hide a logged-in merchant's own products
  // from their customer-side browse. Anonymous visitors still see
  // everything published.
  app.use('/marketplace/products', publicLimiter, optionalAuth, marketplaceProductRouter);
  app.use('/marketplace/shops', publicLimiter, optionalAuth, marketplaceShopRouter);
  app.use('/marketplace/categories', publicLimiter, optionalAuth, marketplaceCategoryRouter);

  // Categories taxonomy — anonymous-readable. The customer home page
  // calls `/categories/tree` on unauthenticated boot for the categories
  // rail; the previous behind-requireAuth mount returned 401 for guests
  // and broke the anonymous home. Writes inside the router self-gate
  // via requirePlatformAdmin (which fails closed when req.user is
  // absent), so it's safe to mount before requireAuth.
  app.use('/categories', publicLimiter, optionalAuth, categoriesRouter);

  const SAFE_FILENAME_RE = /^[a-zA-Z0-9_.-]+$/;
  app.get('/images/:filename', imageLimiter, async (req: Request, res: Response) => {
    const { filename } = req.params;
    if (!SAFE_FILENAME_RE.test(filename)) {
      res.status(400).json({ error: 'Invalid filename' });
      return;
    }
    const result = await getFileStream(filename);
    if (!result) {
      res.status(404).json({ error: 'Image not found' });
      return;
    }
    // UPLOAD-2: never reflect an arbitrary S3 Content-Type. Pin to an image
    // allowlist; anything else is served as a non-renderable download so a
    // mislabelled or smuggled payload (SVG/HTML) can't execute in our origin.
    const ALLOWED_IMAGE_TYPES = new Set(['image/webp', 'image/jpeg', 'image/png', 'image/gif']);
    const isImage = ALLOWED_IMAGE_TYPES.has(result.contentType);
    res.setHeader('Content-Type', isImage ? result.contentType : 'application/octet-stream');
    if (!isImage) res.setHeader('Content-Disposition', 'attachment');
    res.setHeader('Cache-Control', 'public, max-age=3600');
    // Belt + braces alongside the upload-side allowlist and the pinned type.
    res.setHeader('X-Content-Type-Options', 'nosniff');
    result.stream.pipe(res);
  });

  app.use(requireAuth);

  // Global authenticated backstop (CONFIG-1): a per-user rate ceiling on EVERY
  // authenticated route. Bespoke per-surface limiters (upload, events, …) still
  // apply their tighter caps on top of this; this just ensures no authed route
  // is entirely unbounded (heavy reports, invoice/PDF gen, id-enumeration).
  app.use(perUserLimiter);

  // Review writes are authenticated but NOT role-gated — customers
  // (the marketplace buyers) are the primary author. Registered before
  // the ownerOnly /products mount so this path takes precedence.
  app.use('/products/:id/reviews', reviewsAuthRouter);

  app.use('/me', meRouter);
  app.use('/me/orders', customerOrdersRouter);
  app.use('/me/orders/:parentId/returns', customerOrderReturnsSubmitRouter);
  app.use('/me/returns', customerReturnsRouter);
  app.use('/me/wallet', customerWalletRouter);
  // Authenticated wallet top-up via payment gateway (creates a checkout
  // session funding the caller's own wallet). Read-side returns the intent.
  app.use('/me/wallet/topup', walletTopUpRouter);
  app.use('/me/coupons', customerCouponsRouter);
  app.use('/me/recently-viewed', recentlyViewedRouter);
  app.use('/me/reviews', myReviewsRouter);
  app.use('/me/addresses', addressesRouter);
  app.use('/me/cart', cartRouter);
  // Auth-only avatar upload — shares the merchant uploader but lives
  // outside `ownerOnly` so customers can upload a profile photo too.
  app.use('/me/upload', uploadLimiter, avatarUploadRouter);

  // Customer event ingestion — no role gate; both OWNER (browsing
  // the marketplace) and CUSTOMER can post events. resolveShop is
  // intentionally not used; events attribute to the *user*, not a shop.
  app.use('/v1/events', eventsLimiter, eventsIngestRouter);

  // Per-user recommendations — auth-required (the slot reads from the
  // user's RecommendationCache row).
  app.use('/products', recommendationsRouter);

  // Authed home extras — recently-viewed + for-you recommendations.
  // Lives under /me/home so the public /home/feed stays cacheable.
  app.use('/me/home', homePersonalRouter);
  app.use('/notifications', notificationsRouter);
  app.use('/invitations', invitationsRouter);

  // Platform-admin surface: cross-shop curation tools (banners,
  // category taxonomy, collections). Gated by User.isPlatformAdmin,
  // independent of merchant/customer role.
  app.use('/admin/banners', requirePlatformAdmin, bannersAdminRouter);
  app.use(
    '/admin/platform-bank-offers',
    requirePlatformAdmin,
    platformBankOffersAdminRouter,
  );
  app.use('/admin/shops', requirePlatformAdmin, adminShopRouter);

  const ownerOnly = requireRole('OWNER');

  // Mount a merchant router behind ownerOnly + area-based permission
  // gating. The area is looked up from the central MERCHANT_AREAS
  // registry; a prefix that isn't registered throws at boot, so a new
  // merchant route literally cannot ship ungated (fail-closed). The
  // area gate enforces `<area>:view` on reads and `<area>:manage` on
  // writes; OWNER bypasses. `extra` carries per-mount middleware
  // (resolveShop, rate limiters) that must run before the router.
  const mountMerchant = (
    prefix: string,
    router: express.Router,
    extra: express.RequestHandler[] = [],
  ): void => {
    const area = MERCHANT_AREAS[prefix];
    if (!area) {
      throw new Error(
        `mountMerchant: no permission area mapped for "${prefix}". Add it ` +
          `to MERCHANT_AREAS (or OPEN_MERCHANT_MOUNTS if intentionally open).`,
      );
    }
    app.use(prefix, ownerOnly, requireArea(area), ...extra, router);
  };

  mountMerchant('/me/team', teamRouter, [resolveShop]);
  mountMerchant('/me/shop', shopRouter);
  // First-shop onboarding — ownerOnly but NOT area-gated (a shopless OWNER
  // has no ShopMember yet, which requireArea('shop') would reject).
  app.use('/me/onboarding', ownerOnly, shopOnboardingRouter);
  mountMerchant('/me/banners', bannersMerchantRouter, [
    resolveShop,
    carouselWriteLimiter,
  ]);
  mountMerchant('/me/scan-console', scanConsoleMerchantRouter, [resolveShop]);
  mountMerchant('/me/pos', posMerchantRouter, [resolveShop]);
  mountMerchant('/me/cashier', cashierMerchantRouter, [resolveShop]);
  mountMerchant('/me/analytics', analyticsRouter, [resolveShop]);
  mountMerchant('/me/coupons-admin', merchantCouponsRouter, [resolveShop]);
  mountMerchant('/custom-fields', customFieldsRouter);
  // HSN/SAC rate master — read-only reference data behind the product
  // editor's "type a code, get the GST rate" auto-fill. Authenticated but
  // NOT merchant-area-gated: it's a public tariff, every role that can open
  // a product or an invoice needs it, and a shopless caller simply sees the
  // platform tier (see callerShopId in hsn.controller).
  app.use('/hsn', hsnRouter);
  mountMerchant('/products', productsRouter, [resolveShop]);
  mountMerchant('/stock', stockRouter);
  mountMerchant('/stock-adjustments', stockAdjustmentsRouter);
  mountMerchant('/dashboard', dashboardRouter, [resolveShop]);
  mountMerchant('/vendors', vendorsRouter);
  mountMerchant('/parties', partiesRouter);
  mountMerchant('/quotations', quotationsRouter);
  mountMerchant('/invoices', invoicesRouter);
  mountMerchant('/numbering', numberingRouter);
  mountMerchant('/pdf-templates', pdfTemplatesRouter);
  mountMerchant('/challans', challansRouter);
  // Upload is shared infra (product images, etc.) — intentionally open to
  // any team member (see OPEN_MERCHANT_MOUNTS); not area-gated.
  app.use('/upload', ownerOnly, uploadLimiter, uploadRouter);
  mountMerchant('/reports', reportsRouter, [resolveShop]);
  // Mounted BEFORE /orders so the returns sub-path wins over /orders/:id.
  mountMerchant('/orders/returns', merchantReturnsRouter, [resolveShop]);
  mountMerchant('/orders', ordersRouter);
  mountMerchant('/linked-account', linkedAccountsRouter, [resolveShop]);
  mountMerchant('/payments', paymentsRouter);

  app.use(errorHandler);

  return app;
}
