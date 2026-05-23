import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';

/// Supported field types. Lives next to the service so controller +
/// frontend can both reference the same set without drift.
export const CUSTOM_FIELD_TYPES = [
  'TEXT',
  'LONG_TEXT',
  'NUMBER',
  'DATE',
  'BOOLEAN',
  'DROPDOWN',
] as const;
export type CustomFieldType = (typeof CUSTOM_FIELD_TYPES)[number];

export interface CustomFieldDefinitionInput {
  name: string;
  type: CustomFieldType;
  options?: string[];
  unitSuffix?: string | null;
  icon?: string | null;
  sectionId?: number | null;
  sortOrder?: number;
}

/// Validate a raw string value against a definition's declared type.
/// Returns either the normalised string we'll persist, or an error
/// message the controller can surface. The store keeps everything as
/// String (one column, one index strategy) — typed parsing happens at
/// read/write boundaries.
export function validateValueForType(
  rawValue: string,
  type: CustomFieldType,
  options: string[] | null,
): { ok: true; value: string } | { ok: false; error: string } {
  const v = rawValue.trim();
  if (v === '') return { ok: true, value: '' };

  switch (type) {
    case 'TEXT':
    case 'LONG_TEXT':
      return { ok: true, value: v };

    case 'NUMBER': {
      // Locale-loose: accept "1,234.5" and "1234.5" alike.
      const cleaned = v.replace(/,/g, '');
      if (!/^-?\d+(\.\d+)?$/.test(cleaned)) {
        return { ok: false, error: 'Value must be a number' };
      }
      return { ok: true, value: cleaned };
    }

    case 'DATE': {
      // Persist as ISO-8601 for ordering. Reject obvious garbage but
      // be forgiving about input formats.
      const parsed = new Date(v);
      if (Number.isNaN(parsed.getTime())) {
        return { ok: false, error: 'Value must be a valid date' };
      }
      return { ok: true, value: parsed.toISOString() };
    }

    case 'BOOLEAN': {
      const normalised = v.toLowerCase();
      if (['true', '1', 'yes', 'y'].includes(normalised)) {
        return { ok: true, value: 'true' };
      }
      if (['false', '0', 'no', 'n'].includes(normalised)) {
        return { ok: true, value: 'false' };
      }
      return { ok: false, error: 'Value must be true or false' };
    }

    case 'DROPDOWN': {
      if (!options || options.length === 0) {
        return { ok: false, error: 'Dropdown has no options defined' };
      }
      if (!options.includes(v)) {
        return { ok: false, error: `Value must be one of: ${options.join(', ')}` };
      }
      return { ok: true, value: v };
    }
  }
}

export interface CustomFieldSectionInput {
  name: string;
  icon?: string | null;
  sortOrder?: number;
}

