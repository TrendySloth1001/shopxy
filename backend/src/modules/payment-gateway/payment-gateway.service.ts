import type {
  GatewayPaymentRepository,
  GatewayRefundRepository,
  WebhookEventRepository,
} from './ports/repository.port.js';
import type { HeaderBag } from './ports/payment-provider.port.js';
import { isQrCapable } from './ports/payment-provider.port.js';
import type {
  GatewayPaymentRecord,
  GatewayPaymentStatus,
  GatewayRefundRecord,
  NormalizedEvent,
  NormalizedOrderStatus,
  SettlementTarget,
  SettlementTargetType,
} from './ports/types.js';
import { getProvider } from './providers/registry.js';
import { settlementFor } from './settlement/settlement.js';
import {
  isSettlementEvent,
  ownsSettlementEvent,
  handleSettlementEvent,
} from './settlement/webhook-handlers.js';
import { toMinorUnits } from './helpers.js';
import { tracker } from './tracker.js';
import prisma from '../../infra/db/prisma.js';
import { round2 } from '../../shared/numbering/decimal.js';

function alreadyPaidError(): Error & { status: number; code: string } {
  return Object.assign(new Error('This order is already paid'), {
    status: 409,
    code: 'ALREADY_PAID',
  });
}

export interface InitiateInput {
  provider: string;
  target: SettlementTarget;
  amount: number;
  currency?: string;
  shopId: number | null;
  customerUserId: number | null;
  idempotencyKey: string | null;
}

export interface InitiateResult {
  intentId: number;
  provider: string;
  providerOrderRef: string;
  amount: number;
  currency: string;
  clientParams: Record<string, unknown>;
  reused: boolean;
}

export interface ReconcileSummary {
  scanned: number;
  captured: number;
  abandoned: number;
  stillOpen: number;
  errors: number;
}

export interface RefundToSourceInput {
  targetType: SettlementTargetType;
  targetId: number;
  amount: number;
  sourceType: 'RETURN' | 'CANCEL';
  sourceId: number;
  idempotencyKey: string;
  reason?: string;
  notes?: Record<string, string>;
}

export type RefundToSourceResult =
  | { status: 'REFUNDED'; refund: GatewayRefundRecord }
  | { status: 'FAILED'; refund: GatewayRefundRecord }
  | { status: 'NO_PAYMENT' }
  | { status: 'NOTHING_TO_REFUND' };

export interface RefundReconcileSummary {
  scanned: number;
  processed: number;
  redriven: number;
  stillPending: number;
  gaveUp: number;
  errors: number;
}

export class PaymentGatewayService {
  constructor(
    private readonly repo: GatewayPaymentRepository,
    private readonly events: WebhookEventRepository,
    private readonly refunds: GatewayRefundRepository,
  ) {}

