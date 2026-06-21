/**
 * Pure structural checks for the settlement handler registry.
 *
 * The ORDER handler's behaviour (marks the order PAID + posts merchant receipts)
 * now touches the gateway_payments + invoices + payments tables, so it is covered
 * end-to-end against the real DB in order-receipts.test.ts. Here we only assert
 * the registry shape — that every settlement target resolves to a handler with an
 * onPaid method — which needs no database.
 */
import { describe, it, expect } from 'vitest';
import { settlementFor } from '../../src/modules/payment-gateway/settlement/settlement.js';
import type { SettlementTargetType } from '../../src/modules/payment-gateway/ports/types.js';

describe('settlement registry', () => {
  it.each<SettlementTargetType>(['WALLET', 'ORDER', 'INVOICE', 'POS'])(
    'resolves %s to a handler exposing onPaid',
    (type) => {
      const handler = settlementFor(type);
      expect(handler).toBeDefined();
      expect(typeof handler.onPaid).toBe('function');
    },
  );
});
