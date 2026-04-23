import 'dotenv/config';
import express, { Request, Response } from 'express';
import prisma from '../db/prisma.js';
import authRouter from '../../modules/auth/auth.routes.js';
import categoriesRouter from '../../modules/categories/categories.routes.js';
import productsRouter from '../../modules/products/products.routes.js';
import stockRouter from '../../modules/stock/stock.routes.js';
import dashboardRouter from '../../modules/dashboard/dashboard.routes.js';
import vendorsRouter from '../../modules/vendors/vendors.routes.js';
import partiesRouter from '../../modules/parties/parties.routes.js';
import invoicesRouter from '../../modules/invoices/invoices.routes.js';
import challansRouter from '../../modules/challans/challans.routes.js';
import uploadRouter from '../../modules/upload/upload.routes.js';
import { getFileStream, ensureBucket } from '../../modules/upload/upload.service.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import { errorHandler } from '../../shared/http/errorHandler.js';

const app = express();

app.use(express.json({ limit: '2mb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

// ── Public routes (no auth) ───────────────────────────────────────────────────
app.use('/auth', authRouter);

// Image proxy is public so cached images display without a token in <img> tags
app.get('/images/:filename', async (req: Request, res: Response) => {
  const result = await getFileStream(req.params.filename);
  if (!result) {
    res.status(404).json({ error: 'Image not found' });
    return;
  }
  res.setHeader('Content-Type', result.contentType);
  res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
  result.stream.pipe(res);
});

// ── Protected routes (Bearer token required) ──────────────────────────────────
app.use(requireAuth);

app.use('/categories', categoriesRouter);
app.use('/products', productsRouter);
app.use('/stock', stockRouter);
app.use('/dashboard', dashboardRouter);
app.use('/vendors', vendorsRouter);
app.use('/parties', partiesRouter);
app.use('/invoices', invoicesRouter);
app.use('/challans', challansRouter);
app.use('/upload', uploadRouter);

app.use(errorHandler);

const port = Number(process.env.PORT) || 3001;
const host = process.env.HOST || '0.0.0.0';

async function startServer(): Promise<void> {
  try {
    await prisma.$connect();
    await ensureBucket().catch((e) => console.warn('MinIO bucket init warning:', e.message));
    app.listen(port, host, () => {
      console.log(`Server listening on http://${host}:${port}`);
    });
  } catch (err) {
    console.error('Failed to start server', err);
    await prisma.$disconnect();
    process.exit(1);
  }
}

startServer();

process.on('SIGINT', async () => { await prisma.$disconnect(); process.exit(0); });
process.on('SIGTERM', async () => { await prisma.$disconnect(); process.exit(0); });