  async refundToSource(input: RefundToSourceInput): Promise<RefundToSourceResult> {
    const prior = await this.refunds.findByIdempotencyKey(input.idempotencyKey);
    if (prior) {
      tracker.track({
        step: 'REFUND_REPLAYED',
        provider: prior.provider,
        meta: { idempotencyKey: input.idempotencyKey, status: prior.status },
      });
      return prior.status === 'FAILED'
        ? { status: 'FAILED', refund: prior }
        : { status: 'REFUNDED', refund: prior };
    }

    const capture = await this.repo.findCapturedByTarget(input.targetType, input.targetId);
    if (!capture || !capture.providerPaymentRef) {
      tracker.track({
        step: 'REFUND_SKIPPED',
        meta: {
          targetType: input.targetType,
          targetId: input.targetId,
          reason: 'no captured online payment (COD / wallet / never captured)',
        },
      });
      return { status: 'NO_PAYMENT' };
    }

    let reserved: { row: GatewayRefundRecord; amount: number; fullyRefunded: boolean } | null;
    try {
      reserved = await prisma.$transaction(async (tx) => {
        const { granted, fullyRefunded } = await this.repo.reserveRefundable(
          capture.id,
          input.amount,
          tx,
        );
        if (!(granted > 0)) return null;
        const row = await this.refunds.create(
          {
            gatewayPaymentId: capture.id,
            provider: capture.provider,
            amount: granted,
            currency: capture.currency,
            status: 'PENDING',
            providerRefundRef: null,
            sourceType: input.sourceType,
            sourceId: input.sourceId,
            reason: input.reason ?? null,
            idempotencyKey: input.idempotencyKey,
          },
          tx,
        );
        return { row, amount: granted, fullyRefunded };
      });
    } catch (err) {
      if ((err as { code?: string }).code === 'P2002') {
        const winner = await this.refunds.findByIdempotencyKey(input.idempotencyKey);
        if (winner) {
          tracker.track({
            step: 'REFUND_REPLAYED',
            provider: winner.provider,
            intentId: capture.id,
            meta: { idempotencyKey: input.idempotencyKey, status: winner.status, raced: true },
          });
          return winner.status === 'FAILED'
            ? { status: 'FAILED', refund: winner }
            : { status: 'REFUNDED', refund: winner };
        }
      }
      throw err;
    }

    if (!reserved) {
      tracker.track({
        step: 'REFUND_SKIPPED',
        provider: capture.provider,
        intentId: capture.id,
        meta: { reason: 'nothing left to refund', requested: input.amount },
      });
      return { status: 'NOTHING_TO_REFUND' };
    }
    const { row: refund, amount, fullyRefunded } = reserved;

    const provider = getProvider(capture.provider);
    let providerRefundRef: string | null = null;
    let providerStatus: GatewayRefundRecord['status'] = 'PENDING';
    let failed = false;
    try {
      const res = await provider.refund({
        providerPaymentRef: capture.providerPaymentRef,
        amountMinor: toMinorUnits(amount),
        idempotencyKey: input.idempotencyKey,
        notes: {
          app: 'shopxy',
          sourceType: input.sourceType,
          sourceId: String(input.sourceId),
          ...(input.notes ?? {}),
        },
      });
      providerRefundRef = res.providerRefundRef;
      providerStatus = res.status;
      failed = res.status === 'FAILED';
    } catch (err) {
      failed = true;
      tracker.track({
        step: 'REFUND_FAILED',
        provider: capture.provider,
        intentId: capture.id,
        meta: { error: err instanceof Error ? err.message : 'unknown', amount },
      });
    }

    if (failed) {
      await this.releaseAndFail(refund, capture);
      const failedRow: GatewayRefundRecord = { ...refund, status: 'FAILED' };
      tracker.track({
        step: 'REFUND_FAILED',
        provider: capture.provider,
        intentId: capture.id,
        meta: { refundId: refund.id, amount, phase: 'reservation released' },
      });
      return { status: 'FAILED', refund: failedRow };
    }

    await this.refunds.update(refund.id, {
      status: providerStatus,
      ...(providerRefundRef ? { providerRefundRef } : {}),
    });
    const settledRow: GatewayRefundRecord = {
      ...refund,
      status: providerStatus,
      providerRefundRef,
    };
    tracker.track({
      step: 'REFUND_ISSUED',
      provider: capture.provider,
      intentId: capture.id,
      meta: {
        refundId: refund.id,
        providerRefundRef,
        amount,
        status: providerStatus,
        fullyRefunded,
      },
    });
    return { status: 'REFUNDED', refund: settledRow };
  }

