import { Prisma, type TaxRateSource, type ProductPricingMode } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { ledgerService } from '../ledger/ledger.service.js';
import { embeddingService } from '../search/embedding.service.js';
import { hsnService } from '../hsn/hsn.service.js';
import { HttpError } from '../../shared/http/errorHandler.js';

type RateBearing = {
  hsnCode?: string | null;
  taxPercent?: number;
  cessRate?: number;
  sellingPrice?: number;
  taxSource?: TaxRateSource;
  hsnRevision?: string | null;
};

async function applyHsnRates(
  shopId: number,
  data: RateBearing & { variants?: RateBearing[] },
  fallbackPrice?: number,
): Promise<void> {
  const targets = [data, ...(data.variants ?? [])];
  const codes = targets
    .map((t) => t.hsnCode)
    .filter((c): c is string => typeof c === 'string' && c.trim().length > 0);
  if (codes.length === 0) return;

  for (const target of targets) {
    if (!target.hsnCode?.trim()) continue;
    const outcome = await hsnService.resolveOutcome({
      code: target.hsnCode,
      shopId,
      price: target.sellingPrice ?? data.sellingPrice ?? fallbackPrice,
    });

    if (outcome.status === 'UNKNOWN') continue;

    if (outcome.status === 'UNRATED') {
      if (target.taxPercent === undefined) {
        throw new HttpError(
          422,
          'HSN_RATE_UNRESOLVED',
          outcome.note
            ? `HSN ${outcome.code} has no single GST rate — ${outcome.note} ` +
              'Set the rate that applies to this product.'
            : `HSN ${outcome.code} has no GST rate on file, so the rate can't be ` +
              'derived. Set the rate that applies to this product.',
          {
            hsnCode: target.hsnCode,
            resolvedAt: outcome.code,
            reason: outcome.reason,
            note: outcome.note,
          },
        );
      }
      target.taxSource = 'MANUAL';
      target.hsnRevision = null;
      continue;
    }

    const hit = outcome.rate;

    if (target.taxPercent === undefined) {
      target.taxPercent = hit.gstRate;
      target.taxSource = hit.source as TaxRateSource;
      target.hsnRevision = hit.revision;
    } else {
      const agrees = Math.abs(target.taxPercent - hit.gstRate) < 0.005;
      target.taxSource = agrees ? (hit.source as TaxRateSource) : 'MANUAL';
      target.hsnRevision = agrees ? hit.revision : null;
    }
    if (target.cessRate === undefined && hit.cessRate > 0) target.cessRate = hit.cessRate;
  }
}

function enforceNoGstMode(
  data: RateBearing & { pricingMode?: ProductPricingMode; variants?: RateBearing[] },
): boolean {
  if (data.pricingMode !== 'NO_GST') return false;
  if (data.taxPercent !== undefined && data.taxPercent !== 0) {
    throw new HttpError(
      422,
      'NO_GST_WITH_TAX_PERCENT',
      'A no-GST product cannot have a non-zero tax percent — clear the rate or change the pricing mode.',
    );
  }
  data.taxPercent = 0;
  for (const v of data.variants ?? []) {
    if (v.taxPercent !== undefined && v.taxPercent !== 0) {
      throw new HttpError(
        422,
        'NO_GST_WITH_TAX_PERCENT',
        'A no-GST product cannot have a variant with a non-zero tax percent — clear the rate or change the pricing mode.',
      );
    }
    v.taxPercent = 0;
  }
  return true;
}

const DANGEROUS_TAGS =
  /<\s*\/?\s*(script|iframe|object|embed|style|link|meta|base|form|svg|math|template|noscript|frame|frameset|applet)\b[^>]*>/gi;
