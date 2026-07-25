/**
 * PURE unit tests for the payment-gateway core orchestrator.
 *
 * No DB, no network. We construct PaymentGatewayService directly with
 * hand-rolled in-memory fake repositories and a fake PaymentGatewayPort.
 *
 * The service statically imports three collaborators that we cannot exercise
 * for real in a unit test, so we vi.mock them:
 *   - providers/registry.js   → getProvider returns OUR fake provider
 *   - settlement/settlement.js → settlementFor returns a spy with onPaid
 *   - infra/db/prisma.js       → $transaction just runs the callback (no DB)
 */
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

// ── Mocks for the statically-imported collaborators ──────────────────────
const getProvider = vi.fn();
const onPaid = vi.fn();
const settlementFor = vi.fn(() => ({ onPaid }));

vi.mock('../../src/modules/payment-gateway/providers/registry.js', () => ({
  getProvider: (name: string) => getProvider(name),
}));

vi.mock('../../src/modules/payment-gateway/settlement/settlement.js', () => ({
  settlementFor: (type: string) => settlementFor(type),
}));

// Transactions must actually ROLL BACK in these tests, not just run the callback:
// two correctness properties the service documents depend on it — a settlement
// throw must undo the CAPTURED status flip, and a refund insert that loses the
// idempotency-key unique must undo the reservation it just made. A mock that
// swallowed rollback would report both as leaked state.
//
// Rollback is per-transaction, not a whole-store snapshot: two refunds racing on
// one capture have OVERLAPPING transactions, and a snapshot taken at the loser's
// BEGIN predates the winner's commit — restoring it would wipe committed work
// that Postgres would have kept. So each tx gets a token, every tx-scoped
// mutation registers a targeted undo against it, and rollback replays only that
// token's undos in reverse.
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
    // Run the callback with a per-call token as the tx handle, so we exercise the
    // real updateStatus + settlement wiring (and rollback) without a database.
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

// Import the subject AFTER the mocks are registered.
import { PaymentGatewayService } from '../../src/modules/payment-gateway/payment-gateway.service.js';

// ── Hand-rolled in-memory fakes ───────────────────────────────────────────

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
    // Fresh by default: replay/resume tests exercise the within-window
    // contract. Staleness tests pass an explicit old createdAt.
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

  // Mirrors the locked SQL implementation: cap-check and increment in one step,
  // granting only what's actually left. (The real one holds a row lock; a
  // single-threaded fake serializes anyway — what matters is that the check and
  // the increment are one indivisible step, which is what this asserts.)
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
    // Enforce the real unique (idempotency_key) so the racing-same-key path is
    // exercisable: the service must translate P2002 into a replay, not an error.
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
  // Override per-test if we need a specific claim outcome.
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
    // Only an unprocessed claim is releasable — mirrors the `processedAt: null`
    // guard in the SQL, so a settled event stays deduped forever.
    if (!this.processed.includes(key)) this.claimed.delete(key);
  }
}