  async reconcileStaleRefunds(opts?: {
    now?: Date;
    recheckAfterMs?: number;
    giveUpAfterMs?: number;
    batchSize?: number;
  }): Promise<RefundReconcileSummary> {
    const now = opts?.now ?? new Date();
    const recheckAfterMs = opts?.recheckAfterMs ?? 10 * 60_000;
    const giveUpAfterMs = opts?.giveUpAfterMs ?? 7 * 24 * 60 * 60_000;
    const batchSize = opts?.batchSize ?? 50;

    const recheckBefore = new Date(now.getTime() - recheckAfterMs);
    const giveUpBefore = new Date(now.getTime() - giveUpAfterMs);

    const stale = await this.refunds.findStaleForReconcile({
      updatedBefore: recheckBefore,
      limit: batchSize,
    });
    const summary: RefundReconcileSummary = {
      scanned: stale.length,
      processed: 0,
      redriven: 0,
      stillPending: 0,
      gaveUp: 0,
      errors: 0,
    };

    for (const row of stale) {
      try {
        const capture = await this.repo.findById(row.gatewayPaymentId);
        if (!capture || !capture.providerPaymentRef) {
          summary.errors++;
          continue;
        }
        const provider = getProvider(row.provider);

        if (row.status === 'PENDING' && row.providerRefundRef) {
          const live = await provider.fetchRefundStatus(row.providerRefundRef);
          if (live.status === 'PROCESSED') {
            await this.refunds.update(row.id, { status: 'PROCESSED' });
            summary.processed++;
          } else if (live.status === 'FAILED') {
            await this.releaseAndFail(row, capture);
            summary.errors++;
          } else {
            summary.stillPending++;
          }
          continue;
        }

        if (row.createdAt < giveUpBefore) {
          summary.gaveUp++;
          continue;
        }
        const ok = await this.redriveRefund(row, capture);
        if (ok) summary.redriven++;
        else summary.errors++;
      } catch (err) {
        summary.errors++;
        tracker.track({
          step: 'REFUND_FAILED',
          provider: row.provider,
          meta: {
            phase: 'reconcile-sweep',
            refundId: row.id,
            error: err instanceof Error ? err.message : 'unknown',
          },
        });
      }
    }

    tracker.track({ step: 'REFUND_RECONCILE_SWEEP', meta: { ...summary } });
    return summary;
  }

  private async redriveRefund(
    row: GatewayRefundRecord,
    capture: GatewayPaymentRecord,
  ): Promise<boolean> {
    const alreadyReserved = row.status !== 'FAILED';
    const provider = getProvider(row.provider);
    const res = await provider.refund({
      providerPaymentRef: capture.providerPaymentRef!,
      amountMinor: toMinorUnits(row.amount),
      idempotencyKey: row.idempotencyKey,
      notes: {
        app: 'shopxy',
        sourceType: row.sourceType,
        sourceId: String(row.sourceId),
        targetType: capture.target.type,
        targetId: String(capture.target.id),
        redrive: 'true',
      },
    });

    if (res.status === 'FAILED') {
      if (alreadyReserved) {
        await this.releaseAndFail(row, capture);
      } else {
        await this.refunds.update(row.id, {
          status: 'FAILED',
          ...(res.providerRefundRef ? { providerRefundRef: res.providerRefundRef } : {}),
        });
      }
      return false;
    }

    let granted = row.amount;
    await prisma.$transaction(async (tx) => {
      await this.refunds.update(
        row.id,
        {
          status: res.status,
          ...(res.providerRefundRef ? { providerRefundRef: res.providerRefundRef } : {}),
        },
        tx,
      );
      if (!alreadyReserved) {
        const r = await this.repo.reserveRefundable(capture.id, row.amount, tx);
        granted = r.granted;
      }
    });
    if (granted < row.amount) {
      tracker.track({
        step: 'REFUND_FAILED',
        provider: row.provider,
        intentId: capture.id,
        meta: {
          refundId: row.id,
          phase: 'redrive-reservation-shortfall',
          refunded: row.amount,
          reserved: granted,
          severity: 'CRITICAL',
        },
      });
    }
    tracker.track({
      step: 'REFUND_REDRIVEN',
      provider: row.provider,
      intentId: capture.id,
      meta: { refundId: row.id, status: res.status, providerRefundRef: res.providerRefundRef },
    });
    return true;
  }

