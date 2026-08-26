import { describe, it, expect, beforeEach, vi } from 'vitest';
import type { PaymentGatewayPort, HeaderBag } from '../../src/modules/payment-gateway/ports/payment-provider.port.js';
import type {
  GatewayPaymentRepository,
  WebhookEventRepository,
  CreateIntentInput,
} from '../../src/modules/payment-gateway/ports/repository.port.js';
import type {
  GatewayPaymentRecord,
  GatewayPaymentStatus,
  NormalizedEvent,
} from '../../src/modules/payment-gateway/ports/types.js';

const getProvider = vi.fn();
const onPaid = vi.fn();
const settlementFor = vi.fn(() => ({ onPaid }));

vi.mock('../../src/modules/payment-gateway/providers/registry.js', () => ({
  getProvider: (name: string) => getProvider(name),
}));

vi.mock('../../src/modules/payment-gateway/settlement/settlement.js', () => ({
  settlementFor: (type: string) => settlementFor(type),
}));

const txLog = vi.hoisted(() => ({
  entries: [] as Array<{ token: unknown; undo: () => void }>,
  record(token: unknown, undo: () => void) {
    if (token != null) this.entries.push({ token, undo });
  },
  rollback(token: unknown) {
    const mine = this.entries.filter((e) => e.token === token);
    for (const e of mine.reverse()) e.undo();
    this.entries = this.entries.filter((e) => e.token !== token);
  },
  commit(token: unknown) {
    this.entries = this.entries.filter((e) => e.token !== token);
  },
  reset() {
    this.entries = [];
  },
}));

vi.mock('../../src/infra/db/prisma.js', () => ({
  default: {
    $transaction: vi.fn(async (cb: (t: unknown) => Promise<unknown>) => {
      const token = { __fakeTx: true };
      try {
        const out = await cb(token);
        txLog.commit(token);
        return out;
      } catch (err) {
        txLog.rollback(token);
        throw err;
      }
    }),
  },
}));

import { PaymentGatewayService } from '../../src/modules/payment-gateway/payment-gateway.service.js';

function makeRecord(over: Partial<GatewayPaymentRecord> = {}): GatewayPaymentRecord {
  return {
    id: 1,
    provider: 'RAZORPAY',
    status: 'CREATED',
    amount: 100,
    currency: 'INR',
    target: { type: 'WALLET', id: 7 },
    shopId: null,
    customerUserId: 7,
    providerOrderRef: null,
    providerPaymentRef: null,
    amountRefunded: 0,
    idempotencyKey: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...over,
  };
}

class FakeRepo implements GatewayPaymentRepository {
  rows: GatewayPaymentRecord[] = [];
  private seq = 0;
  createInput: CreateIntentInput | null = null;
  attached: Array<{ id: number; refs: { providerOrderRef?: string; providerPaymentRef?: string } }> = [];
  statusUpdates: Array<{ id: number; status: GatewayPaymentStatus; hadTx: boolean }> = [];

  seed(r: GatewayPaymentRecord) {
    this.rows.push(r);
    return r;
  }

  async create(input: CreateIntentInput): Promise<GatewayPaymentRecord> {
    this.createInput = input;
    const rec = makeRecord({
      id: ++this.seq + 100,
      provider: input.provider,
      status: 'CREATED',
      amount: input.amount,
      currency: input.currency,
      target: input.target,
      shopId: input.shopId,
      customerUserId: input.customerUserId,
      idempotencyKey: input.idempotencyKey,
      providerOrderRef: null,
    });
    this.rows.push(rec);
    return rec;
  }

  async findById(id: number) {
    return this.rows.find((r) => r.id === id) ?? null;
  }

  async findByIdempotencyKey(customerUserId: number | null, key: string) {
    return (
      this.rows.find(
        (r) => r.customerUserId === customerUserId && r.idempotencyKey === key,
      ) ?? null
    );
  }

  async findByProviderOrderRef(provider: string, providerOrderRef: string) {
    return (
      this.rows.find(
        (r) => r.provider === provider && r.providerOrderRef === providerOrderRef,
      ) ?? null
    );
  }

  async findByProviderPaymentRef(provider: string, providerPaymentRef: string) {
    return (
      this.rows.find(
        (r) => r.provider === provider && r.providerPaymentRef === providerPaymentRef,
      ) ?? null
    );
  }

  async findStaleOpenIntents(input: { createdBefore: Date; limit: number }) {
    return this.rows
      .filter(
        (r) =>
          (r.status === 'CREATED' || r.status === 'PENDING') &&
          r.createdAt < input.createdBefore,
      )
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
      .slice(0, input.limit);
  }

  async attachProviderRefs(
    id: number,
    refs: { providerOrderRef?: string; providerPaymentRef?: string },
  ) {
    this.attached.push({ id, refs });
    const row = this.rows.find((r) => r.id === id);
    if (row) {
      if (refs.providerOrderRef !== undefined) row.providerOrderRef = refs.providerOrderRef;
      if (refs.providerPaymentRef !== undefined) row.providerPaymentRef = refs.providerPaymentRef;
    }
  }

