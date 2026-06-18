/**
 * Single source of truth: a Razorpay account status → our LinkedAccount KYC enum
 * AND whether the account can actually be settled to. The adapter, the account.*
 * webhook handler, and the onboarding service ALL map through this so they can
 * never drift.
 *
 * The prior bug this fixes: three separate mappers, one of which derived
 * payoutsEnabled from a STICKY `activated_at` (which Razorpay leaves set even
 * after a suspension) — so the KYC re-poll could resurrect payouts on an account
 * the webhook had disabled. payoutsEnabled is now derived ONLY from the current
 * status, here, once.
 */
export interface KycState {
  kycStatus: string;
  payoutsEnabled: boolean;
}

export function mapProviderKyc(providerStatus: string): KycState {
  switch (providerStatus) {
    case 'activated':
    case 'funds_released':
    // Razorpay INDIVIDUAL Route linked accounts use `created` as their terminal,
    // ready-to-receive-transfers state (they never move to `activated` — that's
    // the business-account path after full KYC). The dashboard shows such an
    // account as "Activated" while the v2 API reports `created`. Treating
    // `created` as payout-ready matches Razorpay's behaviour (verified against a
    // working production Route integration) — without this, a live, dashboard-
    // activated individual account is wrongly gated off.
    case 'created':
      return { kycStatus: 'ACTIVATED', payoutsEnabled: true };
    case 'under_review':
      return { kycStatus: 'UNDER_REVIEW', payoutsEnabled: false };
    case 'needs_clarification':
      return { kycStatus: 'NEEDS_CLARIFICATION', payoutsEnabled: false };
    case 'suspended':
      return { kycStatus: 'SUSPENDED', payoutsEnabled: false };
    case 'funds_held':
      // A settlement hold disables payouts but isn't a full de-activation.
      return { kycStatus: 'FUNDS_HELD', payoutsEnabled: false };
    default:
      return { kycStatus: 'CREATED', payoutsEnabled: false };
  }
}