  private async releaseAndFail(
    row: GatewayRefundRecord,
    capture: GatewayPaymentRecord,
  ): Promise<void> {
    await prisma.$transaction(async (tx) => {
      await this.refunds.update(row.id, { status: 'FAILED' }, tx);
      await this.repo.releaseRefundable(capture.id, row.amount, tx);
    });
    tracker.track({
      step: 'REFUND_FAILED',
      provider: row.provider,
      intentId: capture.id,
      meta: { refundId: row.id, phase: 'pending-turned-failed; reservation released' },
    });
  }

  async initiatePayment(input: InitiateInput): Promise<InitiateResult> {
    const provider = getProvider(input.provider);
    const currency = input.currency ?? 'INR';

    if (input.idempotencyKey) {
      const existing = await this.repo.findByIdempotencyKey(
        input.customerUserId,
        input.idempotencyKey,
      );
      const IDEMPOTENCY_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
      const isStale = (r: { createdAt: Date }) =>
        Date.now() - r.createdAt.getTime() > IDEMPOTENCY_WINDOW_MS;
      const retireExisting = async (r: { id: number; status: string }) => {
        if (r.status === 'CREATED' || r.status === 'PENDING') {
          await this.repo.updateStatus(r.id, 'FAILED');
        }
        await this.repo.detachIdempotencyKey(r.id);
      };
      if (existing) {
        if (existing.status === 'CAPTURED' || existing.status === 'REFUNDED') {
          throw alreadyPaidError();
        }

        if (
          (existing.status === 'CREATED' || existing.status === 'PENDING') &&
          existing.providerOrderRef
        ) {
          if (
            existing.amount !== input.amount ||
            existing.currency !== currency ||
            existing.provider !== input.provider.toUpperCase()
          ) {
            throw Object.assign(
              new Error('Idempotency key mismatch: same key with different payment params'),
              { status: 400 },
            );
          }

          let live: NormalizedOrderStatus | null = null;
          try {
            live = await provider.fetchOrderStatus(existing.providerOrderRef);
          } catch (err) {
            tracker.track({
              step: 'ORDER_STATUS_UNAVAILABLE',
              provider: existing.provider,
              intentId: existing.id,
              meta: { error: err instanceof Error ? err.message : 'unknown' },
            });
          }

          if (live?.status === 'PAID') {
            await this.reconcilePaidOrder(existing, live);
            throw alreadyPaidError();
          }

          if (!isStale(existing)) {
            tracker.track({
              step: 'INTENT_REUSED',
              provider: existing.provider,
              intentId: existing.id,
              providerOrderRef: existing.providerOrderRef,
            });
            return {
              intentId: existing.id,
              provider: existing.provider,
              providerOrderRef: existing.providerOrderRef,
              amount: existing.amount,
              currency: existing.currency,
              clientParams: provider.buildClientParams({
                providerOrderRef: existing.providerOrderRef,
                amountMinor: toMinorUnits(existing.amount),
                currency: existing.currency,
              }),
              reused: true,
            };
          }
          await retireExisting(existing);
          tracker.track({
            step: 'INTENT_RETRIED',
            provider: existing.provider,
            intentId: existing.id,
            meta: { priorStatus: existing.status, reason: 'IDEMPOTENCY_WINDOW_EXPIRED' },
          });
        } else {
          await retireExisting(existing);
          tracker.track({
            step: 'INTENT_RETRIED',
            provider: existing.provider,
            intentId: existing.id,
            meta: { priorStatus: existing.status },
          });
        }
      }
    }

    const intent = await this.repo.create({
      provider: input.provider.toUpperCase(),
      amount: input.amount,
      currency,
      target: input.target,
      shopId: input.shopId,
      customerUserId: input.customerUserId,
      idempotencyKey: input.idempotencyKey,
    });
    tracker.track({
      step: 'INTENT_CREATED',
      provider: intent.provider,
      intentId: intent.id,
      targetType: intent.target.type,
    });

    const session = await provider.createSession({
      amountMinor: toMinorUnits(intent.amount),
      currency,
      intentRef: String(intent.id),
      notes: {
        app: 'shopxy',
        intentId: String(intent.id),
        targetType: intent.target.type,
        targetId: String(intent.target.id),
      },
    });
    await this.repo.attachProviderRefs(intent.id, {
      providerOrderRef: session.providerOrderRef,
    });
    tracker.track({
      step: 'SESSION_CREATED',
      provider: intent.provider,
      intentId: intent.id,
      providerOrderRef: session.providerOrderRef,
    });

    return {
      intentId: intent.id,
      provider: intent.provider,
      providerOrderRef: session.providerOrderRef,
      amount: intent.amount,
      currency,
      clientParams: session.clientParams,
      reused: false,
    };
  }

