export type ProviderName = string;

export type GatewayPaymentStatus =
  | 'CREATED'
  | 'PENDING'
  | 'CAPTURED'
  | 'FAILED'
  | 'REFUNDED';

export type SettlementTargetType = 'WALLET' | 'ORDER' | 'INVOICE' | 'POS';

export interface SettlementTarget {
  type: SettlementTargetType;
  id: number;
}

export interface GatewayPaymentRecord {
  id: number;
  provider: ProviderName;
  status: GatewayPaymentStatus;
  amount: number;
  currency: string;
  target: SettlementTarget;
  shopId: number | null;
  customerUserId: number | null;
  providerOrderRef: string | null;
  providerPaymentRef: string | null;
  amountRefunded: number;
  idempotencyKey: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export type GatewayRefundStatus = 'PENDING' | 'PROCESSED' | 'FAILED';

export interface GatewayRefundRecord {
  id: number;
  gatewayPaymentId: number;
  provider: ProviderName;
  status: GatewayRefundStatus;
  amount: number;
  currency: string;
  providerRefundRef: string | null;
  sourceType: string;
  sourceId: number;
  reason: string | null;
  idempotencyKey: string;
  createdAt: Date;
  updatedAt: Date;
}

export type GatewayEventType =
  | 'PAID'
  | 'FAILED'
  | 'REFUNDED'
  | 'PENDING'
  | 'UNKNOWN'
  | 'TRANSFER_PROCESSED'
  | 'TRANSFER_FAILED'
  | 'TRANSFER_REVERSED'
  | 'ACCOUNT_UPDATED'
  | 'DISPUTE_LOST'
  | 'DISPUTE_OTHER';

export interface NormalizedTransferEvent {
  ref: string;
  status: string;
  amountReversedMinor: number;
  onHold: boolean;
}

export interface NormalizedAccountEvent {
  ref: string;
  status: string;
}

export interface NormalizedDisputeEvent {
  ref: string;
  providerPaymentRef: string | null;
}

export interface NormalizedEvent {
  type: GatewayEventType;
  eventId: string;
  providerOrderRef: string | null;
  providerPaymentRef: string | null;
  providerRefundRef?: string | null;
  amountMinor: number | null;
  currency: string | null;
  transfer?: NormalizedTransferEvent;
  account?: NormalizedAccountEvent;
  dispute?: NormalizedDisputeEvent;
  raw: unknown;
}

export interface GatewaySession {
  providerOrderRef: string;
  clientParams: Record<string, unknown>;
}

export interface NormalizedStatus {
  status: GatewayEventType;
  amountMinor: number | null;
  currency: string | null;
  providerPaymentRef: string | null;
}

export interface NormalizedRefund {
  providerRefundRef: string;
  amountMinor: number;
  status: 'PENDING' | 'PROCESSED' | 'FAILED';
}

export interface NormalizedOrderStatus {
  status: 'CREATED' | 'ATTEMPTED' | 'PAID';
  amountPaidMinor: number;
  capturedPaymentRef: string | null;
}
