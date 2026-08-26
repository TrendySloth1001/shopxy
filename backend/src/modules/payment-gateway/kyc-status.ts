export interface KycState {
  kycStatus: string;
  payoutsEnabled: boolean;
}

export function mapProviderKyc(providerStatus: string): KycState {
  switch (providerStatus) {
    case 'activated':
    case 'funds_released':
    case 'created':
      return { kycStatus: 'ACTIVATED', payoutsEnabled: true };
    case 'under_review':
      return { kycStatus: 'UNDER_REVIEW', payoutsEnabled: false };
    case 'needs_clarification':
      return { kycStatus: 'NEEDS_CLARIFICATION', payoutsEnabled: false };
    case 'suspended':
      return { kycStatus: 'SUSPENDED', payoutsEnabled: false };
    case 'funds_held':
      return { kycStatus: 'FUNDS_HELD', payoutsEnabled: false };
    default:
      return { kycStatus: 'CREATED', payoutsEnabled: false };
  }
}