  async initiatePosQr(input: {
    provider: string;
    shopId: number;
    saleId: number;
    amount: number;
    currency?: string;
    idempotencyKey: string;
  }): Promise<{ intentId: number; qrId: string; imageUrl: string; amount: number; currency: string }> {
    const provider = getProvider(input.provider);
    if (!isQrCapable(provider)) {
      throw Object.assign(new Error('Provider does not support UPI-QR'), { status: 400 });
    }
    const currency = input.currency ?? 'INR';

    const intent = await this.repo.create({
      provider: input.provider.toUpperCase(),
      amount: input.amount,
      currency,
      target: { type: 'POS', id: input.saleId },
      shopId: input.shopId,
      customerUserId: null,
      idempotencyKey: input.idempotencyKey,
    });
    tracker.track({
      step: 'INTENT_CREATED',
      provider: intent.provider,
      intentId: intent.id,
      targetType: 'POS',
    });

    const qr = await provider.createPosQr({
      amountMinor: toMinorUnits(intent.amount),
      intentRef: String(intent.id),
      notes: {
        app: 'shopxy',
        intentId: String(intent.id),
        targetType: 'POS',
        targetId: String(input.saleId),
      },
    });
    await this.repo.attachProviderRefs(intent.id, { providerOrderRef: qr.qrId });
    tracker.track({
      step: 'SESSION_CREATED',
      provider: intent.provider,
      intentId: intent.id,
      providerOrderRef: qr.qrId,
    });

    return { intentId: intent.id, qrId: qr.qrId, imageUrl: qr.imageUrl, amount: intent.amount, currency };
  }

  async getIntent(id: number): Promise<GatewayPaymentRecord | null> {
    return this.repo.findById(id);
  }

  async abandonIntent(id: number): Promise<void> {
    const intent = await this.repo.findById(id);
    if (!intent) return;
    if (intent.status === 'CAPTURED' || intent.status === 'REFUNDED') return;
    await this.abandon(intent);
  }

