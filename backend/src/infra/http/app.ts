import express, { Request, Response } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import prisma from '../db/prisma.js';
import authRouter from '../../modules/auth/auth.routes.js';
import categoriesRouter from '../../modules/categories/categories.routes.js';
import productsRouter from '../../modules/products/products.routes.js';
import stockRouter from '../../modules/stock/stock.routes.js';
import stockAdjustmentsRouter from '../../modules/stock-adjustments/stock-adjustments.routes.js';
import dashboardRouter from '../../modules/dashboard/dashboard.routes.js';
import vendorsRouter from '../../modules/vendors/vendors.routes.js';
import partiesRouter from '../../modules/parties/parties.routes.js';
import invoicesRouter from '../../modules/invoices/invoices.routes.js';
import challansRouter from '../../modules/challans/challans.routes.js';
import uploadRouter from '../../modules/upload/upload.routes.js';
import invitationsRouter from '../../modules/invitations/invitations.routes.js';
import notificationsRouter from '../../modules/notifications/notifications.routes.js';
import reportsRouter from '../../modules/reports/reports.routes.js';
import meRouter from '../../modules/me/me.routes.js';
import paymentsRouter from '../../modules/payments/payments.routes.js';
import customFieldsRouter from '../../modules/customFields/customFields.routes.js';
import shopRouter from '../../modules/shop/shop.routes.js';
import shopPublicRouter from '../../modules/shop/shop.public.routes.js';
import {
  reviewsPublicRouter,
  reviewsAuthRouter,
} from '../../modules/reviews/reviews.routes.js';
import {
  bannersPublicRouter,
  bannersAdminRouter,
  bannersMerchantRouter,
} from '../../modules/banners/banners.routes.js';
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
import analyticsRouter from '../../modules/analytics/analytics.routes.js';
import searchRouter from '../../modules/search/search.routes.js';
import promotionsRouter from '../../modules/promotions/promotions.routes.js';
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

  const corsOriginsEnv = (process.env.CORS_ORIGINS ?? '').split(',').filter(Boolean);
  app.use(
    cors({
      origin: corsOriginsEnv.length > 0 ? corsOriginsEnv : true,
      credentials: true,
    }),
  );

  app.use(express.json({ limit: '2mb' }));

  const authLimiter = rateLimit({
    windowMs: 60_000,
    max: 10,
    standardHeaders: true,
    legacyHeaders: false,
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
  app.use('/shops', shopPublicRouter);

  // Public read of marketplace reviews. Must be registered before the
  // OWNER-gated /products mount below so this specific sub-path wins
  // and customers / unauthenticated visitors can read reviews.
  app.use('/products/:id/reviews', reviewsPublicRouter);

  // Public read of marketplace banners (home feed surfaces).
  app.use('/banners', bannersPublicRouter);

  // Public read of currently-running flash sales for the home feed.
  app.use('/flash-deals', flashSalesPublicRouter);

  // Public read of currently-running brand spotlights + editorial
  // collections — both surface on the unauthenticated home feed.
  app.use('/brand-spotlights', brandSpotlightPublicRouter);
  app.use('/collections', collectionsPublicRouter);

  // Public search — anyone can hit /search; the service attributes
  // to req.user.sub if the JWT happens to be present (we don't gate).
  app.use('/search', searchRouter);

  // Public trending — anyone can hit /products/trending. Mounted
  // before the OWNER-gated /products router below so this sub-path
  // takes precedence for unauthenticated callers.
  app.use('/products', trendingPublicRouter);

  // Customer home feed aggregator — one round trip for the whole page.
  // Mounted before requireAuth so the unauthenticated app can prime
  // the home tab and only escalate to personalised endpoints after
  // login.
  app.use('/home', homePublicRouter);

  // Public marketplace reads: product detail + per-shop product list.
  // Namespaced under /marketplace/ to avoid colliding with the
  // OWNER-gated `/products/:id` PATCH/DELETE mounted after requireAuth,
  // which would otherwise be shadowed by a public GET that returns
  // 404 for unpublished items (breaking the merchant editor).
  // optionalAuth hydrates req.user when a Bearer token is present so
  // the own-shop guard can hide a logged-in merchant's own products
  // from their customer-side browse. Anonymous visitors still see
  // everything published.
  app.use('/marketplace/products', optionalAuth, marketplaceProductRouter);
  app.use('/marketplace/shops', optionalAuth, marketplaceShopRouter);
  app.use('/marketplace/categories', optionalAuth, marketplaceCategoryRouter);

  const SAFE_FILENAME_RE = /^[a-zA-Z0-9_.-]+$/;
  app.get('/images/:filename', async (req: Request, res: Response) => {
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
    result.stream.pipe(res);
  });

  app.use(requireAuth);

  // Review writes are authenticated but NOT role-gated — customers
  // (the marketplace buyers) are the primary author. Registered before
  // the ownerOnly /products mount so this path takes precedence.
  app.use('/products/:id/reviews', reviewsAuthRouter);

  app.use('/me', meRouter);
  app.use('/me/orders', customerOrdersRouter);
  app.use('/me/recently-viewed', recentlyViewedRouter);
  app.use('/me/addresses', addressesRouter);

  // Customer event ingestion — no role gate; both OWNER (browsing
  // the marketplace) and CUSTOMER can post events. resolveShop is
  // intentionally not used; events attribute to the *user*, not a shop.
  app.use('/v1/events', eventsIngestRouter);

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
  app.use('/admin/brand-spotlight', requirePlatformAdmin, brandSpotlightAdminRouter);
  app.use('/admin/collections', requirePlatformAdmin, collectionsAdminRouter);

  // Shared categories read surface (merchant + customer). Writes are
  // self-gated to PLATFORM_ADMIN inside categories.routes.ts.
  app.use('/categories', categoriesRouter);

  const ownerOnly = requireRole('OWNER');
  app.use('/me/shop', ownerOnly, shopRouter);
  // Merchant-owned flash deals — resolveShop attaches req.shopId; the
  // service scopes every read/write through Product.shopId so a wrong
  // ownerId can't reach into another shop's promotions.
  app.use('/me/flash-deals', ownerOnly, resolveShop, flashSalesMerchantRouter);
  // Merchant-owned carousel banners — every shop can publish their own
  // hero slides; service scopes by sponsorShopId = req.shopId. Slides
  // surface on the customer home feed through the existing public
  // /banners reader (no separate customer wiring needed).
  app.use('/me/banners', ownerOnly, resolveShop, bannersMerchantRouter);
  app.use('/me/analytics', ownerOnly, resolveShop, analyticsRouter);
  app.use('/me/promotions', ownerOnly, resolveShop, promotionsRouter);
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
  app.use('/invoices', ownerOnly, invoicesRouter);
  app.use('/challans', ownerOnly, challansRouter);
  app.use('/upload', ownerOnly, uploadRouter);
  app.use('/reports', ownerOnly, reportsRouter);
  app.use('/orders', ownerOnly, ordersRouter);
  app.use('/payments', ownerOnly, paymentsRouter);

  app.use(errorHandler);

  return app;
}
