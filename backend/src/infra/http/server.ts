import express from 'express';
import prisma from '../db/prisma.js';
import usersRouter from '../../modules/users/users.routes.js';
import categoriesRouter from '../../modules/categories/categories.routes.js';
import productsRouter from '../../modules/products/products.routes.js';
import stockRouter from '../../modules/stock/stock.routes.js';
import dashboardRouter from '../../modules/dashboard/dashboard.routes.js';
import { errorHandler } from '../../shared/http/errorHandler.js';

const app = express();

app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

// Module routes
app.use('/users', usersRouter);
app.use('/categories', categoriesRouter);
app.use('/products', productsRouter);
app.use('/stock', stockRouter);
app.use('/dashboard', dashboardRouter);

app.use(errorHandler);

const port = Number(process.env.PORT) || 3001;
const host = process.env.HOST || '0.0.0.0';

async function startServer(): Promise<void> {
  try {
    await prisma.$connect();
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

process.on('SIGINT', async () => {
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await prisma.$disconnect();
  process.exit(0);
});
