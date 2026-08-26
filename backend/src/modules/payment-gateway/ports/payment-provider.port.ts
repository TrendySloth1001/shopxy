import type {
  GatewaySession,
  NormalizedEvent,
  NormalizedOrderStatus,
  NormalizedRefund,
  NormalizedStatus,
} from './types.js';

export type HeaderBag = Record<string, string | string[] | undefined>;

export interface CreateSessionParams {
  amountMinor: number;
  currency: string;
  intentRef: string;
  notes?: Record<string, string>;
}

export interface HandshakeParams {
  providerOrderRef: string;
  providerPaymentRef: string;
  signature: string;
}

export interface RefundParams {
  providerPaymentRef: string;
  amountMinor: number;
  idempotencyKey?: string;
  notes?: Record<string, string>;
}

export interface PaymentGatewayPort {
  readonly name: string;

  createSession(p: CreateSessionParams): Promise<GatewaySession>;

  buildClientParams(p: {
    providerOrderRef: string;
    amountMinor: number;
    currency: string;
  }): Record<string, unknown>;

  verifyHandshake(p: HandshakeParams): boolean;

  verifyWebhookSignature(rawBody: Buffer, headers: HeaderBag): boolean;

  parseWebhookEvent(rawBody: Buffer, headers: HeaderBag): NormalizedEvent;

  fetchPaymentStatus(providerPaymentRef: string): Promise<NormalizedStatus>;

  fetchOrderStatus(providerOrderRef: string): Promise<NormalizedOrderStatus>;

  refund(p: RefundParams): Promise<NormalizedRefund>;

  fetchRefundStatus(providerRefundRef: string): Promise<NormalizedRefund>;
}

export interface TransferRequest {
  destinationAccount: string;
  amountMinor: number;
  onHold?: boolean;
  onHoldUntil?: number;
  notes?: Record<string, string>;
}

export interface TransferResult {
  transferRef: string;
  destinationAccount: string;
  amountMinor: number;
  onHold: boolean;
}

export interface ExistingTransfer {
  transferRef: string;
  destinationAccount: string;
  amountMinor: number;
  onHold: boolean;
  status: string;
  amountReversedMinor: number;
  notes: Record<string, string>;
}

export interface SplitCapablePort {
  createTransfers(
    providerPaymentRef: string,
    transfers: TransferRequest[],
  ): Promise<TransferResult[]>;
  listTransfers(providerPaymentRef: string): Promise<ExistingTransfer[]>;
  releaseTransfer(transferRef: string): Promise<void>;
  reverseTransfer(transferRef: string, amountMinor?: number): Promise<void>;
}

export function isSplitCapable(
  p: PaymentGatewayPort,
): p is PaymentGatewayPort & SplitCapablePort {
  return typeof (p as Partial<SplitCapablePort>).createTransfers === 'function';
}

export interface RegisteredAddress {
  street1: string;
  street2?: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
}

export interface CreateLinkedAccountParams {
  shopId: number;
  email: string;
  phone: string;
  legalBusinessName: string;
  customerFacingBusinessName?: string;
  businessType: string;
  contactName: string;
  category: string;
  subcategory?: string;
  registeredAddress: RegisteredAddress;
  pan: string;
  gst?: string;
  beneficiaryName: string;
  bankAccountNumber: string;
  bankIfsc: string;
}

export interface LinkedAccountResult {
  providerAccountId: string;
  kycStatus: string;
  payoutsEnabled: boolean;
}

export interface OnboardingCapablePort {
  createLinkedAccount(p: CreateLinkedAccountParams): Promise<LinkedAccountResult>;
  fetchAccountStatus(
    providerAccountId: string,
  ): Promise<{ kycStatus: string; payoutsEnabled: boolean }>;
  fetchAccount(providerAccountId: string): Promise<{
    accountId: string;
    kycStatus: string;
    payoutsEnabled: boolean;
    email: string | null;
    legalBusinessName: string | null;
    contactName: string | null;
    businessType: string | null;
  }>;
}

export function isOnboardingCapable(
  p: PaymentGatewayPort,
): p is PaymentGatewayPort & OnboardingCapablePort {
  return typeof (p as Partial<OnboardingCapablePort>).createLinkedAccount === 'function';
}

export interface CreatePosQrParams {
  amountMinor: number;
  intentRef: string;
  notes?: Record<string, string>;
}

export interface PosQrResult {
  qrId: string;
  imageUrl: string;
}

export interface QrCapablePort {
  createPosQr(p: CreatePosQrParams): Promise<PosQrResult>;
  fetchQr(qrId: string): Promise<{ imageUrl: string; closed: boolean }>;
  closeQr(qrId: string): Promise<void>;
}

export function isQrCapable(
  p: PaymentGatewayPort,
): p is PaymentGatewayPort & QrCapablePort {
  return typeof (p as Partial<QrCapablePort>).createPosQr === 'function';
}
