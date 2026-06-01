import express, { Request, Response } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { buildLimiters } from './limiters.js';
import prisma from '../db/prisma.js';
import authRouter from '../../modules/auth/auth.routes.js';
import categoriesRouter from '../../modules/categories/categories.routes.js';
import productsRouter from '../../modules/products/products.routes.js';
import stockRouter from '../../modules/stock/stock.routes.js';
import stockAdjustmentsRouter from '../../modules/stock-adjustments/stock-adjustments.routes.js';
import dashboardRouter from '../../modules/dashboard/dashboard.routes.js';
import vendorsRouter from '../../modules/vendors/vendors.routes.js';
import partiesRouter from '../../modules/parties/parties.routes.js';
import cautionRequestsRouter from '../../modules/caution/caution-requests.routes.js';
import quotationsRouter from '../../modules/quotations/quotations.routes.js';
import invoicesRouter from '../../modules/invoices/invoices.routes.js';
import challansRouter from '../../modules/challans/challans.routes.js';
import uploadRouter from '../../modules/upload/upload.routes.js';
import avatarUploadRouter from '../../modules/upload/upload-avatar.routes.js';
import invitationsRouter from '../../modules/invitations/invitations.routes.js';
import notificationsRouter from '../../modules/notifications/notifications.routes.js';
import reportsRouter from '../../modules/reports/reports.routes.js';
import meRouter from '../../modules/me/me.routes.js';
import paymentsRouter from '../../modules/payments/payments.routes.js';
import customFieldsRouter from '../../modules/customFields/customFields.routes.js';
import shopRouter, { adminShopRouter } from '../../modules/shop/shop.routes.js';
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
import {
  carouselsAdminRouter,
  carouselsMerchantRouter,
} from '../../modules/carousels/carousels.routes.js';
import {
  flashSalesMerchantRouter,
  flashSalesPublicRouter,
} from '../../modules/flash-sales/flash-sales.routes.js';
import {
  brandSpotlightPublicRouter,
  brandSpotlightMerchantRouter,
  brandSpotlightAdminRouter,
} from '../../modules/brand-spotlight/brand-spotlight.routes.js';
import {
  collectionsPublicRouter,
  collectionsAdminRouter,
} from '../../modules/collections/collections.routes.js';
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
import promotionsRouter from '../../modules/promotions/promotions.routes.js';
import linkedAccountsRouter from '../../modules/linked-accounts/linked-accounts.routes.js';
import { requirePlatformAdmin } from '../../shared/http/requireRole.js';
import {
  ordersRouter,
  customerOrdersRouter,
} from '../../modules/purchase-requests/purchase-requests.routes.js';
import { getFileStream } from '../../modules/upload/upload.service.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import { requireRole } from '../../shared/http/requireRole.js';
import { resolveShop } from '../../shared/http/resolveShop.js';
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
    }),
  );

  // Payment-gateway webhooks + meta. MOUNTED BEFORE express.json so the
  // webhook handler sees the raw bytes (it carries its own express.raw) — HMAC
  // signature verification fails if the body is reparsed. Unauthenticated:
  // trust comes from the provider signature, so it's also before requireAuth.
  app.use('/payment-gateway', paymentGatewayPublicRouter);

  app.use(express.json({ limit: '2mb' }));

  // All rate limiters live in ./limiters so this file stays focused on
  // middleware order + route mounting. Tune limits there, not here.
  const {
    auth: authLimiter,
    public: publicLimiter,
    image: imageLimiter,
    upload: uploadLimiter,
    events: eventsLimiter,
    carouselWrite: carouselWriteLimiter,
  } = buildLimiters();

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

  // Public read of currently-running flash sales for the home feed.
  app.use('/flash-deals', publicLimiter, flashSalesPublicRouter);

  // Public read of currently-running brand spotlights + editorial
  // collections — both surface on the unauthenticated home feed.
  app.use('/brand-spotlights', publicLimiter, brandSpotlightPublicRouter);
  app.use('/collections', publicLimiter, collectionsPublicRouter);

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
    res.setHeader('Content-Type', result.contentType);
    res.setHeader('Cache-Control', 'public, max-age=3600');
    // Prevent the browser from MIME-sniffing a misnamed payload (e.g.
    // an SVG/HTML smuggled through a future upload path) and executing
    // it in our origin. Belt + braces alongside upload-side allowlist.
    res.setHeader('X-Content-Type-Options', 'nosniff');
    result.stream.pipe(res);
  });

  app.use(requireAuth);

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
  app.use('/admin/carousels', requirePlatformAdmin, carouselsAdminRouter);
  app.use('/admin/brand-spotlight', requirePlatformAdmin, brandSpotlightAdminRouter);
  app.use('/admin/collections', requirePlatformAdmin, collectionsAdminRouter);
  app.use(
    '/admin/platform-bank-offers',
    requirePlatformAdmin,
    platformBankOffersAdminRouter,
  );
  app.use('/admin/shops', requirePlatformAdmin, adminShopRouter);

  const ownerOnly = requireRole('OWNER');
  app.use('/me/shop', ownerOnly, shopRouter);
  // Merchant-owned flash deals — resolveShop attaches req.shopId; the
  // service scopes every read/write through Product.shopId so a wrong
  // ownerId can't reach into another shop's promotions.
  app.use('/me/flash-deals', ownerOnly, resolveShop, flashSalesMerchantRouter);
  // Merchant carousels (Phase 2) — named carousel groups + nested
  // slides. carouselWriteLimiter caps the per-user write rate. Every
  // slide endpoint resolves :carouselId to its shopId before any DB
  // mutation, so cross-shop probes return 404.
  app.use(
    '/me/carousels',
    ownerOnly,
    resolveShop,
    carouselWriteLimiter,
    carouselsMerchantRouter,
  );
  // Legacy merchant slide CRUD — kept as a thin shim during the
  // Phase 1→7 deprecation window so existing merchant builds keep
  // working. New writes should target /me/carousels/:cid/slides
  // instead. carouselWriteLimiter retrofitted to close the gap
  // identified in the Phase 1 security audit.
  app.use(
    '/me/banners',
    ownerOnly,
    resolveShop,
    carouselWriteLimiter,
    bannersMerchantRouter,
  );
  app.use('/me/analytics', ownerOnly, resolveShop, analyticsRouter);
  app.use('/me/promotions', ownerOnly, resolveShop, promotionsRouter);
  // Merchant coupon CRUD. Lives at `/me/coupons-admin` so it doesn't
  // collide with the customer-facing `/me/coupons` listing surface.
  app.use('/me/coupons-admin', ownerOnly, resolveShop, merchantCouponsRouter);
  app.use(
    '/me/brand-spotlight',
    ownerOnly,
    resolveShop,
    brandSpotlightMerchantRouter,
  );
  // Categories are a shared read surface — both merchants (picking a
  // category for a product) and customers (browsing the marketplace)
  // hit GET /categories + /categories/tree. Mutating routes inside the
  // router self-gate to requirePlatformAdmin.

  app.use('/custom-fields', ownerOnly, customFieldsRouter);
  app.use('/products', ownerOnly, resolveShop, productsRouter);
  app.use('/stock', ownerOnly, stockRouter);
  app.use('/stock-adjustments', ownerOnly, stockAdjustmentsRouter);
  app.use('/dashboard', ownerOnly, resolveShop, dashboardRouter);
  app.use('/vendors', ownerOnly, vendorsRouter);
  app.use('/parties', ownerOnly, partiesRouter);
  app.use('/caution-requests', ownerOnly, cautionRequestsRouter);
  app.use('/quotations', ownerOnly, quotationsRouter);
  app.use('/invoices', ownerOnly, invoicesRouter);
  app.use('/challans', ownerOnly, challansRouter);
  app.use('/upload', ownerOnly, uploadLimiter, uploadRouter);
  // resolveShop attaches req.shopId so every report query can scope to the
  // caller's own shop. Without it the reports aggregated across ALL shops
  // (a cross-tenant data + PII leak).
  app.use('/reports', ownerOnly, resolveShop, reportsRouter);
  // Merchant returns inbox + workflow — mounted BEFORE /orders so the
  // sub-path takes precedence over the /orders/:id route registered
  // by the parent router below.
  app.use('/orders/returns', ownerOnly, resolveShop, merchantReturnsRouter);
  app.use('/orders', ownerOnly, ordersRouter);
  // Merchant Route onboarding (start KYC + poll status) for the caller's shop.
  app.use('/linked-account', ownerOnly, resolveShop, linkedAccountsRouter);
  app.use('/payments', ownerOnly, paymentsRouter);

  app.use(errorHandler);

  return app;
}