  async reconcileStaleIntents(opts?: {
    now?: Date;
    recheckAfterMs?: number;
    abandonAfterMs?: number;
    batchSize?: number;
  }): Promise<ReconcileSummary> {
    const now = opts?.now ?? new Date();
    const recheckAfterMs = opts?.recheckAfterMs ?? 15 * 60_000;
    const abandonAfterMs = opts?.abandonAfterMs ?? 24 * 60 * 60_000;
    const batchSize = opts?.batchSize ?? 50;

    const recheckBefore = new Date(now.getTime() - recheckAfterMs);
    const abandonBefore = new Date(now.getTime() - abandonAfterMs);

    const stale = await this.repo.findStaleOpenIntents({
      createdBefore: recheckBefore,
      limit: batchSize,
    });

    const summary: ReconcileSummary = {
      scanned: stale.length,
      captured: 0,
      abandoned: 0,
      stillOpen: 0,
      errors: 0,
    };

    for (const intent of stale) {
      try {
        if (!intent.providerOrderRef) {
          if (intent.createdAt < abandonBefore) {
            await this.fail(intent);
            summary.abandoned++;
            tracker.track({
              step: 'RECONCILE_ABANDONED',
              provider: intent.provider,
              intentId: intent.id,
              meta: { reason: 'no provider order ref' },
            });
          } else {
            summary.stillOpen++;
          }
          continue;
        }

        const provider = getProvider(intent.provider);
        const live = await provider.fetchOrderStatus(intent.providerOrderRef);

        if (live.status === 'PAID') {
          await this.reconcilePaidOrder(intent, live);
          summary.captured++;
        } else if (intent.target.type === 'POS') {
          await this.abandon(intent);
          summary.abandoned++;
          tracker.track({
            step: 'RECONCILE_ABANDONED',
            provider: intent.provider,
            intentId: intent.id,
            meta: { liveStatus: live.status, target: 'POS' },
          });
        } else if (intent.createdAt < abandonBefore) {
          await this.fail(intent);
          summary.abandoned++;
          tracker.track({
            step: 'RECONCILE_ABANDONED',
            provider: intent.provider,
            intentId: intent.id,
            meta: { liveStatus: live.status },
          });
        } else {
          summary.stillOpen++;
        }
      } catch (err) {
        summary.errors++;
        tracker.track({
          step: 'ORDER_STATUS_UNAVAILABLE',
          provider: intent.provider,
          intentId: intent.id,
          meta: {
            phase: 'reconcile-sweep',
            error: err instanceof Error ? err.message : 'unknown',
          },
        });
      }
    }

    tracker.track({ step: 'RECONCILE_SWEEP', meta: { ...summary } });
    return summary;
  }

  async syncIntentStatus(input: {
    customerUserId: number | null;
    idempotencyKey: string;
  }): Promise<{ found: boolean; status: GatewayPaymentStatus | null; settled: boolean }> {
    const existing = await this.repo.findByIdempotencyKey(
      input.customerUserId,
      input.idempotencyKey,
    );
    if (!existing) return { found: false, status: null, settled: false };

    if (existing.status === 'CAPTURED' || existing.status === 'REFUNDED') {
      return { found: true, status: existing.status, settled: false };
    }
    if (!existing.providerOrderRef) {
      return { found: true, status: existing.status, settled: false };
    }

    const provider = getProvider(existing.provider);
    let live: NormalizedOrderStatus | null = null;
    try {
      live = await provider.fetchOrderStatus(existing.providerOrderRef);
    } catch (err) {
      tracker.track({
        step: 'ORDER_STATUS_UNAVAILABLE',
        provider: existing.provider,
        intentId: existing.id,
        meta: { error: err instanceof Error ? err.message : 'unknown' },
      });
      return { found: true, status: existing.status, settled: false };
    }

    if (live.status === 'PAID') {
      await this.reconcilePaidOrder(existing, live);
      return { found: true, status: 'CAPTURED', settled: true };
    }
    return { found: true, status: existing.status, settled: false };
  }

