import type {
  CreateLinkedAccountParams,
  CreatePosQrParams,
  CreateSessionParams,
  ExistingTransfer,
  HandshakeParams,
  HeaderBag,
  LinkedAccountResult,
  OnboardingCapablePort,
  PaymentGatewayPort,
  PosQrResult,
  QrCapablePort,
  RefundParams,
  SplitCapablePort,
  TransferRequest,
  TransferResult,
} from '../ports/payment-provider.port.js';
import type {
  GatewayEventType,
  GatewaySession,
  NormalizedEvent,
  NormalizedOrderStatus,
  NormalizedRefund,
  NormalizedStatus,
} from '../ports/types.js';
import { hmacSha256Hex, timingSafeEqualHex, headerValue } from '../helpers.js';
import { mapProviderKyc, type KycState } from '../kyc-status.js';
import { requireEnv, envOr } from '../../../shared/env.js';

const RAZORPAY_API = 'https://api.razorpay.com/v1';
const RAZORPAY_API_V2 = 'https://api.razorpay.com/v2';

const MIN_TRANSFER_PAISE = 100;
const ON_HOLD_UNTIL_MIN = 946684800;
const ON_HOLD_UNTIL_MAX = 4765046400;

function mapEventType(event: string): GatewayEventType {
  switch (event) {
    case 'payment.captured':
    case 'order.paid':
    case 'qr_code.credited':
      return 'PAID';
    case 'payment.failed':
      return 'FAILED';
    case 'refund.processed':
    case 'refund.created':
      return 'REFUNDED';
    case 'payment.authorized':
      return 'PENDING';
    case 'transfer.processed':
    case 'transfer.settled':
      return 'TRANSFER_PROCESSED';
    case 'transfer.failed':
      return 'TRANSFER_FAILED';
    case 'transfer.reversed':
      return 'TRANSFER_REVERSED';
    case 'account.activated':
    case 'account.under_review':
    case 'account.needs_clarification':
    case 'account.suspended':
    case 'account.funds_held':
    case 'account.funds_released':
      return 'ACCOUNT_UPDATED';
    case 'payment.dispute.lost':
      return 'DISPUTE_LOST';
    case 'payment.dispute.created':
    case 'payment.dispute.won':
    case 'payment.dispute.closed':
    case 'payment.dispute.under_review':
    case 'payment.dispute.action_required':
      return 'DISPUTE_OTHER';
    default:
      return 'UNKNOWN';
  }
}

function mapPaymentStatus(status: string): GatewayEventType {
  switch (status) {
    case 'captured':
      return 'PAID';
    case 'failed':
      return 'FAILED';
    case 'refunded':
      return 'REFUNDED';
    case 'authorized':
    case 'created':
      return 'PENDING';
    default:
      return 'UNKNOWN';
  }
}

function mapRefundStatus(status: string): NormalizedRefund['status'] {
  return status === 'processed' ? 'PROCESSED' : status === 'failed' ? 'FAILED' : 'PENDING';
}

export interface RazorpayCallConfig {
  maxRetries?: number;
  retryBaseMs?: number;
  jitter?: boolean;
  circuitThreshold?: number;
  circuitWindowMs?: number;
  circuitCooldownMs?: number;
}

type CircuitState = 'CLOSED' | 'OPEN' | 'HALF_OPEN';

