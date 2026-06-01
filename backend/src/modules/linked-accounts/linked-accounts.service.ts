/**
 * Linked-account KYC onboarding — creates and tracks a shop's Razorpay Route
 * payout destination. A shop with an ACTIVATED, payouts-enabled linked account
 * is what lets the ORDER split create real transfers; until then its slices are
 * recorded KYC_GATED and retried once activation lands (webhook or the reconcile
 * re-poll). One linked account per shop (the LinkedAccount @@unique(shopId)).
 */
import prisma from '../../infra/db/prisma.js';
import { getProvider } from '../payment-gateway/providers/registry.js';
import {
  isOnboardingCapable,
  type CreateLinkedAccountParams,
} from '../payment-gateway/ports/payment-provider.port.js';

const PROVIDER = 'RAZORPAY';
// Don't re-poll the provider for the same shop more often than this (a merchant
// spamming ?refresh=1 would otherwise burn API quota + trip the shared breaker).
const REFRESH_MIN_INTERVAL_MS = 30_000;

export interface LinkedAccountView {
  shopId: number;
  providerAccountId: string | null;
  kycStatus: string;
  payoutsEnabled: boolean;
  email: string | null;
  contactName: string | null;
  businessType: string | null;
}

type Row = {
  shopId: number;
  providerAccountId: string | null;
  kycStatus: string;
  payoutsEnabled: boolean;
  email: string | null;
  contactName: string | null;
  businessType: string | null;
};

function view(row: Row): LinkedAccountView {
  return {
    shopId: row.shopId,
    providerAccountId: row.providerAccountId,
    kycStatus: row.kycStatus,
    payoutsEnabled: row.payoutsEnabled,
    email: row.email,
    contactName: row.contactName,
    businessType: row.businessType,
  };
}

const SELECT = {
  shopId: true,
  providerAccountId: true,
  kycStatus: true,
  payoutsEnabled: true,
  email: true,
  contactName: true,
  businessType: true,
} as const;

export class LinkedAccountsService {
  /**
   * Start (or resume) onboarding for a shop. Idempotent: an already-onboarded
   * shop returns its existing account without creating a second at the provider;
   * a reserved-but-incomplete row (provider create failed earlier) is retried.
   */
  async startOnboarding(
    input: Omit<CreateLinkedAccountParams, 'shopId'> & { shopId: number },
  ): Promise<{ ok: true; account: LinkedAccountView } | { error: 'PROVIDER_UNAVAILABLE' }> {
    const provider = getProvider(PROVIDER);
    if (!isOnboardingCapable(provider)) return { error: 'PROVIDER_UNAVAILABLE' };

    // Reserve the per-shop row up front so the @@unique(shopId) serializes
    // concurrent/retried onboarding to a single row before any provider call.
    await prisma.linkedAccount.upsert({
      where: { shopId: input.shopId },
      create: {
        shopId: input.shopId,
        provider: PROVIDER,
        kycStatus: 'CREATED',
        payoutsEnabled: false,
        email: input.email,
        contactName: input.contactName,
        businessType: input.businessType,
      },
      update: {},
      select: { shopId: true },
    });

    const existing = await prisma.linkedAccount.findUnique({
      where: { shopId: input.shopId },
      select: SELECT,
    });
    if (existing?.providerAccountId) return { ok: true, account: view(existing) }; // already onboarded

    // Claim the provider-create: ONLY the request that flips null→CREATING calls
    // Razorpay, so a concurrent OR retried request can't mint a duplicate account
    // (the create is a non-idempotent POST — this is the real serialization).
    const claim = await prisma.linkedAccount.updateMany({
      where: { shopId: input.shopId, providerAccountId: null, kycStatus: { not: 'CREATING' } },
      data: { kycStatus: 'CREATING' },
    });
    if (claim.count !== 1) {
      // Another request owns the in-flight create — return the current state.
      const row = await prisma.linkedAccount.findUnique({
        where: { shopId: input.shopId },
        select: SELECT,
      });
      return { ok: true, account: view(row!) };
    }

    try {
      const acct = await provider.createLinkedAccount({
        shopId: input.shopId,
        email: input.email,
        phone: input.phone,
        legalBusinessName: input.legalBusinessName,
        customerFacingBusinessName: input.customerFacingBusinessName,
        businessType: input.businessType,
        contactName: input.contactName,
        category: input.category,
        subcategory: input.subcategory,
        registeredAddress: input.registeredAddress,
        // PAN/GST and bank details are forwarded to the provider and NOT
        // persisted here (data minimization — they live only at Razorpay).
        pan: input.pan,
        gst: input.gst,
        beneficiaryName: input.beneficiaryName,
        bankAccountNumber: input.bankAccountNumber,
        bankIfsc: input.bankIfsc,
      });
      const row = await prisma.linkedAccount.update({
        where: { shopId: input.shopId },
        data: {
          providerAccountId: acct.providerAccountId,
          kycStatus: acct.kycStatus,
          payoutsEnabled: acct.payoutsEnabled,
        },
        select: SELECT,
      });
      return { ok: true, account: view(row) };
    } catch (err) {
      // Release the claim so a later retry can re-attempt the provider create.
      await prisma.linkedAccount.updateMany({
        where: { shopId: input.shopId, kycStatus: 'CREATING' },
        data: { kycStatus: 'CREATED' },
      });
      throw err;
    }
  }