// Fake provider port. Only the methods the core touches are real; the rest
// throw if ever called so a test that depends on them fails loudly.
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
    // Default: the live provider order is still unpaid, so a retry resumes it.
    // Tests that exercise reconciliation override this with a PAID status.
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
    txLog.reset(); // no undo entries leak between tests
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    svc = new PaymentGatewayService(repo, events, refunds as any);
  });

  // ── initiatePayment ─────────────────────────────────────────────────────

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

      // Provider key is upper-cased on persistence.
      expect(repo.createInput?.provider).toBe('RAZORPAY');
      expect(repo.createInput?.currency).toBe('INR');

      // Session created and the resulting order ref attached back to the intent.
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
      // No new order/session minted on replay; client params rebuilt instead.
      expect(provider.createSession).not.toHaveBeenCalled();
      expect(provider.buildClientParams).toHaveBeenCalledTimes(1);
      expect(repo.createInput).toBeNull();
    });

    it('does NOT reopen checkout when the prior order was already PAID — reconciles + throws ALREADY_PAID', async () => {
      // A prior attempt actually paid, but the webhook never arrived (the classic
      // localhost-dev case). The intent is still CREATED locally; the LIVE order
      // reports paid. Reopening it is what froze Razorpay — we must not.
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

      // Reconciled: marked CAPTURED + settled exactly once, the captured ref
      // attached. No fresh order minted, sheet never re-presented.
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

      // A failed attempt must NOT be resumed (its order_id is spent) — a brand
      // new provider order is created so the retry opens a clean sheet.
      expect(res.reused).toBe(false);
      expect(res.intentId).not.toBe(60);
      expect(provider.createSession).toHaveBeenCalledTimes(1);
      expect(repo.createInput).not.toBeNull();
      // We never probe a dead order's live status.
      expect(provider.fetchOrderStatus).not.toHaveBeenCalled();
    });
  });

  // ── handleWebhook ─────────────────────────────────────────────────────────

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
      // repo has no rows → findByProviderOrderRef returns null.

      await expect(svc.handleWebhook('razorpay', BODY, HEADERS)).resolves.toBeUndefined();

      expect(events.claimCalls).toHaveLength(0);
      expect(onPaid).not.toHaveBeenCalled();
      expect(repo.statusUpdates).toHaveLength(0);
    });

    it('is a no-op on a duplicate event (claim returns false): does not transition or settle', async () => {
      repo.seed(makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'PENDING' }));
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(evt());
      events.claimResult = false; // already claimed elsewhere

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

      // settlement resolved for the target type and invoked once, inside the tx.
      expect(settlementFor).toHaveBeenCalledWith('WALLET');
      expect(onPaid).toHaveBeenCalledTimes(1);
      const [settledArg, txArg] = onPaid.mock.calls[0];
      expect(settledArg).toMatchObject({ id: 10, status: 'CAPTURED', providerPaymentRef: 'pay_1' });
      expect(txArg).toEqual({ __fakeTx: true });

      // payment ref attached, event marked processed after success.
      expect(repo.attached).toContainEqual({ id: 10, refs: { providerPaymentRef: 'pay_1' } });
      expect(events.processed).toEqual(['RAZORPAY:ev_1']);
    });

    it('PAID with an amount mismatch throws 400 and does NOT settle or mark processed', async () => {
      const row = repo.seed(
        makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'PENDING', amount: 100 }),
      );
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ type: 'PAID', amountMinor: 9999 }), // expected 10000
      );

      await expect(svc.handleWebhook('razorpay', BODY, HEADERS)).rejects.toMatchObject({
        message: 'Webhook amount does not match intent',
        status: 400,
      });

      expect(onPaid).not.toHaveBeenCalled();
      expect(repo.statusUpdates).toHaveLength(0);
      expect(row.status).toBe('PENDING');
      expect(events.processed).toHaveLength(0); // processedAt stays null on failure
    });

    it('PAID on an already-CAPTURED intent is idempotent: no settlement, but event is marked processed', async () => {
      repo.seed(makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'CAPTURED', amount: 100 }));
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ type: 'PAID', amountMinor: 10000 }),
      );

      await svc.handleWebhook('razorpay', BODY, HEADERS);

      expect(onPaid).not.toHaveBeenCalled();
      expect(repo.statusUpdates).toHaveLength(0);
      // claim succeeded (fresh) and confirm short-circuited → still marked processed.
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

    // ── claim release on transient failure (the 500 must mean something) ──
    //
    // The claim commits before settlement runs, so a claim kept after a transient
    // failure would make the provider's redelivery a no-op and the 500 we return
    // a lie. These two tests pin the transient/permanent split.

    it('releases the claim when settlement fails TRANSIENTLY, so a redelivery re-runs it', async () => {
      repo.seed(makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'PENDING', amount: 100 }));
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ type: 'PAID', amountMinor: 10000 }),
      );
      // A DB blip inside settlement — no `status`, so transient.
      onPaid.mockRejectedValueOnce(new Error('deadlock detected'));

      await expect(svc.handleWebhook('razorpay', BODY, HEADERS)).rejects.toThrow(
        'deadlock detected',
      );
      expect(events.released).toEqual(['RAZORPAY:ev_1']);
      expect(events.processed).toHaveLength(0);

      // The redelivery the 500 asked for now actually lands and settles.
      onPaid.mockResolvedValueOnce(undefined);
      await svc.handleWebhook('razorpay', BODY, HEADERS);

      expect(events.claimCalls).toHaveLength(2);
      expect(onPaid).toHaveBeenCalledTimes(2);
      expect(events.processed).toEqual(['RAZORPAY:ev_1']);
    });

    it('KEEPS the claim on a PERMANENT (4xx) failure — a redelivery would fail identically', async () => {
      repo.seed(makeRecord({ id: 10, providerOrderRef: 'order_FAKE', status: 'PENDING', amount: 100 }));
      (provider.parseWebhookEvent as ReturnType<typeof vi.fn>).mockReturnValue(
        evt({ type: 'PAID', amountMinor: 9999 }), // amount mismatch → 400
      );

      await expect(svc.handleWebhook('razorpay', BODY, HEADERS)).rejects.toMatchObject({
        status: 400,
      });

      expect(events.released).toHaveLength(0);
      expect(events.claimed.has('RAZORPAY:ev_1')).toBe(true);
    });
  });

  // ── reconcileStaleIntents (the scheduled liveness net) ─────────────────────

  describe('reconcileStaleIntents', () => {
    // A fixed clock so age windows are deterministic. `now` is injected.
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
          createdAt: minsAgo(30), // past the 15-min recheck window
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
      // Settled through the SAME path as a webhook — exactly once, inside a tx.
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
          createdAt: minsAgo(5), // within the 15-min window
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
          createdAt: hoursAgo(2), // past recheck, within the 24h abandon window
        }),
      );
      (provider.fetchOrderStatus as ReturnType<typeof vi.fn>).mockResolvedValue({
        status: 'ATTEMPTED',
        amountPaidMinor: 0,
        capturedPaymentRef: null,
      });

      const res = await svc.reconcileStaleIntents({ now: NOW });

      expect(res).toMatchObject({ scanned: 1, captured: 0, abandoned: 0, stillOpen: 1, errors: 0 });
      expect(row.status).toBe('PENDING'); // not abandoned on age alone
    });

    it('abandons an unpaid intent past the abandon window → FAILED (stops re-scanning)', async () => {
      const row = repo.seed(
        makeRecord({
          id: 10,
          status: 'PENDING',
          providerOrderRef: 'order_STUCK',
          createdAt: hoursAgo(48), // past the 24h abandon window
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
          providerOrderRef: null, // createSession failed after the row was written
          createdAt: hoursAgo(48),
        }),
      );

      const res = await svc.reconcileStaleIntents({ now: NOW });

      expect(res).toMatchObject({ scanned: 1, abandoned: 1, errors: 0 });
      expect(row.status).toBe('FAILED');
      expect(provider.fetchOrderStatus).not.toHaveBeenCalled(); // nothing to probe
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
      expect(bad.status).toBe('PENDING'); // left open, retried next tick
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

      expect(res.scanned).toBe(0); // CAPTURED is not "open" — never fetched
      expect(provider.fetchOrderStatus).not.toHaveBeenCalled();
      expect(onPaid).not.toHaveBeenCalled();
    });
  });

  // ── refundToSource (real-money refund to the original instrument) ─────────
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
      // Provider called with paise + the deterministic idempotency key.
      expect(provider.refund).toHaveBeenCalledWith(
        expect.objectContaining({ providerPaymentRef: 'pay_CAP', amountMinor: 40000, idempotencyKey: 'return-refund-7' }),
      );
      // One persisted refund row, tied to its trigger.
      expect(refunds.rows).toHaveLength(1);
      expect(refunds.rows[0]).toMatchObject({
        amount: 400,
        status: 'PROCESSED',
        providerRefundRef: 'rfnd_1',
        sourceType: 'RETURN',
        sourceId: 7,
      });
      // Capture's cap advanced; not yet fully refunded (400 of 1000).
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

      // Ask for 400 when only 100 is left — must clamp to 100.
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
        expect.objectContaining({ amountMinor: 10000 }), // ₹100, not ₹400
      );
      expect(refunds.rows[0].amount).toBe(100);
      expect(repo.rows[0].amountRefunded).toBe(1000);
    });

    it('returns NO_PAYMENT for a COD / never-captured order (no provider call)', async () => {
      // No captured GatewayPayment seeded.
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
      expect(provider.refund).toHaveBeenCalledTimes(1); // replay short-circuits
      expect(refunds.rows).toHaveLength(1);
      expect(repo.rows[0].amountRefunded).toBe(400); // not double-counted
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
      // A failed refund must NOT consume refundable amount.
      expect(repo.rows[0].amountRefunded).toBe(0);
      expect(repo.rows[0].status).toBe('CAPTURED');
    });

    // ── concurrent refunds on ONE capture must not sum past it ────────────
    //
    // The real-world shape: two children of the same order cancelled at once.
    // Different idempotency keys (so no replay short-circuit), same targetId, so
    // both resolve the SAME capture. Reserving before the provider call is what
    // makes the second one see the first's consumption.

    it('two concurrent refunds on one capture cannot over-refund it (reservation serializes)', async () => {
      seedCapture(); // ₹1000 captured, nothing refunded yet
      provider.refund = vi.fn(async (p: { amountMinor: number }) => ({
        providerRefundRef: `rfnd_${p.amountMinor}`,
        amountMinor: p.amountMinor,
        status: 'PROCESSED' as const,
      }));

      // Each asks for ₹600 — individually under the ₹1000 cap, together over it.
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
      // The cap held: ₹600 + ₹400, never ₹1200.
      const total = refunds.rows.reduce((s, r) => s + r.amount, 0);
      expect(total).toBe(1000);
      expect(repo.rows[0].amountRefunded).toBe(1000);
      expect(repo.rows[0].status).toBe('REFUNDED');
      // And the provider was only ever asked for what was reserved.
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

      // Both pass the replay lookup (neither row exists yet), so the loser hits
      // the unique on insert — which must resolve to the winner's refund.
      const [a, b] = await Promise.all([svc.refundToSource(input), svc.refundToSource(input)]);

      expect([a.status, b.status]).toEqual(['REFUNDED', 'REFUNDED']);
      expect(refunds.rows).toHaveLength(1);
      expect(repo.rows[0].amountRefunded).toBe(400); // charged once
    });

    it('refund.processed webhook flips a PENDING refund row to PROCESSED', async () => {
      seedCapture();
      // A refund that came back PENDING from the provider (normal, non-instant).
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
      // The refund webhook resolves the captured intent by its order ref, then
      // our refund row by the refund entity id.
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

  // ── reconcileStaleRefunds (the liveness net for un-settled refunds) ────────
  describe('reconcileStaleRefunds', () => {
    const NOW = new Date('2026-06-24T12:00:00Z');
    const STALE = new Date(NOW.getTime() - 30 * 60_000); // 30 min ago → past recheck
    const FRESH = new Date(NOW.getTime() - 60_000); // 1 min ago → within recheck

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
      cap({ amountRefunded: 400 }); // PENDING reserved the cap at create
      const row = refundRow({ status: 'PENDING', providerRefundRef: 'rfnd_p' });
      provider.fetchRefundStatus = vi.fn(async () => ({
        providerRefundRef: 'rfnd_p',
        amountMinor: 40000,
        status: 'PROCESSED' as const,
      }));

      const res = await svc.reconcileStaleRefunds({ now: NOW });

      expect(res).toMatchObject({ scanned: 1, processed: 1 });
      expect(row.status).toBe('PROCESSED');
      expect(repo.rows[0].amountRefunded).toBe(400); // unchanged (already reserved)
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
      expect(repo.rows[0].amountRefunded).toBe(0); // reservation released
      expect(repo.rows[0].status).toBe('CAPTURED'); // no longer fully refunded
    });

    it('re-drives a FAILED refund and reserves the cap on success (idempotent)', async () => {
      cap({ amountRefunded: 0 }); // FAILED never reserved
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
      expect(repo.rows[0].amountRefunded).toBe(400); // reserved now
      // Re-issue reuses the SAME idempotency key → Razorpay dedupes (no double pay).
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
        createdAt: new Date(NOW.getTime() - 8 * 24 * 60 * 60_000), // 8 days old
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