export class RazorpayProvider
  implements PaymentGatewayPort, SplitCapablePort, OnboardingCapablePort, QrCapablePort
{
  readonly name = 'RAZORPAY';

  private readonly keyId: string;
  private readonly keySecret: string;
  private readonly webhookSecret: string;

  private readonly cfg: Required<RazorpayCallConfig>;
  private circuitState: CircuitState = 'CLOSED';
  private failureTimestamps: number[] = [];
  private circuitOpenedAt = 0;
  private halfOpenProbeInFlight = false;

  constructor(opts: RazorpayCallConfig = {}) {
    this.keyId = requireEnv('RAZORPAY_KEY_ID');
    this.keySecret = requireEnv('RAZORPAY_KEY_SECRET');
    this.webhookSecret = envOr('RAZORPAY_WEBHOOK_SECRET', '');
    if (!this.webhookSecret && process.env.NODE_ENV === 'production') {
      throw new Error(
        'RAZORPAY_WEBHOOK_SECRET is required in production when Razorpay keys are configured',
      );
    }
    this.cfg = {
      maxRetries: Math.max(1, opts.maxRetries ?? 3),
      retryBaseMs: opts.retryBaseMs ?? 200,
      jitter: opts.jitter ?? true,
      circuitThreshold: opts.circuitThreshold ?? 5,
      circuitWindowMs: opts.circuitWindowMs ?? 60_000,
      circuitCooldownMs: opts.circuitCooldownMs ?? 30_000,
    };
  }

  private authHeader(): string {
    const token = Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64');
    return `Basic ${token}`;
  }

  private recordTransientFailure(): void {
    const now = Date.now();
    this.halfOpenProbeInFlight = false;
    if (this.circuitState === 'HALF_OPEN') {
      this.circuitState = 'OPEN';
      this.circuitOpenedAt = now;
      return;
    }
    this.failureTimestamps.push(now);
    this.failureTimestamps = this.failureTimestamps.filter(
      (t) => now - t < this.cfg.circuitWindowMs,
    );
    if (
      this.failureTimestamps.length >= this.cfg.circuitThreshold &&
      this.circuitState === 'CLOSED'
    ) {
      this.circuitState = 'OPEN';
      this.circuitOpenedAt = now;
    }
  }

  private recordUpstreamResponsive(): void {
    this.halfOpenProbeInFlight = false;
    if (this.circuitState === 'HALF_OPEN') {
      this.circuitState = 'CLOSED';
    }
    this.failureTimestamps = [];
  }

  private canProceed(): boolean {
    if (this.circuitState === 'CLOSED') return true;
    if (this.halfOpenProbeInFlight) return false;
    if (Date.now() - this.circuitOpenedAt >= this.cfg.circuitCooldownMs) {
      this.circuitState = 'HALF_OPEN';
      this.halfOpenProbeInFlight = true;
      return true;
    }
    return false;
  }

  private isTransient(status: number | undefined): boolean {
    return status === undefined || status === 429 || status === 502;
  }

  private async call<T>(
    method: 'GET' | 'POST' | 'PATCH',
    path: string,
    body?: unknown,
    opts?: { idempotent?: boolean; idempotencyKey?: string },
  ): Promise<T> {
    const idempotent =
      opts?.idempotent ?? (method === 'GET' || method === 'PATCH' || !!opts?.idempotencyKey);

    let lastErr: unknown;
    for (let attempt = 0; attempt < this.cfg.maxRetries; attempt++) {
      if (!this.canProceed()) {
        throw Object.assign(
          new Error('Razorpay temporarily unavailable — circuit breaker open'),
          { status: 503 },
        );
      }
      try {
        const result = await this.rawCall<T>(method, path, body, opts?.idempotencyKey);
        this.recordUpstreamResponsive();
        return result;
      } catch (err) {
        lastErr = err;
        const status = (err as { status?: number }).status;
        if (!this.isTransient(status)) {
          this.recordUpstreamResponsive();
          throw err;
        }
        const retryable = idempotent ? true : status === 429;
        if (retryable && attempt < this.cfg.maxRetries - 1) {
          await this.backoff(attempt);
          continue;
        }
        this.recordTransientFailure();
        throw err;
      }
    }
    throw lastErr;
  }

  private async backoff(attempt: number): Promise<void> {
    const base = this.cfg.retryBaseMs * Math.pow(2, attempt);
    const delay = this.cfg.jitter ? base + Math.random() * 50 : base;
    if (delay > 0) await new Promise((r) => setTimeout(r, delay));
  }

  private async rawCall<T>(
    method: 'GET' | 'POST' | 'PATCH',
    path: string,
    body?: unknown,
    idempotencyKey?: string,
  ): Promise<T> {
    const url = path.startsWith('http') ? path : `${RAZORPAY_API}${path}`;
    const res = await fetch(url, {
      method,
      headers: {
        Authorization: this.authHeader(),
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const text = await res.text();
    let json: unknown;
    try {
      json = text ? JSON.parse(text) : {};
    } catch {
      json = { raw: text };
    }
    if (!res.ok) {
      const desc =
        (json as { error?: { description?: string } })?.error?.description ??
        `Razorpay ${method} ${path} failed (${res.status})`;
      const status =
        res.status === 400
          ? 400
          : res.status === 401
            ? 401
            : res.status === 402
              ? 402
              : res.status === 429
                ? 429
                : res.status >= 500
                  ? 502
                  : 500;
      throw Object.assign(new Error(desc), { status });
    }
    return json as T;
  }

  buildClientParams(p: {
    providerOrderRef: string;
    amountMinor: number;
    currency: string;
  }): Record<string, unknown> {
    return {
      key: this.keyId,
      order_id: p.providerOrderRef,
      amount: p.amountMinor,
      currency: p.currency,
    };
  }

  async createSession(p: CreateSessionParams): Promise<GatewaySession> {
    const order = await this.call<{ id: string }>('POST', '/orders', {
      amount: p.amountMinor,
      currency: p.currency,
      receipt: p.intentRef,
      notes: p.notes ?? {},
    });
    return {
      providerOrderRef: order.id,
      clientParams: this.buildClientParams({
        providerOrderRef: order.id,
        amountMinor: p.amountMinor,
        currency: p.currency,
      }),
    };
  }

  verifyHandshake(p: HandshakeParams): boolean {
    const expected = hmacSha256Hex(
      this.keySecret,
      `${p.providerOrderRef}|${p.providerPaymentRef}`,
    );
    return timingSafeEqualHex(expected, p.signature);
  }

  verifyWebhookSignature(rawBody: Buffer, headers: HeaderBag): boolean {
    if (!this.webhookSecret) return false;
    const signature = headerValue(headers, 'x-razorpay-signature');
    if (!signature) return false;
    const expected = hmacSha256Hex(this.webhookSecret, rawBody);
    return timingSafeEqualHex(expected, signature);
  }

  parseWebhookEvent(rawBody: Buffer, headers: HeaderBag): NormalizedEvent {
    let payload: {
      event?: string;
      payload?: {
        payment?: { entity?: { id?: string; order_id?: string; amount?: number; currency?: string } };
        order?: {
          entity?: {
            id?: string;
            amount?: number;
            amount_paid?: number;
            currency?: string;
          };
        };
        refund?: { entity?: { id?: string; payment_id?: string; amount?: number; currency?: string } };
        qr_code?: { entity?: { id?: string } };
        transfer?: {
          entity?: { id?: string; status?: string; amount_reversed?: number; on_hold?: boolean };
        };
        account?: { entity?: { id?: string; status?: string } };
        dispute?: { entity?: { id?: string; payment_id?: string; status?: string } };
      };
    };
    try {
      payload = JSON.parse(rawBody.toString('utf8'));
    } catch (err) {
      throw Object.assign(
        new Error(`Invalid webhook JSON: ${err instanceof Error ? err.message : 'parse error'}`),
        { status: 400 },
      );
    }
    const event = payload.event ?? '';
    let type = mapEventType(event);
    const payEntity = payload.payload?.payment?.entity;
    const orderEntity = payload.payload?.order?.entity;
    const refundEntity = payload.payload?.refund?.entity;
    const qrEntity = payload.payload?.qr_code?.entity;
    const transferEntity = payload.payload?.transfer?.entity;
    const accountEntity = payload.payload?.account?.entity;
    const disputeEntity = payload.payload?.dispute?.entity;

    if (disputeEntity?.status === 'lost' && type === 'DISPUTE_OTHER') {
      type = 'DISPUTE_LOST';
    }

    const eventId =
      headerValue(headers, 'x-razorpay-event-id') ??
      `${payEntity?.id ?? refundEntity?.id ?? orderEntity?.id ?? qrEntity?.id ?? transferEntity?.id ?? accountEntity?.id ?? disputeEntity?.id ?? 'unknown'}:${event}`;

    return {
      type,
      eventId,
      providerOrderRef: qrEntity?.id ?? payEntity?.order_id ?? orderEntity?.id ?? null,
      providerPaymentRef:
        payEntity?.id ?? refundEntity?.payment_id ?? disputeEntity?.payment_id ?? null,
      providerRefundRef: refundEntity?.id ?? null,
      amountMinor:
        payEntity?.amount ??
        orderEntity?.amount_paid ??
        refundEntity?.amount ??
        null,
      currency: payEntity?.currency ?? orderEntity?.currency ?? refundEntity?.currency ?? null,
      ...(transferEntity?.id
        ? {
            transfer: {
              ref: transferEntity.id,
              status: transferEntity.status ?? 'unknown',
              amountReversedMinor: transferEntity.amount_reversed ?? 0,
              onHold: !!transferEntity.on_hold,
            },
          }
        : {}),
      ...(accountEntity?.id
        ? { account: { ref: accountEntity.id, status: accountEntity.status ?? 'unknown' } }
        : {}),
      ...(type === 'DISPUTE_LOST' || type === 'DISPUTE_OTHER'
        ? {
            dispute: {
              ref: disputeEntity?.id ?? 'unknown',
              providerPaymentRef: disputeEntity?.payment_id ?? payEntity?.id ?? null,
            },
          }
        : {}),
      raw: payload,
    };
  }

  async fetchOrderStatus(providerOrderRef: string): Promise<NormalizedOrderStatus> {
    if (providerOrderRef.startsWith('qr_')) {
      return this.fetchQrOrderStatus(providerOrderRef);
    }
    const order = await this.call<{ status: string; amount_paid?: number }>(
      'GET',
      `/orders/${providerOrderRef}`,
    );
    let capturedPaymentRef: string | null = null;
    if (order.status === 'paid') {
      const pays = await this.call<{ items?: Array<{ id: string; status: string }> }>(
        'GET',
        `/orders/${providerOrderRef}/payments`,
      );
      const items = pays.items ?? [];
      const cap =
        items.find((p) => p.status === 'captured') ??
        items.find((p) => p.status === 'authorized');
      capturedPaymentRef = cap?.id ?? null;
    }
    const status =
      order.status === 'paid' ? 'PAID' : order.status === 'attempted' ? 'ATTEMPTED' : 'CREATED';
    return { status, amountPaidMinor: order.amount_paid ?? 0, capturedPaymentRef };
  }

  async fetchPaymentStatus(providerPaymentRef: string): Promise<NormalizedStatus> {
    const pay = await this.call<{ status: string; amount: number; currency: string; id: string }>(
      'GET',
      `/payments/${providerPaymentRef}`,
    );
    return {
      status: mapPaymentStatus(pay.status),
      amountMinor: pay.amount,
      currency: pay.currency,
      providerPaymentRef: pay.id,
    };
  }

  async refund(p: RefundParams): Promise<NormalizedRefund> {
    const refund = await this.call<{ id: string; amount: number; status: string }>(
      'POST',
      `/payments/${p.providerPaymentRef}/refund`,
      {
        amount: p.amountMinor,
        ...(p.notes ? { notes: p.notes } : {}),
      },
      p.idempotencyKey ? { idempotencyKey: p.idempotencyKey } : undefined,
    );
    return {
      providerRefundRef: refund.id,
      amountMinor: refund.amount,
      status: mapRefundStatus(refund.status),
    };
  }

  async fetchRefundStatus(providerRefundRef: string): Promise<NormalizedRefund> {
    const r = await this.call<{ id: string; amount: number; status: string }>(
      'GET',
      `/refunds/${providerRefundRef}`,
    );
    return { providerRefundRef: r.id, amountMinor: r.amount, status: mapRefundStatus(r.status) };
  }

  async createTransfers(
    providerPaymentRef: string,
    transfers: TransferRequest[],
  ): Promise<TransferResult[]> {
    const errors: { index: number; field: string; message: string }[] = [];
    for (let i = 0; i < transfers.length; i++) {
      const t = transfers[i];
      if (t.amountMinor < MIN_TRANSFER_PAISE) {
        errors.push({
          index: i,
          field: 'amountMinor',
          message: `amount must be ≥ ₹1 (got ${t.amountMinor} paise)`,
        });
      }
      if (
        t.onHoldUntil != null &&
        (t.onHoldUntil < ON_HOLD_UNTIL_MIN || t.onHoldUntil > ON_HOLD_UNTIL_MAX)
      ) {
        errors.push({
          index: i,
          field: 'onHoldUntil',
          message: `must be within ${ON_HOLD_UNTIL_MIN}-${ON_HOLD_UNTIL_MAX} (got ${t.onHoldUntil})`,
        });
      }
    }
    if (errors.length > 0) {
      const summary = errors
        .map((e) => `transfers[${e.index}].${e.field}: ${e.message}`)
        .join('; ');
      throw Object.assign(new Error(`Transfer validation failed: ${summary}`), {
        status: 400,
        errors,
      });
    }

    const payload = {
      transfers: transfers.map((t) => ({
        account: t.destinationAccount,
        amount: t.amountMinor,
        currency: 'INR',
        ...(t.onHold != null ? { on_hold: t.onHold } : {}),
        ...(t.onHoldUntil != null ? { on_hold_until: t.onHoldUntil } : {}),
        ...(t.notes ? { notes: t.notes } : {}),
      })),
    };
    try {
      const res = await this.call<{
        items?: Array<{ id: string; recipient: string; amount: number; on_hold: boolean }>;
      }>('POST', `/payments/${providerPaymentRef}/transfers`, payload);
      return (res.items ?? []).map((it) => ({
        transferRef: it.id,
        destinationAccount: it.recipient,
        amountMinor: it.amount,
        onHold: !!it.on_hold,
      }));
    } catch (err) {
      const e = err as { status?: number; message?: string };
      if (
        e?.status === 400 &&
        typeof e.message === 'string' &&
        (e.message.includes('refund') || e.message.includes('transfer'))
      ) {
        throw Object.assign(
          new Error(
            `Cannot create transfer: payment may have an initiated refund. ` +
              `Transfers must be created BEFORE refunds. Original error: ${e.message}`,
          ),
          { status: 400 },
        );
      }
      throw err;
    }
  }

  async listTransfers(providerPaymentRef: string): Promise<ExistingTransfer[]> {
    const res = await this.call<{
      items?: Array<{
        id: string;
        recipient: string;
        amount: number;
        on_hold: boolean;
        status?: string;
        amount_reversed?: number;
        notes?: Record<string, string> | string[];
      }>;
    }>('GET', `/payments/${providerPaymentRef}/transfers`);
    return (res.items ?? []).map((it) => ({
      transferRef: it.id,
      destinationAccount: it.recipient,
      amountMinor: it.amount,
      onHold: !!it.on_hold,
      status: it.status ?? 'unknown',
      amountReversedMinor: it.amount_reversed ?? 0,
      notes: Array.isArray(it.notes) ? {} : (it.notes ?? {}),
    }));
  }

  async releaseTransfer(transferRef: string): Promise<void> {
    await this.call('PATCH', `/transfers/${transferRef}`, { on_hold: false });
  }

  async reverseTransfer(transferRef: string, amountMinor?: number): Promise<void> {
    if (amountMinor != null && amountMinor < MIN_TRANSFER_PAISE) {
      throw Object.assign(new Error('Reversal amount must be ≥ ₹1'), { status: 400 });
    }
    const body = amountMinor != null ? { amount: amountMinor } : {};
    await this.call('POST', `/transfers/${transferRef}/reversals`, body);
  }

  async createLinkedAccount(p: CreateLinkedAccountParams): Promise<LinkedAccountResult> {
    const legalInfo: Record<string, string> = { pan: p.pan };
    if (p.gst) legalInfo.gst = p.gst;

    const registered: Record<string, string> = {
      street1: p.registeredAddress.street1,
      city: p.registeredAddress.city,
      state: p.registeredAddress.state,
      postal_code: p.registeredAddress.postalCode,
      country: p.registeredAddress.country,
    };
    if (p.registeredAddress.street2) registered.street2 = p.registeredAddress.street2;

    const profile: Record<string, unknown> = {
      category: p.category,
      addresses: { registered },
    };
    if (p.subcategory) profile.subcategory = p.subcategory;

    const res = await this.call<{ id: string; status?: string }>(
      'POST',
      `${RAZORPAY_API_V2}/accounts`,
      {
        email: p.email,
        phone: p.phone,
        type: 'route',
        reference_id: `shop_${p.shopId}`,
        legal_business_name: p.legalBusinessName,
        customer_facing_business_name:
          p.customerFacingBusinessName || p.legalBusinessName,
        business_type: p.businessType,
        contact_name: p.contactName,
        profile,
        legal_info: legalInfo,
        notes: { shopId: String(p.shopId), app: 'shopxy' },
      },
    );
    const accountId = res.id;

    const product = await this.call<{ id: string }>(
      'POST',
      `${RAZORPAY_API_V2}/accounts/${accountId}/products`,
      { product_name: 'route', tnc_accepted: true },
    );

    await this.call('PATCH', `${RAZORPAY_API_V2}/accounts/${accountId}/products/${product.id}`, {
      settlements: {
        account_number: p.bankAccountNumber,
        ifsc_code: p.bankIfsc,
        beneficiary_name: p.beneficiaryName,
      },
      tnc_accepted: true,
    });

    return { providerAccountId: accountId, ...mapProviderKyc(res.status ?? 'created') };
  }

  async fetchAccountStatus(providerAccountId: string): Promise<KycState> {
    const res = await this.call<{ status?: string }>(
      'GET',
      `${RAZORPAY_API_V2}/accounts/${providerAccountId}`,
    );
    return mapProviderKyc(res.status ?? 'created');
  }

  async fetchAccount(providerAccountId: string): Promise<{
    accountId: string;
    kycStatus: string;
    payoutsEnabled: boolean;
    email: string | null;
    legalBusinessName: string | null;
    contactName: string | null;
    businessType: string | null;
  }> {
    const res = await this.call<{
      id?: string;
      status?: string;
      email?: string;
      legal_business_name?: string;
      business_type?: string;
      contact_name?: string;
    }>('GET', `${RAZORPAY_API_V2}/accounts/${providerAccountId}`);
    const { kycStatus, payoutsEnabled } = mapProviderKyc(res.status ?? 'created');
    return {
      accountId: res.id ?? providerAccountId,
      kycStatus,
      payoutsEnabled,
      email: res.email ?? null,
      legalBusinessName: res.legal_business_name ?? null,
      contactName: res.contact_name ?? null,
      businessType: res.business_type ?? null,
    };
  }

  async createPosQr(p: CreatePosQrParams): Promise<PosQrResult> {
    const qr = await this.call<{ id: string; image_url?: string }>('POST', '/payments/qr_codes', {
      type: 'upi_qr',
      usage: 'single_use',
      fixed_amount: true,
      payment_amount: p.amountMinor,
      notes: p.notes ?? {},
    });
    return { qrId: qr.id, imageUrl: qr.image_url ?? '' };
  }

  async fetchQr(qrId: string): Promise<{ imageUrl: string; closed: boolean }> {
    const qr = await this.call<{ image_url?: string; status?: string }>(
      'GET',
      `/payments/qr_codes/${qrId}`,
    );
    return { imageUrl: qr.image_url ?? '', closed: qr.status === 'closed' };
  }

  async closeQr(qrId: string): Promise<void> {
    try {
      await this.call('POST', `/payments/qr_codes/${qrId}/close`, {});
    } catch (err) {
      if ((err as { status?: number }).status === 400) return;
      throw err;
    }
  }

  private async fetchQrOrderStatus(qrId: string): Promise<NormalizedOrderStatus> {
    const res = await this.call<{
      items?: Array<{ id: string; status: string; amount: number }>;
    }>('GET', `/payments/qr_codes/${qrId}/payments`);
    const items = res.items ?? [];
    const cap = items.find((p) => p.status === 'captured') ?? items.find((p) => p.status === 'authorized');
    if (cap) {
      return { status: 'PAID', amountPaidMinor: cap.amount, capturedPaymentRef: cap.id };
    }
    return { status: 'CREATED', amountPaidMinor: 0, capturedPaymentRef: null };
  }
}
