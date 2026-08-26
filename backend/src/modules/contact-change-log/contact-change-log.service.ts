import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';

export type ContactEntityType = 'PARTY' | 'VENDOR';

const TRACKED_FIELDS = [
  'name',
  'contactName',
  'phone',
  'email',
  'address',
  'city',
  'state',
  'stateCode',
  'pinCode',
  'panNumber',
  'gstin',
  'isActive',
] as const;

type TrackedField = (typeof TRACKED_FIELDS)[number];

type Snapshot = Partial<Record<TrackedField, string | null | boolean>>;

function normalize(v: string | null | boolean | undefined): string | null {
  if (v === undefined || v === null) return null;
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  const trimmed = v.trim();
  return trimmed.length === 0 ? null : trimmed;
}

export class ContactChangeLogService {
  async recordChanges(args: {
    entityType: ContactEntityType;
    entityId: number;
    before: Snapshot;
    after: Snapshot;
    changedById: number | null;
    tx?: Prisma.TransactionClient;
  }): Promise<void> {
    const { entityType, entityId, before, after, changedById, tx } = args;
    const rows: Prisma.ContactChangeLogCreateManyInput[] = [];
    for (const field of TRACKED_FIELDS) {
      if (!(field in after)) continue;
      const oldNorm = normalize(before[field]);
      const newNorm = normalize(after[field]);
      if (oldNorm === newNorm) continue;
      rows.push({
        entityType,
        entityId,
        field,
        oldValue: oldNorm,
        newValue: newNorm,
        changedById,
      });
    }
    if (rows.length === 0) return;
    const client = tx ?? prisma;
    await client.contactChangeLog.createMany({ data: rows });
  }

  async listForEntity(args: {
    shopId: number;
    entityType: ContactEntityType;
    entityId: number;
    page: number;
    limit: number;
    skip: number;
  }) {
    const owns =
      args.entityType === 'PARTY'
        ? await prisma.party.findFirst({
            where: { id: args.entityId, shopId: args.shopId },
            select: { id: true },
          })
        : await prisma.vendor.findFirst({
            where: { id: args.entityId, shopId: args.shopId },
            select: { id: true },
          });
    if (!owns) return { rows: [], total: 0 };

    const where = { entityType: args.entityType, entityId: args.entityId };
    const [rows, total] = await Promise.all([
      prisma.contactChangeLog.findMany({
        where,
        orderBy: { changedAt: 'desc' },
        skip: args.skip,
        take: args.limit,
        select: {
          id: true,
          field: true,
          oldValue: true,
          newValue: true,
          changedAt: true,
          changedBy: { select: { id: true, name: true, email: true } },
        },
      }),
      prisma.contactChangeLog.count({ where }),
    ]);
    return { rows, total };
  }
}

export const contactChangeLogService = new ContactChangeLogService();