  async updateStatus(id: number, status: GatewayPaymentStatus, tx?: unknown) {
    this.statusUpdates.push({ id, status, hadTx: tx != null });
    const row = this.rows.find((r) => r.id === id);
    if (row) {
      const prior = row.status;
      txLog.record(tx, () => {
        row.status = prior;
      });
      row.status = status;
    }
  }

  async detachIdempotencyKey(id: number) {
    const row = this.rows.find((r) => r.id === id);
    if (row) row.idempotencyKey = null;
  }

  async findCapturedByTarget(targetType: string, targetId: number) {
    return (
      this.rows.find(
        (r) => r.target.type === targetType && r.target.id === targetId && r.status === 'CAPTURED',
      ) ?? null
    );
  }

  async reserveRefundable(id: number, requested: number, tx?: unknown) {
    const row = this.rows.find((r) => r.id === id);
    if (!row) return { granted: 0, fullyRefunded: false };
    const r2 = (v: number) => Math.round(v * 100) / 100;
    const granted = r2(Math.min(requested, r2(row.amount - row.amountRefunded)));
    if (!(granted > 0)) return { granted: 0, fullyRefunded: false };
    const prior = { amountRefunded: row.amountRefunded, status: row.status };
    txLog.record(tx, () => {
      row.amountRefunded = prior.amountRefunded;
      row.status = prior.status;
    });
    row.amountRefunded = r2(row.amountRefunded + granted);
    const fullyRefunded = row.amountRefunded >= row.amount;
    if (fullyRefunded) row.status = 'REFUNDED';
    return { granted, fullyRefunded };
  }

  async releaseRefundable(id: number, amount: number, tx?: unknown) {
    const row = this.rows.find((r) => r.id === id);
    if (row) {
      const prior = { amountRefunded: row.amountRefunded, status: row.status };
      txLog.record(tx, () => {
        row.amountRefunded = prior.amountRefunded;
        row.status = prior.status;
      });
      row.amountRefunded = Math.round((row.amountRefunded - amount) * 100) / 100;
      row.status = row.amountRefunded >= row.amount ? 'REFUNDED' : 'CAPTURED';
    }
  }
}

class FakeRefundRepo {
  rows: Array<{
    id: number;
    gatewayPaymentId: number;
    provider: string;
    status: 'PENDING' | 'PROCESSED' | 'FAILED';
    amount: number;
    currency: string;
    providerRefundRef: string | null;
    sourceType: string;
    sourceId: number;
    reason: string | null;
    idempotencyKey: string;
    createdAt: Date;
    updatedAt: Date;
  }> = [];
  private seq = 0;

  async findByIdempotencyKey(key: string) {
    return this.rows.find((r) => r.idempotencyKey === key) ?? null;
  }

  async findByProviderRef(provider: string, providerRefundRef: string) {
    return (
      this.rows.find(
        (r) => r.provider === provider && r.providerRefundRef === providerRefundRef,
      ) ?? null
    );
  }

  async findStaleForReconcile(input: { updatedBefore: Date; limit: number }) {
    return this.rows
      .filter(
        (r) =>
          (r.status === 'PENDING' || r.status === 'FAILED') &&
          r.updatedAt < input.updatedBefore,
      )
      .sort((a, b) => a.updatedAt.getTime() - b.updatedAt.getTime())
      .slice(0, input.limit);
  }

  async create(
    input: Omit<FakeRefundRepo['rows'][number], 'id' | 'createdAt' | 'updatedAt'>,
    tx?: unknown,
  ) {
    if (this.rows.some((r) => r.idempotencyKey === input.idempotencyKey)) {
      throw Object.assign(new Error('Unique constraint failed on idempotencyKey'), {
        code: 'P2002',
      });
    }
    const row = { ...input, id: ++this.seq, createdAt: new Date(), updatedAt: new Date() };
    txLog.record(tx, () => {
      this.rows = this.rows.filter((r) => r !== row);
    });
    this.rows.push(row);
    return row;
  }

  async update(
    id: number,
    data: { status?: 'PENDING' | 'PROCESSED' | 'FAILED'; providerRefundRef?: string },
    tx?: unknown,
  ) {
    const row = this.rows.find((r) => r.id === id);
    if (row) {
      const prior = { status: row.status, providerRefundRef: row.providerRefundRef };
      txLog.record(tx, () => {
        row.status = prior.status;
        row.providerRefundRef = prior.providerRefundRef;
      });
      if (data.status !== undefined) row.status = data.status;
      if (data.providerRefundRef !== undefined) row.providerRefundRef = data.providerRefundRef;
    }
  }
}

class FakeEvents implements WebhookEventRepository {
  claimed = new Set<string>();
  processed: string[] = [];
  released: string[] = [];
  claimResult: boolean | null = null;
  claimCalls: Array<{ provider: string; eventId: string }> = [];

  async claim(provider: string, eventId: string, _payload: unknown): Promise<boolean> {
    this.claimCalls.push({ provider, eventId });
    if (this.claimResult !== null) return this.claimResult;
    const key = `${provider}:${eventId}`;
    if (this.claimed.has(key)) return false;
    this.claimed.add(key);
    return true;
  }

  async markProcessed(provider: string, eventId: string) {
    this.processed.push(`${provider}:${eventId}`);
  }

  async release(provider: string, eventId: string) {
    const key = `${provider}:${eventId}`;
    this.released.push(key);
    if (!this.processed.includes(key)) this.claimed.delete(key);
  }
}