/// Predefined section + field bundles the user can stamp in one tap.
/// Names are stored exactly as written — if the user already has a
/// matching section, applying a template merges instead of duplicating.
export const PREDEFINED_TEMPLATES: ReadonlyArray<{
  id: string;
  label: string;
  icon: string;
  description: string;
  fields: ReadonlyArray<{
    name: string;
    type: CustomFieldType;
    unitSuffix?: string;
    options?: string[];
    icon?: string;
  }>;
}> = [
  {
    id: 'electronics',
    label: 'Electronics',
    icon: 'memory',
    description: 'Voltage, wattage, warranty info common to electronics',
    fields: [
      { name: 'Warranty period', type: 'NUMBER', unitSuffix: 'months', icon: 'verified' },
      { name: 'Voltage', type: 'NUMBER', unitSuffix: 'V', icon: 'bolt' },
      { name: 'Wattage', type: 'NUMBER', unitSuffix: 'W', icon: 'flash_on' },
      { name: 'Power source', type: 'DROPDOWN', options: ['AC', 'DC', 'Battery', 'USB'], icon: 'power' },
    ],
  },
  {
    id: 'apparel',
    label: 'Apparel',
    icon: 'checkroom',
    description: 'Size, colour, material, gender for clothing & accessories',
    fields: [
      { name: 'Size', type: 'DROPDOWN', options: ['XS', 'S', 'M', 'L', 'XL', 'XXL'], icon: 'straighten' },
      { name: 'Colour', type: 'TEXT', icon: 'palette' },
      { name: 'Material', type: 'TEXT', icon: 'texture' },
      { name: 'Gender', type: 'DROPDOWN', options: ['Men', 'Women', 'Unisex', 'Kids'], icon: 'people' },
    ],
  },
  {
    id: 'logistics',
    label: 'Logistics',
    icon: 'local_shipping',
    description: 'Weight, dimensions, packaging details for shipping',
    fields: [
      { name: 'Weight', type: 'NUMBER', unitSuffix: 'kg', icon: 'scale' },
      { name: 'Length', type: 'NUMBER', unitSuffix: 'cm', icon: 'straighten' },
      { name: 'Width', type: 'NUMBER', unitSuffix: 'cm', icon: 'straighten' },
      { name: 'Height', type: 'NUMBER', unitSuffix: 'cm', icon: 'straighten' },
      { name: 'Fragile', type: 'BOOLEAN', icon: 'warning' },
    ],
  },
  {
    id: 'food',
    label: 'Food & Beverages',
    icon: 'restaurant',
    description: 'Expiry, batch, dietary info for consumables',
    fields: [
      { name: 'Manufacturing date', type: 'DATE', icon: 'factory' },
      { name: 'Expiry date', type: 'DATE', icon: 'event_busy' },
      { name: 'Batch number', type: 'TEXT', icon: 'tag' },
      { name: 'Vegetarian', type: 'BOOLEAN', icon: 'eco' },
      { name: 'Net weight', type: 'NUMBER', unitSuffix: 'g', icon: 'scale' },
    ],
  },
  {
    id: 'warranty',
    label: 'Warranty',
    icon: 'verified_user',
    description: 'Warranty terms, period, claim info',
    fields: [
      { name: 'Warranty period', type: 'NUMBER', unitSuffix: 'months', icon: 'event' },
      { name: 'Warranty type', type: 'DROPDOWN', options: ['Manufacturer', 'Seller', 'Extended', 'No warranty'], icon: 'fact_check' },
      { name: 'Claim procedure', type: 'LONG_TEXT', icon: 'description' },
    ],
  },
];

export class CustomFieldsService {
  // ── Sections ───────────────────────────────────────────────────────

  /// One round-trip pulls the whole tree (sections with their fields,
  /// plus the ungrouped fields). The settings + product form both
  /// render directly off this shape, no client-side joining needed.
  async getTree({ activeOnly }: { activeOnly: boolean }) {
    const where = activeOnly ? { isActive: true } : {};
    const [sections, ungrouped] = await Promise.all([
      prisma.customFieldSection.findMany({
        where,
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
        include: {
          fields: {
            where,
            orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
          },
        },
      }),
      prisma.customFieldDefinition.findMany({
        where: { ...where, sectionId: null },
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      }),
    ]);
    return { sections, ungrouped };
  }

