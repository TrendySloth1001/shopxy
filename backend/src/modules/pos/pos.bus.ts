import { scanConsoleHub } from '../scan-console/scan-console.service.js';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';

/// Realtime notifications for the live shared cart. Carried over the existing
/// scan-console WebSocket (shop rooms + ticket auth); each event names its
/// `saleId` so a till only reacts to the sale it's viewing. Deliberately carries
/// NO cart contents (customer PII + pricing) — `pos.sale` is just a version
/// nudge and the till re-fetches the shop-gated snapshot (review M3).
export type SaleEvent =
  | { type: 'pos.sale'; saleId: number; version: number }
  | { type: 'pos.checkout'; saleId: number; invoiceId: number }
  | { type: 'pos.void'; saleId: number };

export interface SaleBus {
  publish(shopId: number, event: SaleEvent): void;
}

const CHANNEL = 'pos:sale';

/// The scaling seam (POS_DESIGN.md §9). One instance, in-memory: publish fans
/// straight to the shop's local WS sockets. Multiple instances: publish goes to
/// Redis and EVERY instance's subscriber (including this one) fans it to its own
/// local sockets — so a till connected to any node sees the change. Falls back
/// to in-memory automatically when Redis is down (dev, or a transient outage),
/// trading cross-instance reach for correctness, never the reverse.
class SaleBusImpl implements SaleBus {
  private useRedis = false;
  private subscriber?: ReturnType<typeof getRedis>;

  /// Called once at boot, after the Redis ping. If Redis is reachable, switch to
  /// pub/sub; otherwise stay in-memory (single-instance).
  init(): void {
    if (this.useRedis || !redisAvailable()) return;
    try {
      const sub = getRedis().duplicate();
      sub.on('message', (_channel: string, payload: string) => {
        try {
          const { shopId, event } = JSON.parse(payload) as { shopId: number; event: SaleEvent };
          scanConsoleHub.publishRaw(shopId, { ...event });
        } catch {
          /* ignore malformed */
        }
      });
      void sub.subscribe(CHANNEL);
      this.subscriber = sub;
      this.useRedis = true;
      logger.info({ channel: CHANNEL }, 'pos: SaleBus using Redis pub/sub (multi-instance)');
    } catch (err) {
      logger.warn({ err }, 'pos: Redis SaleBus init failed; staying in-memory');
    }
  }

  /// Close the dedicated subscriber connection on shutdown (it's a separate
  /// ioredis connection from the shared cache client — review M6).
  async close(): Promise<void> {
    if (this.subscriber) {
      await this.subscriber.quit().catch(() => undefined);
      this.subscriber = undefined;
      this.useRedis = false;
    }
  }

  publish(shopId: number, event: SaleEvent): void {
    if (this.useRedis) {
      // Publish to all instances; our own subscriber delivers to local sockets,
      // so we must NOT also publishRaw here (that would double-send locally).
      void getRedis()
        .publish(CHANNEL, JSON.stringify({ shopId, event }))
        .catch(() => scanConsoleHub.publishRaw(shopId, { ...event })); // degrade to local
      return;
    }
    scanConsoleHub.publishRaw(shopId, { ...event });
  }
}

export const saleBus = new SaleBusImpl();