function makeProvider(over: Partial<PaymentGatewayPort> = {}): PaymentGatewayPort {
  return {
    name: 'RAZORPAY',
    createSession: vi.fn(async () => ({
      providerOrderRef: 'order_FAKE',
      clientParams: { key: 'rzp_test', order_id: 'order_FAKE', amount: 10000 },
    })),
    buildClientParams: vi.fn(() => ({ key: 'rzp_test', order_id: 'order_REUSED' })),
    verifyHandshake: () => true,
    verifyWebhookSignature: vi.fn(() => true),
    parseWebhookEvent: vi.fn(),
    fetchPaymentStatus: vi.fn(),
    fetchOrderStatus: vi.fn(async () => ({
      status: 'CREATED' as const,
      amountPaidMinor: 0,
      capturedPaymentRef: null,
    })),
    refund: vi.fn(),
    fetchRefundStatus: vi.fn(),
    ...over,
  } as PaymentGatewayPort;
}

function evt(over: Partial<NormalizedEvent> = {}): NormalizedEvent {
  return {
    type: 'PAID',
    eventId: 'ev_1',
    providerOrderRef: 'order_FAKE',
    providerPaymentRef: 'pay_1',
    amountMinor: 10000,
    currency: 'INR',
    raw: { some: 'payload' },
    ...over,
  };
}

const HEADERS: HeaderBag = { 'x-razorpay-signature': 'sig' };
const BODY = Buffer.from('{}');

