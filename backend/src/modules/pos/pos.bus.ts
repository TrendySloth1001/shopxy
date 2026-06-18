import { scanConsoleHub } from '../scan-console/scan-console.service.js';
import type { SaleSnapshot } from './pos.service.js';

/// Realtime events for the live shared cart. Carried over the existing
/// scan-console WebSocket (shop rooms + ticket auth); each event names its
/// `saleId` so a till only reacts to the sale it's viewing.
export type SaleEvent =
  | { type: 'pos.sale'; saleId: number; snapshot: SaleSnapshot }
  | { type: 'pos.checkout'; saleId: number; invoiceId: number }
  | { type: 'pos.void'; saleId: number };

/// The seam that makes the realtime layer swappable for scale (POS_DESIGN.md §9):
/// today an in-memory adapter fans out via the shop's WS room; a multi-instance
/// deploy swaps in a Redis pub/sub adapter with NO change to pos.service.
export interface SaleBus {
  publish(shopId: number, event: SaleEvent): void;
}

class InMemorySaleBus implements SaleBus {
  publish(shopId: number, event: SaleEvent): void {
    scanConsoleHub.publishRaw(shopId, { ...event });
  }
}

export const saleBus: SaleBus = new InMemorySaleBus();
