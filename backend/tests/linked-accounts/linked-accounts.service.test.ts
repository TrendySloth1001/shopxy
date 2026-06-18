/**
 * Unit tests for linked-account onboarding (linked-accounts.service.ts).
 * prisma and the provider registry are vi.mock'd.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest';

const { linkedAccount, createLinkedAccount, fetchAccountStatus, fetchAccount, provider } = vi.hoisted(() => {
  const linkedAccount = {
    findUnique: vi.fn(),
    upsert: vi.fn(),
    update: vi.fn(),
    updateMany: vi.fn(),
    findMany: vi.fn(),
  };
  const createLinkedAccount = vi.fn();
  const fetchAccountStatus = vi.fn();
  const fetchAccount = vi.fn();
  const provider = { name: 'RAZORPAY', createLinkedAccount, fetchAccountStatus, fetchAccount };
  return { linkedAccount, createLinkedAccount, fetchAccountStatus, fetchAccount, provider };
});

vi.mock('../../src/infra/db/prisma.js', () => ({ default: { linkedAccount } }));
vi.mock('../../src/modules/payment-gateway/providers/registry.js', () => ({
  getProvider: () => provider,
}));

import { linkedAccountsService } from '../../src/modules/linked-accounts/linked-accounts.service.js';
import { mapProviderKyc } from '../../src/modules/payment-gateway/kyc-status.js';

const ONBOARD = {
  shopId: 7,
  email: 'm@shop.test',
  phone: '9999999999',
  legalBusinessName: 'Shop LLP',
  businessType: 'partnership',
  contactName: 'Owner',
  category: 'ecommerce',
  registeredAddress: {
    street1: '1 MG Road',
    city: 'Bengaluru',
    state: 'KARNATAKA',
    postalCode: '560001',
    country: 'IN',
  },
  pan: 'AAACL1234C',
  beneficiaryName: 'Shop LLP',
  bankAccountNumber: '1234567890',
  bankIfsc: 'HDFC0001234',
};

const row = (over: Record<string, unknown> = {}) => ({
  shopId: 7,
  providerAccountId: null,
  kycStatus: 'CREATED',
  payoutsEnabled: false,
  email: null,
  contactName: null,
  businessType: null,
  ...over,
});

beforeEach(() => {
  vi.clearAllMocks();
  linkedAccount.upsert.mockResolvedValue({ shopId: 7 });
  linkedAccount.updateMany.mockResolvedValue({ count: 1 });
});

describe('mapProviderKyc (single source of truth)', () => {
  it('maps status → enum + payoutsEnabled, with no sticky activated_at', () => {
    expect(mapProviderKyc('activated')).toEqual({ kycStatus: 'ACTIVATED', payoutsEnabled: true });
    expect(mapProviderKyc('under_review')).toEqual({ kycStatus: 'UNDER_REVIEW', payoutsEnabled: false });
    expect(mapProviderKyc('suspended')).toEqual({ kycStatus: 'SUSPENDED', payoutsEnabled: false });
    expect(mapProviderKyc('funds_held')).toEqual({ kycStatus: 'FUNDS_HELD', payoutsEnabled: false });
    expect(mapProviderKyc('created')).toEqual({ kycStatus: 'CREATED', payoutsEnabled: false });
  });
});

describe('startOnboarding', () => {
  it('reserves, claims, creates at the provider, and stores the row', async () => {
    linkedAccount.findUnique.mockResolvedValue(row({ providerAccountId: null }));
    createLinkedAccount.mockResolvedValue({ providerAccountId: 'acc_NEW', kycStatus: 'CREATED', payoutsEnabled: false });
    linkedAccount.update.mockResolvedValue(row({ providerAccountId: 'acc_NEW' }));

    const r = await linkedAccountsService.startOnboarding(ONBOARD);

    expect(r).toEqual({ ok: true, account: expect.objectContaining({ providerAccountId: 'acc_NEW' }) });
    expect(linkedAccount.upsert).toHaveBeenCalledTimes(1); // reserved first
    expect(createLinkedAccount).toHaveBeenCalledTimes(1);
    // KYC + bank details are forwarded to the provider…
    expect(createLinkedAccount).toHaveBeenCalledWith(
      expect.objectContaining({
        pan: 'AAACL1234C',
        category: 'ecommerce',
        registeredAddress: expect.objectContaining({ city: 'Bengaluru' }),
        bankAccountNumber: '1234567890',
        bankIfsc: 'HDFC0001234',
      }),
    );
    // …but PII (PAN, bank) is NEVER persisted (data minimization).
    const reservedData = (linkedAccount.upsert.mock.calls[0][0] as { create: Record<string, unknown> }).create;
    expect(reservedData).not.toHaveProperty('bankAccountNumber');
    expect(reservedData).not.toHaveProperty('pan');
    const updatedData = (linkedAccount.update.mock.calls[0][0] as { data: Record<string, unknown> }).data;
    expect(updatedData).not.toHaveProperty('bankAccountNumber');
    expect(updatedData).not.toHaveProperty('pan');
  });

  it('is idempotent: an already-onboarded shop returns its account WITHOUT a 2nd provider create', async () => {
    linkedAccount.findUnique.mockResolvedValue(row({ providerAccountId: 'acc_EXISTING', kycStatus: 'ACTIVATED', payoutsEnabled: true }));

    const r = await linkedAccountsService.startOnboarding(ONBOARD);

    expect(r).toMatchObject({ ok: true, account: { providerAccountId: 'acc_EXISTING' } });
    expect(createLinkedAccount).not.toHaveBeenCalled();
    expect(linkedAccount.updateMany).not.toHaveBeenCalled(); // never claimed
  });

  it('does NOT create at the provider when it loses the create-claim (concurrent/retry)', async () => {
    linkedAccount.findUnique
      .mockResolvedValueOnce(row({ providerAccountId: null })) // existing reserved
      .mockResolvedValueOnce(row({ providerAccountId: null, kycStatus: 'CREATING' })); // in-flight
    linkedAccount.updateMany.mockResolvedValue({ count: 0 }); // someone else owns the create

    const r = await linkedAccountsService.startOnboarding(ONBOARD);

    expect(createLinkedAccount).not.toHaveBeenCalled(); // no duplicate provider account
    expect(r).toMatchObject({ ok: true });
  });

  it('releases the claim when the provider create fails', async () => {
    linkedAccount.findUnique.mockResolvedValue(row({ providerAccountId: null }));
    createLinkedAccount.mockRejectedValue(new Error('razorpay 400'));

    await expect(linkedAccountsService.startOnboarding(ONBOARD)).rejects.toThrow('razorpay 400');
    // claim released back to CREATED.
    expect(linkedAccount.updateMany).toHaveBeenCalledWith({
      where: { shopId: 7, kycStatus: 'CREATING' },
      data: { kycStatus: 'CREATED' },
    });
  });
});

describe('connect existing account', () => {
  const DETAILS = {
    accountId: 'acc_LIVE',
    kycStatus: 'ACTIVATED',
    payoutsEnabled: true,
    email: 'm@shop.test',
    legalBusinessName: 'Shop LLP',
    contactName: 'Owner',
    businessType: 'partnership',
  };

  it('verifyConnect fetches + returns details without writing', async () => {
    fetchAccount.mockResolvedValue(DETAILS);
    const r = await linkedAccountsService.verifyConnect('acc_LIVE');
    expect(r).toEqual({ ok: true, details: DETAILS });
    expect(linkedAccount.upsert).not.toHaveBeenCalled();
    expect(linkedAccount.update).not.toHaveBeenCalled();
  });

  it('verifyConnect → NOT_FOUND when the account fetch fails (bad/foreign id)', async () => {
    fetchAccount.mockRejectedValue(new Error('razorpay 400'));
    const r = await linkedAccountsService.verifyConnect('acc_NOPE');
    expect(r).toEqual({ error: 'NOT_FOUND' });
  });

  it('confirmConnect stores the account with mapper-derived status', async () => {
    linkedAccount.findUnique.mockResolvedValue(null); // no prior account
    fetchAccount.mockResolvedValue(DETAILS);
    linkedAccount.upsert.mockResolvedValue(
      row({ providerAccountId: 'acc_LIVE', kycStatus: 'ACTIVATED', payoutsEnabled: true }),
    );

    const r = await linkedAccountsService.confirmConnect(7, 'acc_LIVE');

    expect(r).toMatchObject({ ok: true, account: { providerAccountId: 'acc_LIVE', payoutsEnabled: true } });
    const data = (linkedAccount.upsert.mock.calls[0][0] as { update: Record<string, unknown> }).update;
    expect(data).toMatchObject({ providerAccountId: 'acc_LIVE', payoutsEnabled: true });
  });

  it('confirmConnect rejects when a DIFFERENT account is already linked', async () => {
    linkedAccount.findUnique.mockResolvedValue({ providerAccountId: 'acc_OTHER' });
    const r = await linkedAccountsService.confirmConnect(7, 'acc_LIVE');
    expect(r).toEqual({ error: 'ALREADY_LINKED' });
    expect(fetchAccount).not.toHaveBeenCalled();
    expect(linkedAccount.upsert).not.toHaveBeenCalled();
  });

  it('confirmConnect is idempotent for the SAME account id', async () => {
    linkedAccount.findUnique.mockResolvedValue({ providerAccountId: 'acc_LIVE' });
    fetchAccount.mockResolvedValue(DETAILS);
    linkedAccount.upsert.mockResolvedValue(row({ providerAccountId: 'acc_LIVE', payoutsEnabled: true }));
    const r = await linkedAccountsService.confirmConnect(7, 'acc_LIVE');
    expect(r).toMatchObject({ ok: true });
  });
});

describe('refreshStatus', () => {
  it('re-polls the provider and syncs when stale', async () => {
    linkedAccount.findUnique.mockResolvedValue(
      row({ providerAccountId: 'acc_1', kycStatus: 'UNDER_REVIEW', updatedAt: new Date('2020-01-01') }),
    );
    fetchAccountStatus.mockResolvedValue({ kycStatus: 'ACTIVATED', payoutsEnabled: true });
    linkedAccount.update.mockResolvedValue(row({ providerAccountId: 'acc_1', kycStatus: 'ACTIVATED', payoutsEnabled: true }));

    const r = await linkedAccountsService.refreshStatus(7);

    expect(r?.payoutsEnabled).toBe(true);
    expect(linkedAccount.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { kycStatus: 'ACTIVATED', payoutsEnabled: true } }),
    );
  });

  it('throttles: does not re-poll when refreshed within the min interval', async () => {
    linkedAccount.findUnique.mockResolvedValue(
      row({ providerAccountId: 'acc_1', kycStatus: 'UNDER_REVIEW', updatedAt: new Date() }),
    );
    const r = await linkedAccountsService.refreshStatus(7);
    expect(fetchAccountStatus).not.toHaveBeenCalled();
    expect(r?.payoutsEnabled).toBe(false);
  });

  it('does not re-poll an already-activated account', async () => {
    linkedAccount.findUnique.mockResolvedValue(
      row({ providerAccountId: 'acc_1', kycStatus: 'ACTIVATED', payoutsEnabled: true, updatedAt: new Date('2020-01-01') }),
    );
    await linkedAccountsService.refreshStatus(7);
    expect(fetchAccountStatus).not.toHaveBeenCalled();
  });
});

describe('reconcilePendingKyc', () => {
  it('activates accounts the provider now reports as enabled', async () => {
    linkedAccount.findMany.mockResolvedValue([
      { shopId: 7, providerAccountId: 'acc_1' },
      { shopId: 8, providerAccountId: 'acc_2' },
    ]);
    fetchAccountStatus
      .mockResolvedValueOnce({ kycStatus: 'ACTIVATED', payoutsEnabled: true })
      .mockResolvedValueOnce({ kycStatus: 'UNDER_REVIEW', payoutsEnabled: false });

    const r = await linkedAccountsService.reconcilePendingKyc();

    expect(r).toEqual({ scanned: 2, activated: 1, errors: 0 });
    expect(linkedAccount.updateMany).toHaveBeenCalledWith({
      where: { shopId: 7, payoutsEnabled: false },
      data: { kycStatus: 'ACTIVATED', payoutsEnabled: true },
    });
  });

  it('isolates a per-account failure', async () => {
    linkedAccount.findMany.mockResolvedValue([
      { shopId: 7, providerAccountId: 'acc_1' },
      { shopId: 8, providerAccountId: 'acc_2' },
    ]);
    fetchAccountStatus
      .mockRejectedValueOnce(new Error('rzp 503'))
      .mockResolvedValueOnce({ kycStatus: 'ACTIVATED', payoutsEnabled: true });

    const r = await linkedAccountsService.reconcilePendingKyc();

    expect(r).toEqual({ scanned: 2, activated: 1, errors: 1 });
  });
});