describe('PaymentGatewayService', () => {
  let repo: FakeRepo;
  let events: FakeEvents;
  let refunds: FakeRefundRepo;
  let provider: PaymentGatewayPort;
  let svc: PaymentGatewayService;

  beforeEach(() => {
    vi.clearAllMocks();
    repo = new FakeRepo();
    events = new FakeEvents();
    refunds = new FakeRefundRepo();
    provider = makeProvider();
    getProvider.mockReturnValue(provider);
    settlementFor.mockReturnValue({ onPaid });
    txLog.reset();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    svc = new PaymentGatewayService(repo, events, refunds as any);
  });

  describe('initiatePayment', () => {
    it('creates an intent, attaches the order ref, and returns client params', async () => {
      const res = await svc.initiatePayment({
        provider: 'razorpay',
        target: { type: 'WALLET', id: 7 },
        amount: 100,
        shopId: null,
        customerUserId: 7,
        idempotencyKey: null,
      });

      expect(repo.createInput?.provider).toBe('RAZORPAY');
      expect(repo.createInput?.currency).toBe('INR');

      expect(provider.createSession).toHaveBeenCalledTimes(1);
      expect(repo.attached).toEqual([
        { id: res.intentId, refs: { providerOrderRef: 'order_FAKE' } },
      ]);

      expect(res.reused).toBe(false);
      expect(res.providerOrderRef).toBe('order_FAKE');
      expect(res.clientParams).toEqual({
        key: 'rzp_test',
        order_id: 'order_FAKE',
        amount: 10000,
      });
    });

    it('is idempotent: a replay with the same (customer,key) returns reused:true and does NOT mint a new order', async () => {
      repo.seed(
        makeRecord({
          id: 55,
          provider: 'RAZORPAY',
          amount: 100,
          currency: 'INR',
          customerUserId: 7,
          idempotencyKey: 'key-abc',
          providerOrderRef: 'order_EXISTING',
        }),
      );

      const res = await svc.initiatePayment({
        provider: 'razorpay',
        target: { type: 'WALLET', id: 7 },
        amount: 100,
        shopId: null,
        customerUserId: 7,
        idempotencyKey: 'key-abc',
      });

      expect(res.reused).toBe(true);
      expect(res.intentId).toBe(55);
      expect(res.providerOrderRef).toBe('order_EXISTING');
      expect(provider.createSession).not.toHaveBeenCalled();
      expect(provider.buildClientParams).toHaveBeenCalledTimes(1);
      expect(repo.createInput).toBeNull();
    });

    it('does NOT reopen checkout when the prior order was already PAID — reconciles + throws ALREADY_PAID', async () => {
      const seeded = repo.seed(
        makeRecord({
          id: 55,
          status: 'CREATED',
          amount: 100,
          currency: 'INR',
          customerUserId: 7,
          idempotencyKey: 'order:9',
          providerOrderRef: 'order_PAID',
          target: { type: 'WALLET', id: 7 },
        }),
      );
      (provider.fetchOrderStatus as ReturnType<typeof vi.fn>).mockResolvedValue({
        status: 'PAID',
        amountPaidMinor: 10000,
        capturedPaymentRef: 'pay_recon',
      });

      await expect(
        svc.initiatePayment({
          provider: 'razorpay',
          target: { type: 'WALLET', id: 7 },
          amount: 100,
          shopId: null,
          customerUserId: 7,
          idempotencyKey: 'order:9',
        }),
      ).rejects.toMatchObject({ code: 'ALREADY_PAID', status: 409 });

      expect(seeded.status).toBe('CAPTURED');
      expect(onPaid).toHaveBeenCalledTimes(1);
      expect(repo.attached).toContainEqual({ id: 55, refs: { providerPaymentRef: 'pay_recon' } });
      expect(provider.createSession).not.toHaveBeenCalled();
      expect(repo.createInput).toBeNull();
    });

    it('mints a FRESH intent + order when retrying a FAILED intent (clean order_id)', async () => {
      repo.seed(
        makeRecord({
          id: 60,
          status: 'FAILED',
          amount: 100,
          currency: 'INR',
          customerUserId: 7,
          idempotencyKey: 'order:11',
          providerOrderRef: 'order_DEAD',
          target: { type: 'WALLET', id: 7 },
        }),
      );

      const res = await svc.initiatePayment({
        provider: 'razorpay',
        target: { type: 'WALLET', id: 7 },
        amount: 100,
        shopId: null,
        customerUserId: 7,
        idempotencyKey: 'order:11',
      });

      expect(res.reused).toBe(false);
      expect(res.intentId).not.toBe(60);
      expect(provider.createSession).toHaveBeenCalledTimes(1);
      expect(repo.createInput).not.toBeNull();
      expect(provider.fetchOrderStatus).not.toHaveBeenCalled();
    });
  });

  describe('handleWebhook', () => {
    it('throws 400 on a bad signature and never parses the event', async () => {
      (provider.verifyWebhookSignature as ReturnType<typeof vi.fn>).mockReturnValue(false);

      await expect(svc.handleWebhook('razorpay', BODY, HEADERS)).rejects.toMatchObject({
        message: 'Invalid webhook signature',
        status: 400,
      });
      expect(provider.parseWebhookEvent).not.toHaveBeenCalled();
      expect(onPaid).not.toHaveBeenCalled();
    });

    it('acks-and-ignores a FOREIGN event (no matching intent): no throw, no claim, no settlement', async () => {
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ providerOrderRef: 'order_FROM_OTHER_APP' }),
      );

      await expect(svc.handleWebhook('razorpay', BODY, HEADERS)).resolves.toBeUndefined();

      expect(events.claimCalls).toHaveLength(0);
      expect(onPaid).not.toHaveBeenCalled();
      expect(repo.statusUpdates).toHaveLength(0);
    });

    it('is a no-op on a duplicate event (claim returns false): does not transition or settle', async () => {
      repo.seed(makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'PENDING' }));
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(evt());
      events.claimResult = false;

      await expect(svc.handleWebhook('razorpay', BODY, HEADERS)).resolves.toBeUndefined();

      expect(events.claimCalls).toHaveLength(1);
      expect(onPaid).not.toHaveBeenCalled();
      expect(repo.statusUpdates).toHaveLength(0);
      expect(events.processed).toHaveLength(0);
    });

    it('PAID transitions the intent to CAPTURED and settles exactly once', async () => {
      const row = repo.seed(
        makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'PENDING', amount: 100 }),
      );
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ type: 'PAID', amountMinor: 10000, providerPaymentRef: 'pay_1' }),
      );

      await svc.handleWebhook('razorpay', BODY, HEADERS);

      expect(row.status).toBe('CAPTURED');
      expect(repo.statusUpdates).toEqual([{ id: 10, status: 'CAPTURED', hadTx: true }]);

      expect(settlementFor).toHaveBeenCalledWith('WALLET');
      expect(onPaid).toHaveBeenCalledTimes(1);
      const [settledArg, txArg] = onPaid.mock.calls[0];
      expect(settledArg).toMatchObject({ id: 10, status: 'CAPTURED', providerPaymentRef: 'pay_1' });
      expect(txArg).toEqual({ __fakeTx: true });

      expect(repo.attached).toContainEqual({ id: 10, refs: { providerPaymentRef: 'pay_1' } });
      expect(events.processed).toEqual(['RAZORPAY:ev_1']);
    });

    it('PAID with an amount mismatch throws 400 and does NOT settle or mark processed', async () => {
      const row = repo.seed(
        makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'PENDING', amount: 100 }),
      );
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ type: 'PAID', amountMinor: 9999 }),
      );

      await expect(svc.handleWebhook('razorpay', BODY, HEADERS)).rejects.toMatchObject({
        message: 'Webhook amount does not match intent',
        status: 400,
      });

      expect(onPaid).not.toHaveBeenCalled();
      expect(repo.statusUpdates).toHaveLength(0);
      expect(row.status).toBe('PENDING');
      expect(events.processed).toHaveLength(0);
    });

    it('PAID on an already-CAPTURED intent is idempotent: no settlement, but event is marked processed', async () => {
      repo.seed(makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'CAPTURED', amount: 100 }));
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ type: 'PAID', amountMinor: 10000 }),
      );

      await svc.handleWebhook('razorpay', BODY, HEADERS);

      expect(onPaid).not.toHaveBeenCalled();
      expect(repo.statusUpdates).toHaveLength(0);
      expect(events.processed).toEqual(['RAZORPAY:ev_1']);
    });

    it('FAILED transitions the intent to FAILED', async () => {
      const row = repo.seed(
        makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'PENDING', amount: 100 }),
      );
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ type: 'FAILED' }),
      );

      await svc.handleWebhook('razorpay', BODY, HEADERS);

      expect(row.status).toBe('FAILED');
      expect(repo.statusUpdates).toEqual([{ id: 10, status: 'FAILED', hadTx: false }]);
      expect(onPaid).not.toHaveBeenCalled();
      expect(events.processed).toEqual(['RAZORPAY:ev_1']);
    });

    it('releases the claim when settlement fails TRANSIENTLY, so a redelivery re-runs it', async () => {
      repo.seed(makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'PENDING', amount: 100 }));
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ type: 'PAID', amountMinor: 10000 }),
      );
      onPaid.mockRejectedValueOnce(new Error('deadlock detected'));

      await expect(svc.handleWebhook('razorpay', BODY, HEADERS)).rejects.toThrow(
        'deadlock detected',
      );
      expect(events.released).toEqual(['RAZORPAY:ev_1']);
      expect(events.processed).toHaveLength(0);

      onPaid.mockResolvedValueOnce(undefined);
      await svc.handleWebhook('razorpay', BODY, HEADERS);

      expect(events.claimCalls).toHaveLength(2);
      expect(onPaid).toHaveBeenCalledTimes(2);
      expect(events.processed).toEqual(['RAZORPAY:ev_1']);
    });

    it('KEEPS the claim on a PERMANENT (4xx) failure — a redelivery would fail identically', async () => {
      repo.seed(makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'PENDING', amount: 100 }));
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ type: 'PAID', amountMinor: 9999 }),
      );

      await expect(svc.handleWebhook('razorpay', BODY, HEADERS)).rejects.toMatchObject({
        status: 400,
      });

      expect(events.released).toHaveLength(0);
      expect(events.claimed.has('RAZORPAY:ev_1')).toBe(true);
    });
  });

  describe('reconcileStaleIntents', () => {
    const NOW = new Date('2026-06-01T12:00:00Z');
    const minsAgo = (m: number) => new Date(NOW.getTime() - m * 60_000);
    const hoursAgo = (h: number) => new Date(NOW.getTime() - h * 3_600_000);

    it('heals a missed webhook: a stale OPEN intent whose order is PAID is marked CAPTURED + settled once', async () => {
      const row = repo.seed(
        makeRecord({
          id: 10,
          status: 'PENDING',
          amount: 100,
          providerOrderRef: 'order_PAID',
          createdAt: minsAgo(30),
        }),
      );
      (provider.fetchOrderStatus as ReturnType<typeof vi.fn>).mockResolvedValue({
        status: 'PAID',
        amountPaidMinor: 10000,
        capturedPaymentRef: 'pay_recon',
      });

      const res = await svc.reconcileStaleIntents({ now: NOW });

      expect(res).toMatchObject({ scanned: 1, captured: 1, abandoned: 0, stillOpen: 0, errors: 0 });
      expect(row.status).toBe('CAPTURED');
      expect(onPaid).toHaveBeenCalledTimes(1);
      expect(repo.statusUpdates).toEqual([{ id: 10, status: 'CAPTURED', hadTx: true }]);
      expect(repo.attached).toContainEqual({ id: 10, refs: { providerPaymentRef: 'pay_recon' } });
    });

    it('leaves a recently-created intent alone (younger than the recheck window — never probed)', async () => {
      repo.seed(
        makeRecord({
          id: 10,
          status: 'CREATED',
          providerOrderRef: 'order_FRESH',
          createdAt: minsAgo(5),
        }),
      );

      const res = await svc.reconcileStaleIntents({ now: NOW });

      expect(res).toMatchObject({ scanned: 0, captured: 0, abandoned: 0, errors: 0 });
      expect(provider.fetchOrderStatus).not.toHaveBeenCalled();
    });

    it('leaves a still-unpaid intent OPEN within the abandon window (re-checked, not failed)', async () => {
      const row = repo.seed(
        makeRecord({
          id: 10,
          status: 'PENDING',
          providerOrderRef: 'order_PENDING',
          createdAt: hoursAgo(2),
        }),
      );
      (provider.fetchOrderStatus as ReturnType<typeof vi.fn>).mockResolvedValue({
        status: 'ATTEMPTED',
        amountPaidMinor: 0,
        capturedPaymentRef: null,
      });

      const res = await svc.reconcileStaleIntents({ now: NOW });

      expect(res).toMatchObject({ scanned: 1, captured: 0, abandoned: 0, stillOpen: 1, errors: 0 });
      expect(row.status).toBe('PENDING');
    });

    it('abandons an unpaid intent past the abandon window → FAILED (stops re-scanning)', async () => {
      const row = repo.seed(
        makeRecord({
          id: 10,
          status: 'PENDING',
          providerOrderRef: 'order_STUCK',
          createdAt: hoursAgo(48),
        }),
      );
      (provider.fetchOrderStatus as ReturnType<typeof vi.fn>).mockResolvedValue({
        status: 'CREATED',
        amountPaidMinor: 0,
        capturedPaymentRef: null,
      });

      const res = await svc.reconcileStaleIntents({ now: NOW });

      expect(res).toMatchObject({ scanned: 1, captured: 0, abandoned: 1, stillOpen: 0, errors: 0 });
      expect(row.status).toBe('FAILED');
    });

    it('abandons an intent that never attached a provider order (past window) WITHOUT probing the provider', async () => {
      const row = repo.seed(
        makeRecord({
          id: 10,
          status: 'CREATED',
          providerOrderRef: null,
          createdAt: hoursAgo(48),
        }),
      );

      const res = await svc.reconcileStaleIntents({ now: NOW });

      expect(res).toMatchObject({ scanned: 1, abandoned: 1, errors: 0 });
      expect(row.status).toBe('FAILED');
      expect(provider.fetchOrderStatus).not.toHaveBeenCalled();
    });

    it('counts a provider error per-intent and keeps going — the bad intent stays OPEN', async () => {
      const bad = repo.seed(
        makeRecord({ id: 10, status: 'PENDING', providerOrderRef: 'order_DOWN', createdAt: minsAgo(30) }),
      );
      const good = repo.seed(
        makeRecord({ id: 11, status: 'PENDING', providerOrderRef: 'order_OK', createdAt: minsAgo(20) }),
      );
      (provider.fetchOrderStatus as ReturnType<typeof vi.fn>)
        .mockRejectedValueOnce(new Error('rzp 503'))
        .mockResolvedValueOnce({ status: 'PAID', amountPaidMinor: 10000, capturedPaymentRef: 'pay_ok' });

      const res = await svc.reconcileStaleIntents({ now: NOW });

      expect(res).toMatchObject({ scanned: 2, captured: 1, errors: 1 });
      expect(bad.status).toBe('PENDING');
      expect(good.status).toBe('CAPTURED');
    });

    it('is idempotent with the webhook: an already-CAPTURED row is never re-scanned (terminal)', async () => {
      repo.seed(
        makeRecord({
          id: 10,
          status: 'CAPTURED',
          providerOrderRef: 'order_DONE',
          createdAt: hoursAgo(48),
        }),
      );

      const res = await svc.reconcileStaleIntents({ now: NOW });

      expect(res.scanned).toBe(0);
      expect(provider.fetchOrderStatus).not.toHaveBeenCalled();
      expect(onPaid).not.toHaveBeenCalled();
    });
  });

  describe('refundToSource', () => {
    function seedCapture(over: Partial<GatewayPaymentRecord> = {}) {
      return repo.seed(
        makeRecord({
          id: 50,
          status: 'CAPTURED',
          amount: 1000,
          target: { type: 'ORDER', id: 99 },
          providerOrderRef: 'order_CAP',
          providerPaymentRef: 'pay_CAP',
          ...over,
        }),
      );
    }

    it('refunds to source against the captured payment and records the refund', async () => {
      seedCapture();
      provider.refund = vi.fn(async () => ({
        providerRefundRef: 'rfnd_1',
        amountMinor: 40000,
        status: 'PROCESSED' as const,
      }));

      const res = await svc.refundToSource({
        targetType: 'ORDER',
        targetId: 99,
        amount: 400,
        sourceType: 'RETURN',
        sourceId: 7,
        idempotencyKey: 'return-refund-7',
      });

      expect(res.status).toBe('REFUNDED');
      expect(provider.refund).toHaveBeenCalledWith(
        expect.objectContaining({ providerPaymentRef: 'pay_CAP', amountMinor: 40000, idempotencyKey: 'return-refund-7' }),
      );
      expect(refunds.rows).toHaveLength(1);
      expect(refunds.rows[0]).toMatchObject({
        amount: 400,
        status: 'PROCESSED',
        providerRefundRef: 'rfnd_1',
        sourceType: 'RETURN',
        sourceId: 7,
      });
      expect(repo.rows[0].amountRefunded).toBe(400);
      expect(repo.rows[0].status).toBe('CAPTURED');
    });

    it('flips the capture to REFUNDED once fully reversed', async () => {
      seedCapture({ amountRefunded: 600 });
      provider.refund = vi.fn(async () => ({
        providerRefundRef: 'rfnd_2',
        amountMinor: 40000,
        status: 'PROCESSED' as const,
      }));

      const res = await svc.refundToSource({
        targetType: 'ORDER',
        targetId: 99,
        amount: 400,
        sourceType: 'RETURN',
        sourceId: 8,
        idempotencyKey: 'return-refund-8',
      });

      expect(res.status).toBe('REFUNDED');
      expect(repo.rows[0].amountRefunded).toBe(1000);
      expect(repo.rows[0].status).toBe('REFUNDED');
    });

    it('clamps an overshoot to the remaining refundable amount (never over-refunds)', async () => {
      seedCapture({ amountRefunded: 900 });
      provider.refund = vi.fn(async () => ({
        providerRefundRef: 'rfnd_3',
        amountMinor: 10000,
        status: 'PROCESSED' as const,
      }));

      const res = await svc.refundToSource({
        targetType: 'ORDER',
        targetId: 99,
        amount: 400,
        sourceType: 'CANCEL',
        sourceId: 9,
        idempotencyKey: 'cancel-9',
      });

      expect(res.status).toBe('REFUNDED');
      expect(provider.refund).toHaveBeenCalledWith(
        expect.objectContaining({ amountMinor: 10000 }),
      );
      expect(refunds.rows[0].amount).toBe(100);
      expect(repo.rows[0].amountRefunded).toBe(1000);
    });

    it('returns NO_PAYMENT for a COD / never-captured order (no provider call)', async () => {
      const res = await svc.refundToSource({
        targetType: 'ORDER',
        targetId: 99,
        amount: 400,
        sourceType: 'RETURN',
        sourceId: 10,
        idempotencyKey: 'return-refund-10',
      });

      expect(res.status).toBe('NO_PAYMENT');
      expect(provider.refund).not.toHaveBeenCalled();
      expect(refunds.rows).toHaveLength(0);
    });

    it('returns NOTHING_TO_REFUND when the capture is already fully reversed', async () => {
      seedCapture({ amountRefunded: 1000 });

      const res = await svc.refundToSource({
        targetType: 'ORDER',
        targetId: 99,
        amount: 100,
        sourceType: 'RETURN',
        sourceId: 11,
        idempotencyKey: 'return-refund-11',
      });

      expect(res.status).toBe('NOTHING_TO_REFUND');
      expect(provider.refund).not.toHaveBeenCalled();
    });

    it('is idempotent: a replayed key reuses the existing refund, no second provider call', async () => {
      seedCapture();
      provider.refund = vi.fn(async () => ({
        providerRefundRef: 'rfnd_4',
        amountMinor: 40000,
        status: 'PROCESSED' as const,
      }));
      const input = {
        targetType: 'ORDER' as const,
        targetId: 99,
        amount: 400,
        sourceType: 'RETURN' as const,
        sourceId: 12,
        idempotencyKey: 'return-refund-12',
      };

      const first = await svc.refundToSource(input);
      const second = await svc.refundToSource(input);

      expect(first.status).toBe('REFUNDED');
      expect(second.status).toBe('REFUNDED');
      expect(provider.refund).toHaveBeenCalledTimes(1);
      expect(refunds.rows).toHaveLength(1);
      expect(repo.rows[0].amountRefunded).toBe(400);
    });

    it('records a FAILED refund row (no cap consumed) when the provider throws', async () => {
      seedCapture();
      provider.refund = vi.fn(async () => {
        throw new Error('razorpay: payment already fully refunded');
      });

      const res = await svc.refundToSource({
        targetType: 'ORDER',
        targetId: 99,
        amount: 400,
        sourceType: 'RETURN',
        sourceId: 13,
        idempotencyKey: 'return-refund-13',
      });

      expect(res.status).toBe('FAILED');
      expect(refunds.rows[0].status).toBe('FAILED');
      expect(repo.rows[0].amountRefunded).toBe(0);
      expect(repo.rows[0].status).toBe('CAPTURED');
    });

    it('two concurrent refunds on one capture cannot over-refund it (reservation serializes)', async () => {
      seedCapture();
      provider.refund = vi.fn(async (p: { amountMinor: number }) => ({
        providerRefundRef: `rfnd_${p.amountMinor}`,
        amountMinor: p.amountMinor,
        status: 'PROCESSED' as const,
      }));

      const [a, b] = await Promise.all([
        svc.refundToSource({
          targetType: 'ORDER',
          targetId: 99,
          amount: 600,
          sourceType: 'CANCEL',
          sourceId: 20,
          idempotencyKey: 'cancel-20',
        }),
        svc.refundToSource({
          targetType: 'ORDER',
          targetId: 99,
          amount: 600,
          sourceType: 'CANCEL',
          sourceId: 21,
          idempotencyKey: 'cancel-21',
        }),
      ]);

      expect([a.status, b.status]).toEqual(['REFUNDED', 'REFUNDED']);
      const total = refunds.rows.reduce((s, r) => s + r.amount, 0);
      expect(total).toBe(1000);
      expect(repo.rows[0].amountRefunded).toBe(1000);
      expect(repo.rows[0].status).toBe('REFUNDED');
      const askedPaise = (provider.refund as ReturnType<typeof vi.fn>).mock.calls.map(
        (c) => (c[0] as { amountMinor: number }).amountMinor,
      );
      expect(askedPaise.reduce((s, v) => s + v, 0)).toBe(100_000);
    });

    it('the second of two refunds sharing a key is a replay, not a constraint error', async () => {
      seedCapture();
      provider.refund = vi.fn(async () => ({
        providerRefundRef: 'rfnd_race',
        amountMinor: 40000,
        status: 'PROCESSED' as const,
      }));
      const input = {
        targetType: 'ORDER' as const,
        targetId: 99,
        amount: 400,
        sourceType: 'RETURN' as const,
        sourceId: 22,
        idempotencyKey: 'return-refund-22',
      };

      const [a, b] = await Promise.all([svc.refundToSource(input), svc.refundToSource(input)]);

      expect([a.status, b.status]).toEqual(['REFUNDED', 'REFUNDED']);
      expect(refunds.rows).toHaveLength(1);
      expect(repo.rows[0].amountRefunded).toBe(400);
    });

    it('refund.processed webhook flips a PENDING refund row to PROCESSED', async () => {
      seedCapture();
      await refunds.create({
        gatewayPaymentId: 50,
        provider: 'RAZORPAY',
        status: 'PENDING',
        amount: 400,
        currency: 'INR',
        providerRefundRef: 'rfnd_W',
        sourceType: 'RETURN',
        sourceId: 14,
        reason: null,
        idempotencyKey: 'return-refund-14',
      });
      provider.parseWebhookEvent = vi.fn(() =>
        evt({
          type: 'REFUNDED',
          providerOrderRef: 'order_CAP',
          providerRefundRef: 'rfnd_W',
          providerPaymentRef: 'pay_CAP',
          eventId: 'ev_rfnd',
        }),
      );

      await svc.handleWebhook('razorpay', BODY, HEADERS);

      expect(refunds.rows[0].status).toBe('PROCESSED');
    });
  });

  describe('reconcileStaleRefunds', () => {
    const NOW = new Date('2026-06-24T12:00:00Z');
    const STALE = new Date(NOW.getTime() - 30 * 60_000);
    const FRESH = new Date(NOW.getTime() - 60_000);

    function cap(over: Partial<GatewayPaymentRecord> = {}) {
      return repo.seed(
        makeRecord({
          id: 50,
          status: 'CAPTURED',
          amount: 1000,
          target: { type: 'ORDER', id: 99 },
          providerOrderRef: 'order_CAP',
          providerPaymentRef: 'pay_CAP',
          ...over,
        }),
      );
    }
    let rseq = 0;
    function refundRow(over: Partial<FakeRefundRepo['rows'][number]> = {}) {
      rseq += 1;
      const row = {
        id: rseq + 500,
        gatewayPaymentId: 50,
        provider: 'RAZORPAY',
        status: 'PENDING' as const,
        amount: 400,
        currency: 'INR',
        providerRefundRef: 'rfnd_x' as string | null,
        sourceType: 'RETURN',
        sourceId: 1,
        reason: null,
        idempotencyKey: `return-refund-${rseq}`,
        createdAt: STALE,
        updatedAt: STALE,
        ...over,
      };
      refunds.rows.push(row);
      return row;
    }

    it('heals a PENDING refund whose webhook was missed (provider → PROCESSED)', async () => {
      cap({ amountRefunded: 400 });
      const row = refundRow({ status: 'PENDING', providerRefundRef: 'rfnd_p' });
      provider.fetchRefundStatus = vi.fn(async () => ({
        providerRefundRef: 'rfnd_p',
        amountMinor: 40000,
        status: 'PROCESSED' as const,
      }));

      const res = await svc.reconcileStaleRefunds({ now: NOW });

      expect(res).toMatchObject({ scanned: 1, processed: 1 });
      expect(row.status).toBe('PROCESSED');
      expect(repo.rows[0].amountRefunded).toBe(400);
      expect(provider.refund).not.toHaveBeenCalled();
    });

    it('releases the cap + fails a PENDING refund the provider reports FAILED', async () => {
      cap({ amountRefunded: 400, status: 'REFUNDED' });
      const row = refundRow({ status: 'PENDING', providerRefundRef: 'rfnd_f' });
      provider.fetchRefundStatus = vi.fn(async () => ({
        providerRefundRef: 'rfnd_f',
        amountMinor: 40000,
        status: 'FAILED' as const,
      }));

      const res = await svc.reconcileStaleRefunds({ now: NOW });

      expect(res.errors).toBe(1);
      expect(row.status).toBe('FAILED');
      expect(repo.rows[0].amountRefunded).toBe(0);
      expect(repo.rows[0].status).toBe('CAPTURED');
    });

    it('re-drives a FAILED refund and reserves the cap on success (idempotent)', async () => {
      cap({ amountRefunded: 0 });
      const row = refundRow({ status: 'FAILED', providerRefundRef: null });
      provider.refund = vi.fn(async () => ({
        providerRefundRef: 'rfnd_new',
        amountMinor: 40000,
        status: 'PROCESSED' as const,
      }));

      const res = await svc.reconcileStaleRefunds({ now: NOW });

      expect(res.redriven).toBe(1);
      expect(row.status).toBe('PROCESSED');
      expect(row.providerRefundRef).toBe('rfnd_new');
      expect(repo.rows[0].amountRefunded).toBe(400);
      expect(provider.refund).toHaveBeenCalledWith(
        expect.objectContaining({ idempotencyKey: row.idempotencyKey }),
      );
    });

    it('leaves a still-failing re-drive as FAILED, cap untouched', async () => {
      cap({ amountRefunded: 0 });
      const row = refundRow({ status: 'FAILED', providerRefundRef: null });
      provider.refund = vi.fn(async () => ({
        providerRefundRef: null as unknown as string,
        amountMinor: 40000,
        status: 'FAILED' as const,
      }));

      const res = await svc.reconcileStaleRefunds({ now: NOW });

      expect(res.errors).toBe(1);
      expect(row.status).toBe('FAILED');
      expect(repo.rows[0].amountRefunded).toBe(0);
    });

    it('gives up on a FAILED refund past the give-up window (no provider call)', async () => {
      cap({ amountRefunded: 0 });
      refundRow({
        status: 'FAILED',
        providerRefundRef: null,
        createdAt: new Date(NOW.getTime() - 8 * 24 * 60 * 60_000),
      });

      const res = await svc.reconcileStaleRefunds({ now: NOW });

      expect(res.gaveUp).toBe(1);
      expect(provider.refund).not.toHaveBeenCalled();
    });

    it('ignores a refund updated within the recheck window', async () => {
      cap();
      refundRow({ status: 'FAILED', updatedAt: FRESH });

      const res = await svc.reconcileStaleRefunds({ now: NOW });

      expect(res.scanned).toBe(0);
    });
  });
});