const EVENT_HANDLERS = /\son\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi;
const DANGEROUS_URIS =
  /(?:j\s*a\s*v\s*a\s*s\s*c\s*r\s*i\s*p\s*t|v\s*b\s*s\s*c\s*r\s*i\s*p\s*t|d\s*a\s*t\s*a)\s*(?:&#x?[0-9a-f]+;?|\s)*:/gi;
const HTML_COMMENTS = /<!--[\s\S]*?-->/g;
function decodeNumericEntities(input: string): string {
  return input
    .replace(/&#x([0-9a-f]+);?/gi, (_m, hex) => {
      const code = parseInt(hex, 16);
      return Number.isFinite(code) ? String.fromCodePoint(code) : _m;
    })
    .replace(/&#(\d+);?/g, (_m, dec) => {
      const code = parseInt(dec, 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : _m;
    });
}

function scrubMarkdown(input: string): string {
  let out = input;
  for (let i = 0; i < 5; i++) {
    const next = decodeNumericEntities(out)
      .replace(HTML_COMMENTS, '')
      .replace(DANGEROUS_TAGS, '')
      .replace(EVENT_HANDLERS, '')
      .replace(DANGEROUS_URIS, '');
    if (next === out) break;
    out = next;
  }
  return out;
}

function sanitizeContentBlocks(blocks: unknown): unknown {
  if (!Array.isArray(blocks)) return blocks;
  return blocks.map((b) => {
    if (b && typeof b === 'object' && (b as { kind?: string }).kind === 'TEXT') {
      const cur = b as { kind: 'TEXT'; markdown: string };
      return {
        ...cur,
        markdown: scrubMarkdown(cur.markdown),
      };
    }
    return b;
  });
}

