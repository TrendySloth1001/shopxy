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
