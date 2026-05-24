import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';

const publicSelect = {
  id: true,
  label: true,
  fullName: true,
  phone: true,
  line1: true,
  line2: true,
  city: true,
  state: true,
  pincode: true,
  landmark: true,
  isDefault: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.UserAddressSelect;

export interface AddressInput {
  label?: string | null;
  fullName: string;
  phone: string;
  line1: string;
  line2?: string | null;
  city: string;
  state: string;
  pincode: string;
  landmark?: string | null;
  isDefault?: boolean;
}

export class AddressesService {
  async list(userId: number) {
    return prisma.userAddress.findMany({
      where: { userId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
      select: publicSelect,
    });
  }

  async getDefault(userId: number) {
    return prisma.userAddress.findFirst({
      where: { userId, isDefault: true },
      select: publicSelect,
    });
  }

  /// Creating an address may also set it as default. We wrap in a
  /// transaction so the "unset previous default" + "insert new
  /// default" steps land atomically — the partial unique index
  /// `user_addresses_one_default_per_user` would otherwise reject
  /// the second write in race conditions.
  async create(userId: number, input: AddressInput) {
    const wantsDefault = input.isDefault ?? false;
    // First address for a user is implicitly the default — no point
    // in forcing the customer to flip a switch on their only address.
    const existing = await prisma.userAddress.count({ where: { userId } });
    const isDefault = wantsDefault || existing === 0;

    return prisma.$transaction(async (tx) => {
      if (isDefault) {
        await tx.userAddress.updateMany({
          where: { userId, isDefault: true },
          data: { isDefault: false },
        });
      }
      return tx.userAddress.create({
        data: {
          userId,
          label: input.label ?? null,
          fullName: input.fullName,
          phone: input.phone,
          line1: input.line1,
          line2: input.line2 ?? null,
          city: input.city,
          state: input.state,
          pincode: input.pincode,
          landmark: input.landmark ?? null,
          isDefault,
        },
        select: publicSelect,
      });
    });
  }

  async update(
    userId: number,
    id: number,
    input: Partial<AddressInput>,
  ): Promise<{ ok: true; address: Prisma.UserAddressGetPayload<{ select: typeof publicSelect }> } | { ok: false; reason: 'not_found' }> {
    const existing = await prisma.userAddress.findFirst({
      where: { id, userId },
      select: { id: true, isDefault: true },
    });
    if (!existing) return { ok: false, reason: 'not_found' };

    return prisma.$transaction(async (tx) => {
      // Promoting a non-default address to default → demote the
      // current one first so the unique index doesn't reject the
      // write.
      if (input.isDefault === true && !existing.isDefault) {
        await tx.userAddress.updateMany({
          where: { userId, isDefault: true },
          data: { isDefault: false },
        });
      }
      const address = await tx.userAddress.update({
        where: { id },
        data: {
          label: input.label === undefined ? undefined : input.label,
          fullName: input.fullName ?? undefined,
          phone: input.phone ?? undefined,
          line1: input.line1 ?? undefined,
          line2: input.line2 === undefined ? undefined : input.line2,
          city: input.city ?? undefined,
          state: input.state ?? undefined,
          pincode: input.pincode ?? undefined,
          landmark: input.landmark === undefined ? undefined : input.landmark,
          isDefault: input.isDefault === undefined ? undefined : input.isDefault,
        },
        select: publicSelect,
      });
      return { ok: true as const, address };
    });
  }

  async delete(userId: number, id: number): Promise<'ok' | 'not_found'> {
    const result = await prisma.userAddress.deleteMany({
      where: { id, userId },
    });
    return result.count > 0 ? 'ok' : 'not_found';
  }

  /// Promote one address to default. Idempotent — already-default
  /// addresses stay default.
  async setDefault(userId: number, id: number): Promise<'ok' | 'not_found'> {
    const target = await prisma.userAddress.findFirst({
      where: { id, userId },
      select: { id: true },
    });
    if (!target) return 'not_found';
    await prisma.$transaction([
      prisma.userAddress.updateMany({
        where: { userId, isDefault: true },
        data: { isDefault: false },
      }),
      prisma.userAddress.update({
        where: { id },
        data: { isDefault: true },
      }),
    ]);
    return 'ok';
  }
}

export const addressesService = new AddressesService();
