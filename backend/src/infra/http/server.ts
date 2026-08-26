import 'dotenv/config';
import { createServer } from 'node:http';
import prisma from '../db/prisma.js';
import { ensureBucket } from '../../modules/upload/upload.service.js';
import { pingRedis, closeRedis } from '../redis.js';
import { startScheduler, stopScheduler } from '../scheduler.js';
import { seedCanonicalCategories } from '../../modules/categories/categories.seed.js';
import { seedHsnMaster } from '../../modules/hsn/hsn.seed.js';
import { attachScanConsoleWs, registerWsCommandHandler } from '../../modules/scan-console/scan-console.service.js';
import { saleBus } from '../../modules/pos/pos.bus.js';
import { sessionRevocationBus } from '../../shared/sessionRevocation.js';
import { handlePosCommand } from '../../modules/pos/pos.ws.js';
import { logger } from '../../shared/logging/logger.js';
import { buildApp } from './app.js';

const app = buildApp();
const httpServer = createServer(app);
registerWsCommandHandler(handlePosCommand);
attachScanConsoleWs(httpServer);
const port = Number(process.env.PORT) || 3003;
const host = process.env.HOST || '0.0.0.0';

async function startServer(): Promise<void> {
  try {
    await prisma.$connect();
    await ensureBucket().catch((e) => logger.warn({ err: e }, 'minio bucket init failed'));
    await pingRedis().catch(() => undefined);
    saleBus.init();
    await sessionRevocationBus.init();
    await seedCanonicalCategories().catch((e) =>
      logger.warn({ err: e }, 'category seed failed; continuing boot'),
    );
    await seedHsnMaster().catch((e) =>
      logger.warn({ err: e }, 'hsn master seed failed; continuing boot'),
    );
    startScheduler();
    httpServer.listen(port, host, () => {
      logger.info({ port, host }, 'server listening');
    });
  } catch (err) {
    logger.error({ err }, 'failed to start server');
    await prisma.$disconnect();
    await closeRedis();
    process.exit(1);
  }
}

startServer();

async function shutdown(): Promise<void> {
  stopScheduler();
  await saleBus.close();
  await sessionRevocationBus.close();
  await prisma.$disconnect();
  await closeRedis();
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