  async handleWebhook(
    providerName: string,
    rawBody: Buffer,
    headers: HeaderBag,
  ): Promise<void> {
    const provider = getProvider(providerName);

    if (!provider.verifyWebhookSignature(rawBody, headers)) {
      tracker.track({ step: 'SIGNATURE_FAILED', provider: provider.name });
      throw Object.assign(new Error('Invalid webhook signature'), { status: 400 });
    }

    const event = provider.parseWebhookEvent(rawBody, headers);
    tracker.track({
      step: 'WEBHOOK_RECEIVED',
      provider: provider.name,
      providerOrderRef: event.providerOrderRef,
      providerPaymentRef: event.providerPaymentRef,
      meta: { type: event.type, eventId: event.eventId },
    });

    if (isSettlementEvent(event.type)) {
      await this.handleSettlementWebhook(provider.name, event);
      return;
    }

    const intent = event.providerOrderRef
      ? await this.repo.findByProviderOrderRef(provider.name, event.providerOrderRef)
      : event.providerPaymentRef
        ? await this.repo.findByProviderPaymentRef(provider.name, event.providerPaymentRef)
        : null;
    if (!intent) {
      tracker.track({
        step: 'WEBHOOK_IGNORED',
        provider: provider.name,
        providerOrderRef: event.providerOrderRef,
        meta: { type: event.type, reason: 'no matching intent (foreign-account event or pre-commit race)' },
      });
      return;
    }

    const fresh = await this.events.claim(provider.name, event.eventId, event.raw);
    if (!fresh) {
      tracker.track({ step: 'WEBHOOK_DEDUPED', provider: provider.name, intentId: intent.id });
      return;
    }

    try {
      if (event.type === 'PAID') {
        await this.confirm(intent, event);
      } else if (event.type === 'FAILED') {
        await this.fail(intent);
      } else if (event.type === 'REFUNDED') {
        await this.onRefundEvent(provider.name, event);
      }
    } catch (err) {
      await this.releaseClaimForRetry(provider.name, event, err);
      throw err;
    }

    await this.events.markProcessed(provider.name, event.eventId);
  }

  private async releaseClaimForRetry(
    providerName: string,
    event: NormalizedEvent,
    cause: unknown,
  ): Promise<void> {
    const status = (cause as { status?: number })?.status;
    const permanent = typeof status === 'number' && status >= 400 && status < 500;
    if (permanent) return;
    try {
      await this.events.release(providerName, event.eventId);
      tracker.track({
        step: 'WEBHOOK_RELEASED',
        provider: providerName,
        meta: {
          eventId: event.eventId,
          type: event.type,
          reason: 'transient settlement failure — claim released for redelivery',
          error: cause instanceof Error ? cause.message : 'unknown',
        },
      });
    } catch (releaseErr) {
      tracker.track({
        step: 'WEBHOOK_RELEASED',
        provider: providerName,
        status: 'FAILED',
        meta: {
          eventId: event.eventId,
          type: event.type,
          error: releaseErr instanceof Error ? releaseErr.message : 'unknown',
          severity: 'CRITICAL',
        },
      });
    }
  }

  private async handleSettlementWebhook(
    providerName: string,
    event: NormalizedEvent,
  ): Promise<void> {
    if (!(await ownsSettlementEvent(event))) {
      tracker.track({
        step: 'WEBHOOK_IGNORED',
        provider: providerName,
        meta: { type: event.type, reason: 'no matching transfer/account/payment (foreign-account event)' },
      });
      return;
    }
    const fresh = await this.events.claim(providerName, event.eventId, event.raw);
    if (!fresh) {
      tracker.track({ step: 'WEBHOOK_DEDUPED', provider: providerName, meta: { type: event.type } });
      return;
    }
    try {
      await handleSettlementEvent(event);
    } catch (err) {
      await this.releaseClaimForRetry(providerName, event, err);
      throw err;
    }
    await this.events.markProcessed(providerName, event.eventId);
  }

  private async reconcilePaidOrder(
    intent: GatewayPaymentRecord,
    live: NormalizedOrderStatus,
  ): Promise<void> {
    tracker.track({
      step: 'RECONCILE_PAID',
      provider: intent.provider,
      intentId: intent.id,
      providerOrderRef: intent.providerOrderRef,
      meta: { capturedPaymentRef: live.capturedPaymentRef },
    });
    await this.confirm(intent, {
      type: 'PAID',
      eventId: `reconcile:${intent.providerOrderRef}`,
      providerOrderRef: intent.providerOrderRef,
      providerPaymentRef: live.capturedPaymentRef,
      amountMinor: live.amountPaidMinor,
      currency: intent.currency,
      raw: { reconciled: true },
    });
  }

