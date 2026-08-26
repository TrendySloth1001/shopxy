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

export function buildApp(): express.Express {
  const app = express();

  app.set('trust proxy', 1);
  app.use(helmet());
  app.use(requestId);

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
      exposedHeaders: ['X-Shop-Perms'],
    }),
  );

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

  app.use('/payment-gateway', webhookLimiter, paymentGatewayPublicRouter);

  app.use(express.json({ limit: '2mb' }));

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

  app.use('/products/:id/reviews', publicLimiter, reviewsPublicRouter);

  app.use('/banners', publicLimiter, bannersPublicRouter);

  app.use('/search', publicLimiter, searchRouter);

  app.use('/products', publicLimiter, trendingPublicRouter);

  app.use('/home', publicLimiter, homePublicRouter);

  app.use('/marketplace/products', publicLimiter, optionalAuth, marketplaceProductRouter);
  app.use('/marketplace/shops', publicLimiter, optionalAuth, marketplaceShopRouter);
  app.use('/marketplace/categories', publicLimiter, optionalAuth, marketplaceCategoryRouter);

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
    const ALLOWED_IMAGE_TYPES = new Set(['image/webp', 'image/jpeg', 'image/png', 'image/gif']);
    const isImage = ALLOWED_IMAGE_TYPES.has(result.contentType);
    res.setHeader('Content-Type', isImage ? result.contentType : 'application/octet-stream');
    if (!isImage) res.setHeader('Content-Disposition', 'attachment');
    res.setHeader('Cache-Control', 'public, max-age=3600');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    result.stream.pipe(res);
  });

  app.use(requireAuth);

  app.use(perUserLimiter);

  app.use('/products/:id/reviews', reviewsAuthRouter);

  app.use('/me', meRouter);
  app.use('/me/orders', customerOrdersRouter);
  app.use('/me/orders/:parentId/returns', customerOrderReturnsSubmitRouter);
  app.use('/me/returns', customerReturnsRouter);
  app.use('/me/wallet', customerWalletRouter);
  app.use('/me/wallet/topup', walletTopUpRouter);
  app.use('/me/coupons', customerCouponsRouter);
  app.use('/me/recently-viewed', recentlyViewedRouter);
  app.use('/me/reviews', myReviewsRouter);
  app.use('/me/addresses', addressesRouter);
  app.use('/me/cart', cartRouter);
  app.use('/me/upload', uploadLimiter, avatarUploadRouter);

  app.use('/v1/events', eventsLimiter, eventsIngestRouter);

  app.use('/products', recommendationsRouter);

  app.use('/me/home', homePersonalRouter);
  app.use('/notifications', notificationsRouter);
  app.use('/invitations', invitationsRouter);

  app.use('/admin/banners', requirePlatformAdmin, bannersAdminRouter);
  app.use('/admin/shops', requirePlatformAdmin, adminShopRouter);

  const ownerOnly = requireRole('OWNER');

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
  app.use('/me/onboarding', ownerOnly, shopOnboardingRouter);
  mountMerchant('/me/banners', bannersMerchantRouter, [
    resolveShop,
    carouselWriteLimiter,
  ]);
  mountMerchant('/me/scan-console', scanConsoleMerchantRouter, [resolveShop]);
  mountMerchant('/me/pos', posMerchantRouter, [resolveShop]);
  mountMerchant('/me/cashier', cashierMerchantRouter, [resolveShop]);
  mountMerchant('/me/coupons-admin', merchantCouponsRouter, [resolveShop]);
  mountMerchant('/custom-fields', customFieldsRouter);
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
  app.use('/upload', ownerOnly, uploadLimiter, uploadRouter);
  mountMerchant('/reports', reportsRouter, [resolveShop]);
  mountMerchant('/orders/returns', merchantReturnsRouter, [resolveShop]);
  mountMerchant('/orders', ordersRouter);
  mountMerchant('/linked-account', linkedAccountsRouter, [resolveShop]);
  mountMerchant('/payments', paymentsRouter);

  app.use(errorHandler);

  return app;
}