  /**
   * Re-poll the provider for every not-yet-payout-enabled account and sync — the
   * scheduled self-heal for a DROPPED or EARLY account.activated webhook (a
   * seller would otherwise be stranded KYC_GATED on a single missed event). When
   * an account flips to payouts-enabled, the transfer sweep's KYC retry then
   * promotes its gated transfers. Per-item isolated; never throws.
   */
  async reconcilePendingKyc(
    batchSize = 50,
  ): Promise<{ scanned: number; activated: number; errors: number }> {
    const provider = getProvider(PROVIDER);
    if (!isOnboardingCapable(provider)) return { scanned: 0, activated: 0, errors: 0 };
    const pending = await prisma.linkedAccount.findMany({
      where: {
        payoutsEnabled: false,
        providerAccountId: { not: null },
        kycStatus: { notIn: ['SUSPENDED'] },
      },
      select: { shopId: true, providerAccountId: true },
      take: batchSize,
    });
    let activated = 0;
    let errors = 0;
    for (const la of pending) {
      try {
        const live = await provider.fetchAccountStatus(la.providerAccountId!);
        await prisma.linkedAccount.updateMany({
          // claim-once on the gate so a concurrent webhook can't be clobbered.
          where: { shopId: la.shopId, payoutsEnabled: false },
          data: { kycStatus: live.kycStatus, payoutsEnabled: live.payoutsEnabled },
        });
        if (live.payoutsEnabled) activated++;
      } catch {
        errors++;
      }
    }
    return { scanned: pending.length, activated, errors };
  }

  /** The shop's linked account as we last knew it (no provider call). */
  async getStatus(shopId: number): Promise<LinkedAccountView | null> {
    const row = await prisma.linkedAccount.findUnique({ where: { shopId }, select: SELECT });
    return row ? view(row) : null;
  }

  /**
   * Re-poll the provider for live KYC and sync — the self-heal for a dropped or
   * early account.* webhook. Returns the (possibly updated) account.
   */
  async refreshStatus(shopId: number): Promise<LinkedAccountView | null> {
    const row = await prisma.linkedAccount.findUnique({
      where: { shopId },
      select: { ...SELECT, updatedAt: true },
    });
    if (!row) return null;
    if (!row.providerAccountId) return view(row);
    // Throttle: a merchant spamming ?refresh=1 must not hammer the provider (and
    // trip the shared circuit breaker for every tenant). Already-activated rows
    // never need a re-poll.
    if (
      row.payoutsEnabled ||
      Date.now() - row.updatedAt.getTime() < REFRESH_MIN_INTERVAL_MS
    ) {
      return view(row);
    }
    const provider = getProvider(PROVIDER);
    if (!isOnboardingCapable(provider)) return view(row);
    const live = await provider.fetchAccountStatus(row.providerAccountId);
    const updated = await prisma.linkedAccount.update({
      where: { shopId },
      data: { kycStatus: live.kycStatus, payoutsEnabled: live.payoutsEnabled },
      select: SELECT,
    });
    return view(updated);
  }
}

export const linkedAccountsService = new LinkedAccountsService();