const productSelect = {
  id: true,
  name: true,
  description: true,
  sku: true,
  barcode: true,
  hsnCode: true,
  countryOfOrigin: true,
  mrp: true,
  sellingPrice: true,
  purchasePrice: true,
  taxPercent: true,
  cessRate: true,
  pricingMode: true,
  taxSource: true,
  hsnRevision: true,
  stockQuantity: true,
  lowStockThreshold: true,
  unit: true,
  categoryId: true,
  shopId: true,
  isActive: true,
  isPublished: true,
  ratingAvg: true,
  ratingCount: true,
  tags: true,
  highlights: true,
  specs: true,
  offers: true,
  totalSold: true,
  brand: true,
  soldLast30d: true,
  systemTags: true,
  contentBlocks: true,
  variantAxes: true,
  variants: {
    orderBy: { sortOrder: 'asc' as const },
    select: {
      id: true,
      sku: true,
      barcode: true,
      attributes: true,
      mrp: true,
      sellingPrice: true,
      purchasePrice: true,
      hsnCode: true,
      taxPercent: true,
      stockQuantity: true,
      imageUrls: true,
      isDefault: true,
      isActive: true,
      sortOrder: true,
    },
  },
  createdAt: true,
  updatedAt: true,
  category: true,
  images: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductSelect;

export class ProductsService {
  async createProduct(
    data: {
      name: string;
      description?: string;
      sku: string;
      barcode?: string;
      hsnCode?: string;
      countryOfOrigin?: string;
      brand?: string;
      mrp: number;
      sellingPrice: number;
      purchasePrice: number;
      taxPercent?: number;
      cessRate?: number;
      pricingMode?: ProductPricingMode;
      taxSource?: TaxRateSource;
      hsnRevision?: string | null;
      stockQuantity?: number;
      lowStockThreshold?: number;
      unit?: string;
      categoryId?: number;
      imageUrls?: string[];
      tags?: string[];
      highlights?: string[];
      specs?: unknown;
      offers?: unknown;
      contentBlocks?: unknown;
      variantAxes?: unknown;
      variants?: Array<{
        sku: string;
        barcode?: string | null;
        attributes: Record<string, string>;
        mrp: number;
        sellingPrice: number;
        purchasePrice: number;
        hsnCode?: string | null;
        taxPercent?: number;
        stockQuantity?: number;
        imageUrls?: string[];
        isActive?: boolean;
        sortOrder?: number;
      }>;
    },
    options: { createdById?: number; shopId?: number } = {},
  ) {
    if (!options.shopId) {
      throw new Error('createProduct requires options.shopId');
    }
    const shopId = options.shopId;
    if (!enforceNoGstMode(data)) {
      await applyHsnRates(shopId, data);
    }

    const {
      imageUrls,
      stockQuantity,
      specs,
      offers,
      contentBlocks,
      variantAxes,
      variants,
      ...rest
    } = data;

    const fundedTotal = stockQuantity && stockQuantity > 0 ? stockQuantity : 0;
    const needsOpening = stockQuantity != null && stockQuantity > 0;

    const productId = await prisma.$transaction(async (tx) => {
      const createData: Prisma.ProductUncheckedCreateInput = {
        ...rest,
          specs: specs === undefined ? undefined : (specs as Prisma.InputJsonValue),
          offers: offers === undefined ? undefined : (offers as Prisma.InputJsonValue),
          contentBlocks: contentBlocks === undefined
            ? undefined
            : (sanitizeContentBlocks(contentBlocks) as Prisma.InputJsonValue),
          variantAxes: variantAxes === undefined
            ? undefined
            : (variantAxes as Prisma.InputJsonValue),
          shopId,
          isPublished: !needsOpening,
          stockQuantity: 0,
          images: imageUrls?.length
            ? { create: imageUrls.map((url, i) => ({ url, sortOrder: i })) }
            : undefined,
          variants: {
            create: (variants && variants.length > 0)
              ? variants.map((v, i) => ({
                  sku: v.sku,
                  barcode: v.barcode ?? null,
                  attributes: v.attributes as Prisma.InputJsonValue,
                  mrp: v.mrp,
                  sellingPrice: v.sellingPrice,
                  purchasePrice: v.purchasePrice,
                  hsnCode: v.hsnCode ?? null,
                  ...(v.taxPercent !== undefined && { taxPercent: v.taxPercent }),
                  stockQuantity: Math.min(v.stockQuantity ?? 0, fundedTotal),
                  imageUrls: v.imageUrls ?? [],
                  isActive: v.isActive ?? true,
                  sortOrder: v.sortOrder ?? i,
                  isDefault: i === 0,
                }))
              : [{
                  sku: `${data.sku}-DEFAULT`,
                  attributes: {},
                  mrp: data.mrp,
                  sellingPrice: data.sellingPrice,
                  purchasePrice: data.purchasePrice,
                  stockQuantity: 0,
                  isDefault: true,
                }],
          },
      };
      const created = await tx.product.create({
        data: createData,
        select: { id: true },
      });

      if (needsOpening) {
        const result = await ledgerService.post(
          {
            shopId,
            direction: 'IN',
            reasonCode: 'OPENING',
            sourceType: 'OPENING',
            sourceId: created.id,
            lines: [
              {
                productId: created.id,
                quantity: stockQuantity!,
                unitPrice: data.purchasePrice,
              },
            ],
            createdById: options.createdById,
            note: 'Opening balance on product create',
          },
          tx,
        );

        if ('error' in result) {
          throw new Error(`Failed to post opening balance: ${result.error}`);
        }

        await tx.productVariant.updateMany({
          where: { productId: created.id, isDefault: true },
          data: { stockQuantity: stockQuantity! },
        });

        await tx.product.update({
          where: { id: created.id },
          data: { isPublished: true },
        });
      }

      return created.id;
    });

    void embeddingService.reembedProduct(productId);

    return prisma.product.findUniqueOrThrow({
      where: { id: productId },
      select: productSelect,
    });
  }

  async posSearch(shopId: number, term: string, limit = 15) {
    const t = term.trim();
    if (!t) return [];
    const rows = await prisma.product.findMany({
      where: {
        shopId,
        isActive: true,
        OR: [
          { name: { contains: t, mode: 'insensitive' } },
          { sku: { contains: t, mode: 'insensitive' } },
          { barcode: { contains: t, mode: 'insensitive' } },
        ],
      },
      orderBy: { name: 'asc' },
      take: Math.min(Math.max(limit, 1), 30),
      select: {
        id: true,
        name: true,
        sku: true,
        sellingPrice: true,
        mrp: true,
        stockQuantity: true,
        images: { orderBy: { sortOrder: 'asc' }, take: 1, select: { url: true } },
      },
    });
    return rows.map((p) => ({
      id: p.id,
      name: p.name,
      sku: p.sku,
      sellingPrice: Number(p.sellingPrice),
      mrp: Number(p.mrp),
      stock: Number(p.stockQuantity),
      imageUrl: p.images[0]?.url ?? null,
    }));
  }

  static readonly catalogueSelect = {
    id: true,
    name: true,
    sku: true,
    barcode: true,
    hsnCode: true,
    unit: true,
    mrp: true,
    sellingPrice: true,
    purchasePrice: true,
    taxPercent: true,
    cessRate: true,
    taxSource: true,
    stockQuantity: true,
    lowStockThreshold: true,
    categoryId: true,
    isActive: true,
    createdAt: true,
    updatedAt: true,
  } as const;

  async listCatalogue(options: { shopId: number; limit: number }) {
    const where = { shopId: options.shopId, isActive: true };

    const [total, rows] = await Promise.all([
      prisma.product.count({ where }),
      prisma.product.findMany({
        where,
        orderBy: { name: 'asc' },
        take: options.limit,
        select: ProductsService.catalogueSelect,
      }),
    ]);

    return { products: rows, total, truncated: total > options.limit };
  }

  async listProducts(options: {
    shopId: number;
    activeOnly: boolean;
    lowStock: boolean;
    outOfStock: boolean;
    categoryId?: number;
    search: string;
    sortBy: string;
    sortOrder: 'asc' | 'desc';
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = { shopId: options.shopId };

    if (options.activeOnly) where.isActive = true;
    if (options.categoryId) where.categoryId = options.categoryId;
    if (options.search) {
      where.OR = [
        { name: { contains: options.search, mode: 'insensitive' } },
        { sku: { contains: options.search, mode: 'insensitive' } },
        { barcode: { contains: options.search, mode: 'insensitive' } },
      ];
    }

    if (options.outOfStock) {
      where.isActive = true;
      where.stockQuantity = 0;

      const orderBy = { [options.sortBy]: options.sortOrder } as Record<
        string,
        'asc' | 'desc'
      >;
      const [products, total] = await Promise.all([
        prisma.product.findMany({
          where,
          orderBy,
          skip: options.skip,
          take: options.limit,
          select: productSelect,
        }),
        prisma.product.count({ where }),
      ]);
      const enriched = await this._enrichWithLastActivity(products);
      return { products: enriched, total };
    }

    if (options.lowStock) {
      const SORT_COLUMN: Record<string, string> = {
        updatedAt: 'updated_at',
        createdAt: 'created_at',
        name: 'name',
        sellingPrice: 'selling_price',
      };
      const sortColumn = SORT_COLUMN[options.sortBy] ?? 'updated_at';
      const orderByRaw = Prisma.raw(
        `ORDER BY ${sortColumn} ${options.sortOrder === 'asc' ? 'ASC' : 'DESC'}, id ASC`,
      );
      const categoryClause = options.categoryId
        ? Prisma.sql`AND category_id = ${options.categoryId}`
        : Prisma.empty;
      const searchClause = options.search
        ? Prisma.sql`AND (
            name ILIKE ${'%' + options.search + '%'}
            OR sku ILIKE ${'%' + options.search + '%'}
            OR barcode ILIKE ${'%' + options.search + '%'}
          )`
        : Prisma.empty;

      const [countRow, pageRows] = await Promise.all([
        prisma.$queryRaw<{ count: bigint }[]>`
          SELECT COUNT(*)::bigint AS count FROM products
           WHERE shop_id = ${options.shopId}
             AND is_active = true
             AND stock_quantity > 0
             AND stock_quantity <= low_stock_threshold
             ${categoryClause}
             ${searchClause}
        `,
        prisma.$queryRaw<{ id: number }[]>`
          SELECT id FROM products
           WHERE shop_id = ${options.shopId}
             AND is_active = true
             AND stock_quantity > 0
             AND stock_quantity <= low_stock_threshold
             ${categoryClause}
             ${searchClause}
           ${orderByRaw}
           LIMIT ${options.limit} OFFSET ${options.skip}
        `,
      ]);

      const total = Number(countRow[0]?.count ?? 0);
      const pageIds = pageRows.map((r) => r.id);
      if (pageIds.length === 0) return { products: [], total };

      const hydrated = await prisma.product.findMany({
        where: { id: { in: pageIds } },
        select: productSelect,
      });
      const byId = new Map(hydrated.map((p) => [p.id, p]));
      const products = pageIds
        .map((pid) => byId.get(pid))
        .filter((p): p is NonNullable<typeof p> => p != null);

      const enriched = await this._enrichWithLastActivity(products);
      return { products: enriched, total };
    }

    const orderBy = { [options.sortBy]: options.sortOrder } as Record<string, 'asc' | 'desc'>;

    const [products, total] = await Promise.all([
      prisma.product.findMany({
        where,
        orderBy,
        skip: options.skip,
        take: options.limit,
        select: productSelect,
      }),
      prisma.product.count({ where }),
    ]);

    const enriched = await this._enrichWithLastActivity(products);
    return { products: enriched, total };
  }

  private async _enrichWithLastActivity<T extends { id: number }>(
    products: T[],
  ): Promise<Array<T & {
    lastStockInAt: Date | null;
    lastStockOutAt: Date | null;
    lastVendor: { id: number; name: string } | null;
  }>> {
    if (products.length === 0) {
      return products.map((p) => ({
        ...p,
        lastStockInAt: null,
        lastStockOutAt: null,
        lastVendor: null,
      }));
    }

    const ids = products.map((p) => p.id);
    const rows = await prisma.$queryRaw<
      Array<{
        product_id: number;
        type: string;
        vendor_id: number | null;
        vendor_name: string | null;
        created_at: Date;
      }>
    >`
      WITH ranked AS (
        SELECT
          st.product_id,
          st.type,
          st.vendor_id,
          st.created_at,
          v.name AS vendor_name,
          ROW_NUMBER() OVER (PARTITION BY st.product_id, st.type ORDER BY st.created_at DESC) AS rn
        FROM stock_transactions st
        LEFT JOIN vendors v ON v.id = st.vendor_id
        WHERE st.product_id = ANY(${ids}::int[])
          AND st.type IN ('STOCK_IN','STOCK_OUT')
      )
      SELECT product_id, type, vendor_id, vendor_name, created_at
      FROM ranked
      WHERE rn = 1
    `;

    const byProduct = new Map<
      number,
      {
        lastIn?: { vendorId: number | null; vendorName: string | null; at: Date };
        lastOut?: { at: Date };
      }
    >();
    for (const r of rows) {
      const bucket = byProduct.get(r.product_id) ?? {};
      if (r.type === 'STOCK_IN') {
        bucket.lastIn = {
          vendorId: r.vendor_id,
          vendorName: r.vendor_name,
          at: r.created_at,
        };
      } else if (r.type === 'STOCK_OUT') {
        bucket.lastOut = { at: r.created_at };
      }
      byProduct.set(r.product_id, bucket);
    }

    return products.map((p) => {
      const b = byProduct.get(p.id);
      const lastIn = b?.lastIn;
      const lastOut = b?.lastOut;
      const lastVendor =
        lastIn && lastIn.vendorId != null && lastIn.vendorName != null
          ? { id: lastIn.vendorId, name: lastIn.vendorName }
          : null;
      return {
        ...p,
        lastStockInAt: lastIn?.at ?? null,
        lastStockOutAt: lastOut?.at ?? null,
        lastVendor,
      };
    });
  }

  lookupProduct(shopId: number, code: string, includeInactive = false) {
    return prisma.product.findFirst({
      where: {
        shopId,
        ...(includeInactive ? {} : { isActive: true }),
        OR: [{ barcode: code }, { sku: code }],
      },
      select: productSelect,
    });
  }

  getProductById(shopId: number, id: number) {
    return prisma.product.findFirst({
      where: { id, shopId },
      include: {
        category: true,
        images: { orderBy: { sortOrder: 'asc' } },
        variants: {
          orderBy: { sortOrder: 'asc' },
          select: {
            id: true,
            sku: true,
            barcode: true,
            attributes: true,
            mrp: true,
            sellingPrice: true,
            purchasePrice: true,
            hsnCode: true,
            taxPercent: true,
            stockQuantity: true,
            imageUrls: true,
            isDefault: true,
            isActive: true,
            sortOrder: true,
          },
        },
        stockTransactions: {
          orderBy: { createdAt: 'desc' },
          take: 30,
          include: { vendor: { select: { id: true, name: true } } },
        },
      },
    });
  }

  async updateProduct(
    shopId: number,
    id: number,
    data: {
      name?: string;
      description?: string | null;
      sku?: string;
      barcode?: string | null;
      hsnCode?: string | null;
      countryOfOrigin?: string | null;
      brand?: string | null;
      mrp?: number;
      sellingPrice?: number;
      purchasePrice?: number;
      taxPercent?: number;
      cessRate?: number;
      pricingMode?: ProductPricingMode;
      taxSource?: TaxRateSource;
      hsnRevision?: string | null;
      lowStockThreshold?: number;
      unit?: string;
      categoryId?: number | null;
      isActive?: boolean;
      isPublished?: boolean;
      tags?: string[];
      highlights?: string[];
      specs?: unknown | null;
      offers?: unknown | null;
      contentBlocks?: unknown | null;
      variantAxes?: unknown | null;
      variants?: Array<{
        id?: number;
        sku: string;
        barcode?: string | null;
        attributes: Record<string, string>;
        mrp: number;
        sellingPrice: number;
        purchasePrice: number;
        hsnCode?: string | null;
        taxPercent?: number;
        stockQuantity?: number;
        imageUrls?: string[];
        isActive?: boolean;
        sortOrder?: number;
      }>;
    },
  ) {
    if (!enforceNoGstMode(data)) {
      if (data.hsnCode?.trim()) {
        const priced =
          data.sellingPrice === undefined
            ? await prisma.product.findFirst({
                where: { id, shopId },
                select: { sellingPrice: true },
              })
            : null;
        await applyHsnRates(shopId, data, priced ? Number(priced.sellingPrice) : undefined);
      } else {
        await applyHsnRates(shopId, data);
      }
    }

    const { specs, offers, contentBlocks, variantAxes, variants, ...rest } = data;

    if (data.mrp !== undefined || data.sellingPrice !== undefined) {
      const current = await prisma.product.findFirst({
        where: { id, shopId },
        select: { mrp: true, sellingPrice: true },
      });
      if (!current) return null;
      const effectiveMrp = new Prisma.Decimal(data.mrp ?? current.mrp);
      const effectiveSelling = new Prisma.Decimal(
        data.sellingPrice ?? current.sellingPrice,
      );
      if (effectiveSelling.greaterThan(effectiveMrp)) {
        throw new HttpError(
          400,
          'SELLING_ABOVE_MRP',
          'Selling price cannot exceed MRP.',
        );
      }
    }

    if (variants !== undefined) {
      for (const v of variants) {
        if (new Prisma.Decimal(v.sellingPrice).greaterThan(new Prisma.Decimal(v.mrp))) {
          throw new HttpError(
            400,
            'SELLING_ABOVE_MRP',
            'Variant selling price cannot exceed its MRP.',
          );
        }
      }
    }

    const result = await prisma.product.updateMany({
      where: { id, shopId },
      data: {
        ...rest,
        specs: specs === undefined
          ? undefined
          : specs === null
            ? Prisma.JsonNull
            : (specs as Prisma.InputJsonValue),
        offers: offers === undefined
          ? undefined
          : offers === null
            ? Prisma.JsonNull
            : (offers as Prisma.InputJsonValue),
        contentBlocks: contentBlocks === undefined
          ? undefined
          : contentBlocks === null
            ? Prisma.JsonNull
            : (sanitizeContentBlocks(contentBlocks) as Prisma.InputJsonValue),
        variantAxes: variantAxes === undefined
          ? undefined
          : variantAxes === null
            ? Prisma.JsonNull
            : (variantAxes as Prisma.InputJsonValue),
      },
    });
    if (result.count === 0) return null;

    if (variants !== undefined) {
      const fundedRow = await prisma.product.findFirst({
        where: { id, shopId },
        select: { stockQuantity: true },
      });
      const fundedTotal = Number(fundedRow?.stockQuantity ?? 0);
      const clampStock = (q?: number) => Math.min(q ?? 0, fundedTotal);

      const existing = await prisma.productVariant.findMany({
        where: { productId: id },
        select: { id: true },
      });
      const incomingIds = new Set(
        variants.filter((v) => v.id != null).map((v) => v.id!),
      );
      const toDeactivate = existing
        .filter((e) => !incomingIds.has(e.id))
        .map((e) => e.id);
      if (toDeactivate.length > 0) {
        await prisma.productVariant.updateMany({
          where: { id: { in: toDeactivate } },
          data: { isActive: false },
        });
      }
      for (let i = 0; i < variants.length; i++) {
        const v = variants[i];
        if (v.id) {
          const res = await prisma.productVariant.updateMany({
            where: { id: v.id, productId: id },
            data: {
              sku: v.sku,
              barcode: v.barcode ?? null,
              attributes: v.attributes as Prisma.InputJsonValue,
              mrp: v.mrp,
              sellingPrice: v.sellingPrice,
              purchasePrice: v.purchasePrice,
              hsnCode: v.hsnCode ?? null,
              ...(v.taxPercent !== undefined && { taxPercent: v.taxPercent }),
              stockQuantity: clampStock(v.stockQuantity),
              imageUrls: v.imageUrls ?? [],
              isActive: v.isActive ?? true,
              sortOrder: v.sortOrder ?? i,
            },
          });
          if (res.count === 0) {
            continue;
          }
        } else {
          await prisma.productVariant.create({
            data: {
              productId: id,
              sku: v.sku,
              barcode: v.barcode ?? null,
              attributes: v.attributes as Prisma.InputJsonValue,
              mrp: v.mrp,
              sellingPrice: v.sellingPrice,
              purchasePrice: v.purchasePrice,
              hsnCode: v.hsnCode ?? null,
              ...(v.taxPercent !== undefined && { taxPercent: v.taxPercent }),
              stockQuantity: clampStock(v.stockQuantity),
              imageUrls: v.imageUrls ?? [],
              isActive: v.isActive ?? true,
              sortOrder: v.sortOrder ?? i,
              isDefault: false,
            },
          });
        }
      }
    }
    const embedSourceChanged =
      data.name !== undefined ||
      data.description !== undefined ||
      data.tags !== undefined ||
      data.highlights !== undefined ||
      data.specs !== undefined;
    if (embedSourceChanged) {
      await prisma.product.updateMany({
        where: { id, shopId },
        data: { embeddedAt: null },
      });
      void embeddingService.reembedProduct(id);
    }
    return prisma.product.findFirst({
      where: { id, shopId },
      select: productSelect,
    });
  }

  async setPublished(shopId: number, id: number, isPublished: boolean) {
    if (isPublished) {
      const target = await prisma.product.findFirst({
        where: { id, shopId },
        select: {
          taxPercent: true,
          mrp: true,
          sellingPrice: true,
          variants: { select: { mrp: true, sellingPrice: true } },
        },
      });
      if (!target) return null;
      if (target.taxPercent === null || target.taxPercent === undefined) {
        throw new HttpError(
          400,
          'TAX_RATE_REQUIRED',
          'Set a GST tax rate on this product before publishing it.',
        );
      }
      if (
        new Prisma.Decimal(target.sellingPrice).greaterThan(
          new Prisma.Decimal(target.mrp),
        )
      ) {
        throw new HttpError(
          400,
          'SELLING_ABOVE_MRP',
          'Selling price cannot exceed MRP; fix it before publishing.',
        );
      }
      const offendingVariant = target.variants.find((v) =>
        new Prisma.Decimal(v.sellingPrice).greaterThan(new Prisma.Decimal(v.mrp)),
      );
      if (offendingVariant) {
        throw new HttpError(
          400,
          'SELLING_ABOVE_MRP',
          'A variant selling price exceeds its MRP; fix it before publishing.',
        );
      }
    }
    const result = await prisma.product.updateMany({
      where: { id, shopId },
      data: { isPublished },
    });
    if (result.count === 0) return null;
    return prisma.product.findFirst({
      where: { id, shopId },
      select: productSelect,
    });
  }

  async deleteProduct(shopId: number, id: number) {
    const owned = await prisma.product.findFirst({
      where: { id, shopId },
      select: { id: true },
    });
    if (!owned) return null;

    const [stockRefs, invoiceRefs, challanRefs, adjustmentRefs] = await Promise.all([
      prisma.stockTransaction.count({ where: { productId: id } }),
      prisma.invoiceItem.count({ where: { productId: id } }),
      prisma.challanItem.count({ where: { productId: id } }),
      prisma.stockAdjustmentItem.count({ where: { productId: id } }),
    ]);
    const referenced = stockRefs + invoiceRefs + challanRefs + adjustmentRefs > 0;
    if (referenced) {
      return prisma.product.update({
        where: { id },
        data: { isActive: false },
        select: productSelect,
      });
    }
    return prisma.product.delete({ where: { id } });
  }

  private async _ownsProduct(shopId: number, productId: number): Promise<boolean> {
    const row = await prisma.product.findFirst({
      where: { id: productId, shopId },
      select: { id: true },
    });
    return row !== null;
  }

  async addImage(shopId: number, productId: number, url: string, sortOrder?: number) {
    if (!(await this._ownsProduct(shopId, productId))) return null;
    const maxOrder = await prisma.productImage.aggregate({
      where: { productId },
      _max: { sortOrder: true },
    });
    const order = sortOrder ?? (maxOrder._max.sortOrder ?? -1) + 1;
    return prisma.productImage.create({ data: { productId, url, sortOrder: order } });
  }

  async deleteImage(shopId: number, productId: number, imageId: number) {
    if (!(await this._ownsProduct(shopId, productId))) return { error: 'Image not found' as const };
    const image = await prisma.productImage.findFirst({ where: { id: imageId, productId } });
    if (!image) return { error: 'Image not found' as const };
    await prisma.productImage.delete({ where: { id: imageId } });
    return { ok: true };
  }

  async reorderImages(shopId: number, productId: number, orderedIds: number[]) {
    if (!(await this._ownsProduct(shopId, productId))) return null;
    await prisma.$transaction(
      orderedIds.map((id, i) =>
        prisma.productImage.updateMany({ where: { id, productId }, data: { sortOrder: i } }),
      ),
    );
    return prisma.productImage.findMany({ where: { productId }, orderBy: { sortOrder: 'asc' } });
  }

  async refreshSoldLast30d(): Promise<{ updated: number }> {
    const result = await prisma.$executeRaw`
      WITH agg AS (
        SELECT ii.product_id,
               COALESCE(SUM(ii.quantity), 0)::int AS sold
          FROM invoice_items ii
          JOIN invoices i ON i.id = ii.invoice_id
         WHERE i.status = 'CONFIRMED'
           AND i.created_at >= NOW() - INTERVAL '30 days'
         GROUP BY ii.product_id
      )
      UPDATE products p
         SET sold_last_30d = COALESCE(agg.sold, 0)
        FROM products src
        LEFT JOIN agg ON agg.product_id = src.id
       WHERE p.id = src.id
         AND p.sold_last_30d IS DISTINCT FROM COALESCE(agg.sold, 0)
    `;
    return { updated: Number(result) };
  }
}

export const productsService = new ProductsService();
