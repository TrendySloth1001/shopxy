import { scanConsoleHub } from '../scan-console/scan-console.service.js';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';

export type SaleEvent =
  | { type: 'pos.sale'; saleId: number; version: number }
  | { type: 'pos.checkout'; saleId: number; invoiceId: number }
  | { type: 'pos.void'; saleId: number };

export interface SaleBus {
  publish(shopId: number, event: SaleEvent): void;
}

const CHANNEL = 'pos:sale';

class SaleBusImpl implements SaleBus {
  private useRedis = false;
  private subscriber?: ReturnType<typeof getRedis>;

  init(): void {
    if (this.useRedis || !redisAvailable()) return;
    try {
      const sub = getRedis().duplicate({ enableOfflineQueue: true });
      sub.on('error', (err: Error) => {
        logger.warn({ err: err.message }, 'pos: SaleBus subscriber connection error');
      });
      sub.on('message', (_channel: string, payload: string) => {
        try {
          const { shopId, event } = JSON.parse(payload) as { shopId: number; event: SaleEvent };
          scanConsoleHub.publishRaw(shopId, { ...event });
        } catch {
        }
      });
      sub.subscribe(CHANNEL).catch((err: unknown) => {
        logger.warn({ err }, 'pos: SaleBus subscribe failed; staying in-memory');
      });
      this.subscriber = sub;
      this.useRedis = true;
      logger.info({ channel: CHANNEL }, 'pos: SaleBus using Redis pub/sub (multi-instance)');
    } catch (err) {
      logger.warn({ err }, 'pos: Redis SaleBus init failed; staying in-memory');
    }
  }

  async close(): Promise<void> {
    if (this.subscriber) {
      await this.subscriber.quit().catch(() => undefined);
      this.subscriber = undefined;
      this.useRedis = false;
    }
  }

  publish(shopId: number, event: SaleEvent): void {
    if (this.useRedis) {
      void getRedis()
        .publish(CHANNEL, JSON.stringify({ shopId, event }))
        .catch(() => scanConsoleHub.publishRaw(shopId, { ...event }));
      return;
    }
    scanConsoleHub.publishRaw(shopId, { ...event });
  }
}

export const saleBus = new SaleBusImpl();