  async listSections({ activeOnly }: { activeOnly: boolean }) {
    return prisma.customFieldSection.findMany({
      where: activeOnly ? { isActive: true } : {},
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  async createSection(data: CustomFieldSectionInput) {
    return prisma.customFieldSection.create({
      data: {
        name: data.name,
        icon: data.icon ?? null,
        sortOrder: data.sortOrder ?? 0,
      },
    });
  }

  async updateSection(
    id: number,
    data: Partial<CustomFieldSectionInput> & { isActive?: boolean },
  ) {
    return prisma.customFieldSection.update({
      where: { id },
      data: {
        ...(data.name !== undefined ? { name: data.name } : {}),
        ...(data.icon !== undefined ? { icon: data.icon } : {}),
        ...(data.sortOrder !== undefined ? { sortOrder: data.sortOrder } : {}),
        ...(data.isActive !== undefined ? { isActive: data.isActive } : {}),
      },
    });
  }

  async softDeleteSection(id: number) {
    return prisma.customFieldSection.update({
      where: { id },
      data: { isActive: false },
    });
  }

  async reorderSections(orderedIds: number[]) {
    await prisma.$transaction(
      orderedIds.map((id, i) =>
        prisma.customFieldSection.update({
          where: { id },
          data: { sortOrder: i },
        }),
      ),
    );
    return this.listSections({ activeOnly: false });
  }

  // ── Templates ──────────────────────────────────────────────────────

  /// Stamps a predefined section + its fields into the shop. If a
  /// section with the same name exists, we reuse it and only create
  /// missing fields underneath. Idempotent enough that tapping the
  /// template twice doesn't pile up duplicates.
  async applyTemplate(templateId: string) {
    const template = PREDEFINED_TEMPLATES.find((t) => t.id === templateId);
    if (!template) return { error: 'Unknown template' };

    let section = await prisma.customFieldSection.findUnique({
      where: { name: template.label },
    });
    if (!section) {
      const maxOrder = await prisma.customFieldSection.aggregate({
        _max: { sortOrder: true },
      });
      section = await prisma.customFieldSection.create({
        data: {
          name: template.label,
          icon: template.icon,
          sortOrder: (maxOrder._max.sortOrder ?? -1) + 1,
        },
      });
    } else if (!section.isActive) {
      section = await prisma.customFieldSection.update({
        where: { id: section.id },
        data: { isActive: true, icon: section.icon ?? template.icon },
      });
    }

    const existing = await prisma.customFieldDefinition.findMany({
      where: { name: { in: template.fields.map((f) => f.name) } },
    });
    const existingByName = new Map(existing.map((d) => [d.name, d]));

    let nextOrder = 0;
    const created: number[] = [];
    for (const f of template.fields) {
      const existingDef = existingByName.get(f.name);
      if (existingDef) {
        // Move into this section if it's currently un-sectioned; never
        // hijack a definition the user has placed somewhere else.
        if (existingDef.sectionId == null) {
          await prisma.customFieldDefinition.update({
            where: { id: existingDef.id },
            data: { sectionId: section.id, isActive: true },
          });
        } else if (!existingDef.isActive) {
          await prisma.customFieldDefinition.update({
            where: { id: existingDef.id },
            data: { isActive: true },
          });
        }
        continue;
      }
      const def = await prisma.customFieldDefinition.create({
        data: {
          name: f.name,
          type: f.type,
          options:
            f.type === 'DROPDOWN' && f.options ? f.options : Prisma.JsonNull,
          unitSuffix: f.type === 'NUMBER' ? f.unitSuffix ?? null : null,
          icon: f.icon ?? null,
          sectionId: section.id,
          sortOrder: nextOrder++,
        },
      });
      created.push(def.id);
    }

    return this.getTree({ activeOnly: false });
  }

  listTemplates() {
    return PREDEFINED_TEMPLATES.map((t) => ({
      id: t.id,
      label: t.label,
      icon: t.icon,
      description: t.description,
      fieldCount: t.fields.length,
    }));
  }

  // ── Definitions ────────────────────────────────────────────────────

  async listDefinitions({ activeOnly }: { activeOnly: boolean }) {
    return prisma.customFieldDefinition.findMany({
      where: activeOnly ? { isActive: true } : {},
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  getDefinitionById(id: number) {
    return prisma.customFieldDefinition.findUnique({ where: { id } });
  }

  async createDefinition(data: CustomFieldDefinitionInput) {
    const created = await prisma.customFieldDefinition.create({
      data: {
        name: data.name,
        type: data.type,
        // Prisma needs Prisma.JsonNull (not bare null) to write SQL
        // NULL into a JSONB column.
        options:
          data.type === 'DROPDOWN' && data.options
            ? data.options
            : Prisma.JsonNull,
        unitSuffix: data.type === 'NUMBER' ? data.unitSuffix ?? null : null,
        icon: data.icon ?? null,
        sectionId: data.sectionId ?? null,
        sortOrder: data.sortOrder ?? 0,
      },
    });
    return created;
  }

  async updateDefinition(
    id: number,
    data: Partial<CustomFieldDefinitionInput> & { isActive?: boolean },
  ) {
    // Only persist the type-shaped extras when type is the matching
    // shape, so a TEXT field doesn't accidentally carry dropdown
    // options from a stale form payload.
    const existing = await prisma.customFieldDefinition.findUnique({
      where: { id },
    });
    if (!existing) return null;

    const nextType = (data.type ?? existing.type) as CustomFieldType;

    const nextOptions =
      nextType === 'DROPDOWN'
        ? data.options ?? (existing.options as unknown as string[] | null)
        : null;

    return prisma.customFieldDefinition.update({
      where: { id },
      data: {
        ...(data.name !== undefined ? { name: data.name } : {}),
        ...(data.type !== undefined ? { type: data.type } : {}),
        ...(data.sortOrder !== undefined ? { sortOrder: data.sortOrder } : {}),
        ...(data.isActive !== undefined ? { isActive: data.isActive } : {}),
        ...(data.icon !== undefined ? { icon: data.icon } : {}),
        ...(data.sectionId !== undefined ? { sectionId: data.sectionId } : {}),
        options: nextOptions === null ? Prisma.JsonNull : nextOptions,
        unitSuffix:
          nextType === 'NUMBER'
            ? data.unitSuffix ?? existing.unitSuffix
            : null,
      },
    });
  }

  /// Soft-delete by default — flip isActive=false so historical values
  /// remain readable. Hard-delete is exposed separately if needed.
  async softDeleteDefinition(id: number) {
    return prisma.customFieldDefinition.update({
      where: { id },
      data: { isActive: false },
    });
  }

  async reorderDefinitions(orderedIds: number[]) {
    await prisma.$transaction(
      orderedIds.map((id, i) =>
        prisma.customFieldDefinition.update({
          where: { id },
          data: { sortOrder: i },
        }),
      ),
    );
    return this.listDefinitions({ activeOnly: false });
  }

  // ── Per-product values ─────────────────────────────────────────────

  async listValuesForProduct(productId: number) {
    return prisma.productCustomFieldValue.findMany({
      where: { productId },
      include: { definition: true },
      orderBy: [
        { definition: { sortOrder: 'asc' } },
        { definition: { name: 'asc' } },
      ],
    });
  }

  /// Upsert a single (productId, definitionId) row. Empty/whitespace
  /// value deletes the row instead of storing a blank — keeps the
  /// table clean and the "no value" detail-row rendering simple.
  async setValue(productId: number, definitionId: number, rawValue: string) {
    const definition = await prisma.customFieldDefinition.findUnique({
      where: { id: definitionId },
    });
    if (!definition) {
      return { error: 'Definition not found' };
    }

    const opts = Array.isArray(definition.options)
      ? (definition.options as string[])
      : null;
    const validated = validateValueForType(
      rawValue,
      definition.type as CustomFieldType,
      opts,
    );
    if (!validated.ok) return { error: validated.error };

    if (validated.value === '') {
      await prisma.productCustomFieldValue.deleteMany({
        where: { productId, definitionId },
      });
      return { deleted: true };
    }

    return prisma.productCustomFieldValue.upsert({
      where: { productId_definitionId: { productId, definitionId } },
      create: { productId, definitionId, value: validated.value },
      update: { value: validated.value },
      include: { definition: true },
    });
  }

  /// Bulk-replace a product's values in one transaction. Empty values
  /// clear the row. Used by Add/Edit Product save path.
  async bulkSetValues(
    productId: number,
    entries: { definitionId: number; value: string }[],
  ) {
    const definitionIds = entries.map((e) => e.definitionId);
    const definitions = await prisma.customFieldDefinition.findMany({
      where: { id: { in: definitionIds } },
    });
    const byId = new Map(definitions.map((d) => [d.id, d]));

    // Validate everything before we open the transaction so a single
    // bad row doesn't leave half the bulk applied.
    const ops: { definitionId: number; value: string }[] = [];
    for (const e of entries) {
      const def = byId.get(e.definitionId);
      if (!def) {
        return { error: `Unknown definition ${e.definitionId}` };
      }
      const opts = Array.isArray(def.options)
        ? (def.options as string[])
        : null;
      const validated = validateValueForType(
        e.value,
        def.type as CustomFieldType,
        opts,
      );
      if (!validated.ok) {
        return { error: `${def.name}: ${validated.error}` };
      }
      ops.push({ definitionId: e.definitionId, value: validated.value });
    }

    await prisma.$transaction(
      ops.map((op) =>
        op.value === ''
          ? prisma.productCustomFieldValue.deleteMany({
              where: { productId, definitionId: op.definitionId },
            })
          : prisma.productCustomFieldValue.upsert({
              where: {
                productId_definitionId: {
                  productId,
                  definitionId: op.definitionId,
                },
              },
              create: {
                productId,
                definitionId: op.definitionId,
                value: op.value,
              },
              update: { value: op.value },
            }),
      ),
    );

    return this.listValuesForProduct(productId);
  }

  async deleteValue(productId: number, definitionId: number) {
    await prisma.productCustomFieldValue.deleteMany({
      where: { productId, definitionId },
    });
  }
}

export const customFieldsService = new CustomFieldsService();
