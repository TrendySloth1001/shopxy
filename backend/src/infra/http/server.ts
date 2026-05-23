import 'dotenv/config';
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
import {
  ordersRouter,
  customerOrdersRouter,
} from '../../modules/purchase-requests/purchase-requests.routes.js';
import { getFileStream, ensureBucket } from '../../modules/upload/upload.service.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import { requireRole } from '../../shared/http/requireRole.js';
import { errorHandler } from '../../shared/http/errorHandler.js';
import { requestId } from '../../shared/http/requestId.js';
import { logger } from '../../shared/logging/logger.js';

const app = express();

// Trust the immediate proxy (devtunnel / reverse proxy / load balancer) so
// `req.ip` resolves to the real client IP and `X-Forwarded-For` is honoured.
// Tighten the hop count in prod if you front the API with more than one proxy.
app.set('trust proxy', 1);

// Security headers (CSP, X-Frame-Options, etc.) — default helmet config is fine
// for a JSON API; we don't serve HTML beyond the image proxy.
app.use(helmet());

// Attach a request id + child logger to every request, surface it via the
// `x-request-id` response header for client/correlation use, and log a
// structured `request` line on `finish` with status + duration.
app.use(requestId);

// CORS. In prod, set CORS_ORIGINS to a comma-separated allowlist
// (e.g. "https://app.example.com,https://merchant.example.com").
// In dev we fall back to `true` (reflect request origin) so mobile clients
// hitting the box from arbitrary LAN IPs / emulator origins still work.
const corsOriginsEnv = (process.env.CORS_ORIGINS ?? '').split(',').filter(Boolean);
app.use(
  cors({
    origin: corsOriginsEnv.length > 0 ? corsOriginsEnv : true,
    credentials: true,
  }),
);

app.use(express.json({ limit: '2mb' }));

// Rate-limit auth endpoints: 10 requests per minute per IP. Mounted before
// the /auth router so login/refresh brute-force attempts get throttled.
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

// ── Public routes (no auth) ───────────────────────────────────────────────────
app.use('/auth', authLimiter, authRouter);

// Image proxy is public so cached images display without a token in <img> tags
const SAFE_FILENAME_RE = /^[a-zA-Z0-9_.-]+$/;
app.get('/images/:filename', async (req: Request, res: Response) => {
  const { filename } = req.params;
  // Defeat path traversal: reject anything containing slashes, "..", or other
  // path metacharacters before we hand it to the storage layer.
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
  // 1h cache (not immutable): images can be deleted/replaced via the upload
  // module, so a stale CDN/browser cache should self-heal within an hour
  // rather than persist for a year.
  res.setHeader('Cache-Control', 'public, max-age=3600');
  result.stream.pipe(res);
});

// ── Protected routes (Bearer token required) ──────────────────────────────────
app.use(requireAuth);

// Customer-surface (any authenticated role): /me/* and /notifications.
// Invitations are also any-role so a customer can list incoming and respond.
app.use('/me', meRouter);
app.use('/me/orders', customerOrdersRouter);
app.use('/notifications', notificationsRouter);
app.use('/invitations', invitationsRouter);

// Merchant-only surface. All write/read endpoints scoped to shop data
// require OWNER role to plug the cross-tenant authz hole flagged in audit C1.
const ownerOnly = requireRole('OWNER');
app.use('/categories', ownerOnly, categoriesRouter);
app.use('/custom-fields', ownerOnly, customFieldsRouter);
app.use('/products', ownerOnly, productsRouter);
app.use('/stock', ownerOnly, stockRouter);
app.use('/stock-adjustments', ownerOnly, stockAdjustmentsRouter);
app.use('/dashboard', ownerOnly, dashboardRouter);
app.use('/vendors', ownerOnly, vendorsRouter);
app.use('/parties', ownerOnly, partiesRouter);
app.use('/invoices', ownerOnly, invoicesRouter);
app.use('/challans', ownerOnly, challansRouter);
app.use('/upload', ownerOnly, uploadRouter);
app.use('/reports', ownerOnly, reportsRouter);
app.use('/orders', ownerOnly, ordersRouter);
app.use('/payments', ownerOnly, paymentsRouter);

app.use(errorHandler);

const port = Number(process.env.PORT) || 3003;
const host = process.env.HOST || '0.0.0.0';

async function startServer(): Promise<void> {
  try {
    await prisma.$connect();
    await ensureBucket().catch((e) => logger.warn({ err: e }, 'minio bucket init failed'));
    app.listen(port, host, () => {
      logger.info({ port, host }, 'server listening');
    });
  } catch (err) {
    logger.error({ err }, 'failed to start server');
    await prisma.$disconnect();
    process.exit(1);
  }
}

startServer();

process.on('SIGINT', async () => { await prisma.$disconnect(); process.exit(0); });
process.on('SIGTERM', async () => { await prisma.$disconnect(); process.exit(0); });