  private async confirm(intent: GatewayPaymentRecord, event: NormalizedEvent): Promise<void> {
    if (intent.status === 'CAPTURED' || intent.status === 'REFUNDED') {
      return;
    }

    if (event.type === 'PAID' && event.amountMinor == null) {
      tracker.track({
        step: 'AMOUNT_MISMATCH',
        provider: intent.provider,
        intentId: intent.id,
        meta: { expected: toMinorUnits(intent.amount), got: null },
      });
      throw Object.assign(new Error('PAID webhook must include the captured amount'), {
        status: 400,
      });
    }
    if (event.amountMinor != null && event.amountMinor !== toMinorUnits(intent.amount)) {
      tracker.track({
        step: 'AMOUNT_MISMATCH',
        provider: intent.provider,
        intentId: intent.id,
        meta: { expected: toMinorUnits(intent.amount), got: event.amountMinor },
      });
      throw Object.assign(new Error('Webhook amount does not match intent'), {
        status: 400,
      });
    }

    if (event.providerPaymentRef) {
      await this.repo.attachProviderRefs(intent.id, {
        providerPaymentRef: event.providerPaymentRef,
      });
    }

    const settled: GatewayPaymentRecord = {
      ...intent,
      status: 'CAPTURED',
      providerPaymentRef: event.providerPaymentRef ?? intent.providerPaymentRef,
    };
    const handler = settlementFor(intent.target.type);
    await prisma.$transaction(async (tx) => {
      await this.repo.updateStatus(intent.id, 'CAPTURED', tx);
      await handler.onPaid(settled, tx);
    });
    tracker.track({
      step: 'PAYMENT_CONFIRMED',
      provider: intent.provider,
      intentId: intent.id,
      status: 'SUCCESS',
    });

    if (handler.afterCommit) {
      try {
        await handler.afterCommit(settled);
      } catch (err) {
        tracker.track({
          step: 'SETTLEMENT_DONE',
          provider: intent.provider,
          intentId: intent.id,
          targetType: intent.target.type,
          status: 'FAILED',
          error: err instanceof Error ? err.message : 'afterCommit failed',
        });
      }
    }
    tracker.track({
      step: 'SETTLEMENT_DONE',
      provider: intent.provider,
      intentId: intent.id,
      targetType: intent.target.type,
      status: 'SUCCESS',
    });
  }

  private async abandon(intent: GatewayPaymentRecord): Promise<void> {
    const handler = settlementFor(intent.target.type);
    if (handler.onAbandon) {
      try {
        await handler.onAbandon(intent);
      } catch (err) {
        tracker.track({
          step: 'PAYMENT_FAILED',
          provider: intent.provider,
          intentId: intent.id,
          meta: { phase: 'onAbandon', error: err instanceof Error ? err.message : 'unknown' },
        });
      }
    }
    await this.fail(intent);
  }

  private async onRefundEvent(
    providerName: string,
    event: NormalizedEvent,
  ): Promise<void> {
    if (!event.providerRefundRef) return;
    const row = await this.refunds.findByProviderRef(
      providerName,
      event.providerRefundRef,
    );
    if (!row || row.status === 'PROCESSED') return;
    await this.refunds.update(row.id, { status: 'PROCESSED' });
    tracker.track({
      step: 'REFUND_PROCESSED',
      provider: row.provider,
      meta: { refundId: row.id, providerRefundRef: event.providerRefundRef },
    });
  }

  private async fail(intent: GatewayPaymentRecord): Promise<void> {
    if (intent.status === 'CAPTURED' || intent.status === 'REFUNDED') {
      return;
    }
    await this.repo.updateStatus(intent.id, 'FAILED');
    tracker.track({
      step: 'PAYMENT_FAILED',
      provider: intent.provider,
      intentId: intent.id,
      status: 'FAILED',
    });
  }
}
