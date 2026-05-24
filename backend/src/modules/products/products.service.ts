import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { ledgerService } from '../ledger/ledger.service.js';
import { embeddingService } from '../search/embedding.service.js';

const productSelect = {
  id: true,
  name: true,
  description: true,
  sku: true,
  barcode: true,
  hsnCode: true,
  mrp: true,
  sellingPrice: true,
  purchasePrice: true,
  taxPercent: true,
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
  createdAt: true,
  updatedAt: true,
  category: true,
  images: { orderBy: { sortOrder: 'asc' as const } },
} as const;

export class ProductsService {
  async createProduct(
    data: {
      name: string;
      description?: string;
      sku: string;
      barcode?: string;
      hsnCode?: string;
      mrp: number;
      sellingPrice: number;
      purchasePrice: number;
      taxPercent?: number;
      stockQuantity?: number;
      lowStockThreshold?: number;
      unit?: string;
      categoryId?: number;
      imageUrls?: string[];
      tags?: string[];
      highlights?: string[];
      specs?: unknown;
      offers?: unknown;
    },
    options: { createdById?: number; shopId?: number } = {},
  ) {
    const { imageUrls, stockQuantity, specs, offers, ...rest } = data;
    // Create the product with stockQuantity = 0; the ledger post below is
    // what funds it. This keeps products.stockQuantity in sync with the
    // ledger from row one — no orphan stock without a cost basis.
    if (!options.shopId) {
      throw new Error('createProduct requires options.shopId');
    }
    const product = await prisma.product.create({
      data: {
        ...rest,
        // JSONB columns need explicit `as Prisma.InputJsonValue` casts;
        // pass through unchanged when omitted so the column stays NULL.
        specs: specs === undefined ? undefined : (specs as Prisma.InputJsonValue),
        offers: offers === undefined ? undefined : (offers as Prisma.InputJsonValue),
        shopId: options.shopId,
        stockQuantity: 0,
        images: imageUrls?.length
          ? { create: imageUrls.map((url, i) => ({ url, sortOrder: i })) }
          : undefined,
      },
      select: productSelect,
    });

    // New product → kick off a semantic embedding so it's searchable
    // by intent the moment it appears. Failures are swallowed
    // inside reembedProduct + the cron retries periodically.
    void embeddingService.reembedProduct(product.id);

    if (stockQuantity && stockQuantity > 0) {
      const result = await ledgerService.post({
        shopId: options.shopId,
        direction: 'IN',
        reasonCode: 'OPENING',
        sourceType: 'OPENING',
        sourceId: product.id,
        lines: [
          {
            productId: product.id,
            quantity: stockQuantity,
            unitPrice: data.purchasePrice,
          },
        ],
        createdById: options.createdById,
        note: 'Opening balance on product create',
      });

      if ('error' in result) {
        // Roll back the product so we never leave one without a ledger.
        await prisma.product.delete({ where: { id: product.id } });
        throw new Error(`Failed to post opening balance: ${result.error}`);
      }

      // Re-read so the response reflects the funded stock quantity.
      return prisma.product.findUniqueOrThrow({
        where: { id: product.id },
        select: productSelect,
      });
    }

    return product;
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
    // EVERY product read filters by shopId — non-negotiable for multi-tenant
    // safety. Even a search/categoryId combo without this filter would let
    // an authenticated merchant browse competitors' catalogs.
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

    // Out-of-stock is the simple case: stockQuantity = 0, no
    // column-to-column comparison needed. Wins on Low if both are
    // toggled (defensive — UI keeps them mutually exclusive).
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
      // Column-to-column comparison (stock_quantity <= low_stock_threshold)
      // can't be expressed in Prisma's typed `where` builder, so we drop
      // to two parameterised raw queries — one for COUNT, one for the
      // page-of-ids — and then a third typed read to hydrate. This is
      // the indexed path: ~3 round-trips with O(rows-on-page) memory,
      // vs the previous implementation which pulled every active row
      // for the shop into Node memory before filtering.
      const orderBy = { [options.sortBy]: options.sortOrder } as Record<string, 'asc' | 'desc'>;
      const categoryClause = options.categoryId
        ? Prisma.sql`AND category_id = ${options.categoryId}`
        : Prisma.empty;

      const [countRow, pageRows] = await Promise.all([
        prisma.$queryRaw<{ count: bigint }[]>`
          SELECT COUNT(*)::bigint AS count FROM products
           WHERE shop_id = ${options.shopId}
             AND is_active = true
             AND stock_quantity > 0
             AND stock_quantity <= low_stock_threshold
             ${categoryClause}
        `,
        prisma.$queryRaw<{ id: number }[]>`
          SELECT id FROM products
           WHERE shop_id = ${options.shopId}
             AND is_active = true
             AND stock_quantity > 0
             AND stock_quantity <= low_stock_threshold
             ${categoryClause}
           ORDER BY updated_at DESC
           LIMIT ${options.limit} OFFSET ${options.skip}
        `,
      ]);

      const total = Number(countRow[0]?.count ?? 0);
      const pageIds = pageRows.map((r) => r.id);
      if (pageIds.length === 0) return { products: [], total };

      const products = await prisma.product.findMany({
        where: { id: { in: pageIds } },
        orderBy,
        select: productSelect,
      });

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

  /**
   * Enrich a page of products with last STOCK_IN / STOCK_OUT timestamps and
   * the vendor of the most recent STOCK_IN (when one exists).
   *
   * Single window-function pass over the relevant slice of stock_transactions,
   * so this stays O(page) regardless of ledger size. `lastVendor` is suppressed
   * when both vendor_id and vendor_name come back null — those are free-text
   * suppliers from the legacy `supplier_name` column.
   */
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

    // Bucket by productId, splitting last-IN vs last-OUT.
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

  lookupProduct(shopId: number, code: string) {
    return prisma.product.findFirst({
      where: { shopId, OR: [{ barcode: code }, { sku: code }] },
      select: productSelect,
    });
  }

  getProductById(shopId: number, id: number) {
    return prisma.product.findFirst({
      where: { id, shopId },
      include: {
        category: true,
        images: { orderBy: { sortOrder: 'asc' } },
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
      mrp?: number;
      sellingPrice?: number;
      purchasePrice?: number;
      taxPercent?: number;
      lowStockThreshold?: number;
      unit?: string;
      categoryId?: number | null;
      isActive?: boolean;
      isPublished?: boolean;
      tags?: string[];
      highlights?: string[];
      specs?: unknown | null;
      offers?: unknown | null;
    },
  ) {
    // updateMany returns count instead of throwing on missing row; that
    // lets us distinguish "wrong shop" from "wrong id" cleanly without
    // a separate guard query. count=0 → either id doesn't exist OR
    // belongs to another shop. Either way: 404 from the controller.
    const { specs, offers, ...rest } = data;
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
      },
    });
    if (result.count === 0) return null;
    // Any edit that touches the embedding source (name / description /
    // tags / highlights / specs) invalidates the cached embedding.
    // Cheap inline re-embed runs in the background — failures are
    // swallowed inside reembedProduct + the cron retries.
    const embedSourceChanged =
      data.name !== undefined ||
      data.description !== undefined ||
      data.tags !== undefined ||
      data.highlights !== undefined ||
      data.specs !== undefined;
    if (embedSourceChanged) {
      await prisma.product.update({
        where: { id },
        data: { embeddedAt: null },
      });
      void embeddingService.reembedProduct(id);
    }
    return prisma.product.findUnique({ where: { id }, select: productSelect });
  }

  async setPublished(shopId: number, id: number, isPublished: boolean) {
    const result = await prisma.product.updateMany({
      where: { id, shopId },
      data: { isPublished },
    });
    if (result.count === 0) return null;
    return prisma.product.findUnique({ where: { id }, select: productSelect });
  }

  async deleteProduct(shopId: number, id: number) {
    // Guard cross-tenant deletes by scoping the ownership check itself
    // to (id, shopId). A merchant probing another shop's ids gets 404.
    const owned = await prisma.product.findFirst({
      where: { id, shopId },
      select: { id: true },
    });
    if (!owned) return null;

    // Soft-delete if the product is referenced anywhere — invoices, challans,
    // stock ledger, or adjustment lines all need the row to stay around so
    // historical documents render correctly. Otherwise hard-delete.
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

  // ── Image management ──────────────────────────────────────────────

  /// Verify (productId, shopId) ownership in one query so the rest of
  /// image management can trust the productId. Returns null when the
  /// product doesn't exist *or* belongs to another shop — both 404 to
  /// avoid leaking which is which.
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
}

export const productsService = new ProductsService();
