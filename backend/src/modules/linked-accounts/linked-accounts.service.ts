import prisma from '../../infra/db/prisma.js';
import { getProvider } from '../payment-gateway/providers/registry.js';
import {
  isOnboardingCapable,
  type CreateLinkedAccountParams,
} from '../payment-gateway/ports/payment-provider.port.js';

const PROVIDER = 'RAZORPAY';
const REFRESH_MIN_INTERVAL_MS = 30_000;

export interface ConnectAccountDetails {
  accountId: string;
  kycStatus: string;
  payoutsEnabled: boolean;
  email: string | null;
  legalBusinessName: string | null;
  contactName: string | null;
  businessType: string | null;
}

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
  async startOnboarding(
    input: Omit<CreateLinkedAccountParams, 'shopId'> & { shopId: number },
  ): Promise<{ ok: true; account: LinkedAccountView } | { error: 'PROVIDER_UNAVAILABLE' }> {
    const provider = getProvider(PROVIDER);
    if (!isOnboardingCapable(provider)) return { error: 'PROVIDER_UNAVAILABLE' };

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
    if (existing?.providerAccountId) return { ok: true, account: view(existing) };

    const claim = await prisma.linkedAccount.updateMany({
      where: { shopId: input.shopId, providerAccountId: null, kycStatus: { not: 'CREATING' } },
      data: { kycStatus: 'CREATING' },
    });
    if (claim.count !== 1) {
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
      await prisma.linkedAccount.updateMany({
        where: { shopId: input.shopId, kycStatus: 'CREATING' },
        data: { kycStatus: 'CREATED' },
      });
      throw err;
    }
  }

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

  async verifyConnect(
    accountId: string,
  ): Promise<{ ok: true; details: ConnectAccountDetails } | { error: 'PROVIDER_UNAVAILABLE' | 'NOT_FOUND' }> {
    const provider = getProvider(PROVIDER);
    if (!isOnboardingCapable(provider)) return { error: 'PROVIDER_UNAVAILABLE' };
    try {
      return { ok: true, details: await provider.fetchAccount(accountId) };
    } catch {
      return { error: 'NOT_FOUND' };
    }
  }

  async confirmConnect(
    shopId: number,
    accountId: string,
  ): Promise<
    { ok: true; account: LinkedAccountView } | { error: 'PROVIDER_UNAVAILABLE' | 'NOT_FOUND' | 'ALREADY_LINKED' }
  > {
    const provider = getProvider(PROVIDER);
    if (!isOnboardingCapable(provider)) return { error: 'PROVIDER_UNAVAILABLE' };

    const existing = await prisma.linkedAccount.findUnique({
      where: { shopId },
      select: { providerAccountId: true },
    });
    if (existing?.providerAccountId && existing.providerAccountId !== accountId) {
      return { error: 'ALREADY_LINKED' };
    }

    let acct: ConnectAccountDetails;
    try {
      acct = await provider.fetchAccount(accountId);
    } catch {
      return { error: 'NOT_FOUND' };
    }

    const data = {
      providerAccountId: acct.accountId,
      kycStatus: acct.kycStatus,
      payoutsEnabled: acct.payoutsEnabled,
      email: acct.email,
      contactName: acct.contactName,
      businessType: acct.businessType,
    };
    const row = await prisma.linkedAccount.upsert({
      where: { shopId },
      create: { shopId, provider: PROVIDER, ...data },
      update: data,
      select: SELECT,
    });
    return { ok: true, account: view(row) };
  }

  async getStatus(shopId: number): Promise<LinkedAccountView | null> {
    const row = await prisma.linkedAccount.findUnique({ where: { shopId }, select: SELECT });
    return row ? view(row) : null;
  }

  async refreshStatus(shopId: number): Promise<LinkedAccountView | null> {
    const row = await prisma.linkedAccount.findUnique({
      where: { shopId },
      select: { ...SELECT, updatedAt: true },
    });
    if (!row) return null;
    if (!row.providerAccountId) return view(row);
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
