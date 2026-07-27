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
// Wrap Express in a raw http.Server so we can own the WebSocket upgrade
// handshake (scan-console live feed). `app.listen()` hides the server, so we
// create it explicitly and listen on it instead.
const httpServer = createServer(app);
// POS commands ride the scan-console socket; register the handler before the
// server accepts upgrades.
registerWsCommandHandler(handlePosCommand);
attachScanConsoleWs(httpServer);
const port = Number(process.env.PORT) || 3003;
const host = process.env.HOST || '0.0.0.0';

async function startServer(): Promise<void> {
  try {
    await prisma.$connect();
    await ensureBucket().catch((e) => logger.warn({ err: e }, 'minio bucket init failed'));
    // Best-effort: cache helpers degrade gracefully if Redis is down.
    await pingRedis().catch(() => undefined);
    // POS live-cart bus: use Redis pub/sub for cross-instance fan-out when Redis
    // is up, else stay in-memory (single instance). Must run after the ping.
    saleBus.init();
    // Per-session logout revocation: seed from Redis + subscribe for peer
    // revocations (multi-instance). Local-only if Redis is down. After the ping.
    await sessionRevocationBus.init();
    // Canonical category taxonomy — idempotent upsert from the
    // checked-in manifest. Best-effort: the server still boots if the
    // seed fails so we don't lock ourselves out of fixing a bad row.
    await seedCanonicalCategories().catch((e) =>
      logger.warn({ err: e }, 'category seed failed; continuing boot'),
    );
    // HSN/SAC → GST rate master, same deal: idempotent sync from the
    // checked-in manifest. Best-effort for the same reason — a bad row
    // shouldn't cost us the ability to boot and fix it.
    await seedHsnMaster().catch((e) =>
      logger.warn({ err: e }, 'hsn master seed failed; continuing boot'),
    );
    // Recurring jobs (flash-sale flush, expiry sweep, …). No-op in
    // NODE_ENV=test so vitest runs don't fire timers.
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
