import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { ledgerService } from '../ledger/ledger.service.js';
import { embeddingService } from '../search/embedding.service.js';
import { HttpError } from '../../shared/http/errorHandler.js';

/// Strip the obvious script-injection vectors from TEXT block markdown
/// before it lands in the DB. We trust the Zod schema to enforce shape;
/// this just makes sure the DB column never holds a payload that could
/// turn into XSS if the customer renderer ever switches to HTML mode.
/// Whitelist-rendering on the client (no raw HTML) is the real defence
/// — this is the second line.
///
/// P-4 hardening: beyond quoted `on*=` handlers and a wider tag set, this
/// now also strips UNQUOTED handlers (`onerror=alert(1)`), dangerous URI
/// schemes (`javascript:` / `data:` / `vbscript:`), and runs to a fixed
/// point so nested/obfuscated forms like `<scr<script>ipt>` can't survive
/// a single pass. (A full DOMPurify-class sanitizer / store-as-AST remains
/// the ideal; this stays dependency-free as defense-in-depth.)
const DANGEROUS_TAGS =
  /<\s*\/?\s*(script|iframe|object|embed|style|link|meta|base|form|svg|math)\b[^>]*>/gi;
const EVENT_HANDLERS = /\son\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi;
const DANGEROUS_URIS = /(?:javascript|vbscript|data)\s*:/gi;

function scrubMarkdown(input: string): string {
  let out = input;
  // Iterate so a single removal that reveals a new match (nesting) is
  // also caught. Bounded to avoid pathological input looping.
  for (let i = 0; i < 5; i++) {
    const next = out
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
  // Phase B fields — merchant editor sets brand; soldLast30d and
  // systemTags are read-only from the editor's perspective (set by
  // scheduler / admin).
  brand: true,
  soldLast30d: true,
  systemTags: true,
  // Phase C — A+ content blocks edited by the merchant, rendered in
  // the customer PDP Details tab.
  contentBlocks: true,
  // Phase E — variant axes + variants list.
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
      brand?: string;
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
      contentBlocks?: unknown;
      variantAxes?: unknown;
      variants?: Array<{
        sku: string;
        barcode?: string | null;
        attributes: Record<string, string>;
        mrp: number;
        sellingPrice: number;
        purchasePrice: number;
        stockQuantity?: number;
        imageUrls?: string[];
        isActive?: boolean;
        sortOrder?: number;
      }>;
    },
    options: { createdById?: number; shopId?: number } = {},
  ) {
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
        contentBlocks: contentBlocks === undefined
          ? undefined
          : (sanitizeContentBlocks(contentBlocks) as Prisma.InputJsonValue),
        variantAxes: variantAxes === undefined
          ? undefined
          : (variantAxes as Prisma.InputJsonValue),
        shopId: options.shopId,
        // Default new products to published so they're immediately
        // visible on the customer side. Schema default is false (kept
        // that way for historical imports and bulk seeds); the merchant
        // editor has no draft/publish toggle yet, so leaving it false
        // here meant every freshly created product silently failed to
        // appear in the customer feed.
        isPublished: true,
        stockQuantity: 0,
        images: imageUrls?.length
          ? { create: imageUrls.map((url, i) => ({ url, sortOrder: i })) }
          : undefined,
        // Phase E — variants. When the merchant supplied a variants
        // list we create those directly (and skip the default). When
        // they didn't, we create exactly one default variant that
        // inherits product-level pricing — every product has ≥1
        // variant so the customer client always has a variantId to
        // attach to add-to-cart.
        //
        // P-2: variant `stockQuantity` is DISPLAY-ONLY breakdown metadata.
        // The authoritative on-hand figure is the product-level total,
        // which is the only quantity funded through the inventory ledger
        // (OPENING / SALE / PURCHASE / ADJUSTMENT, with FIFO cost layers
        // and a SELECT…FOR UPDATE lock). Variant stock is written verbatim
        // from the payload, carries no cost basis, and must not be treated
        // as a competing source of truth — reconcile it against the
        // ledgered product total, never the reverse.
        variants: {
          create: (variants && variants.length > 0)
            ? variants.map((v, i) => ({
                sku: v.sku,
                barcode: v.barcode ?? null,
                attributes: v.attributes as Prisma.InputJsonValue,
                mrp: v.mrp,
                sellingPrice: v.sellingPrice,
                purchasePrice: v.purchasePrice,
                stockQuantity: v.stockQuantity ?? 0,
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

      // Phase E v1 — keep the default variant's stockQuantity in sync
      // with the product-level ledger total. The PDP swatch picker
      // reads variant stock for display; the ledger remains the
      // source of truth.
      await prisma.productVariant.updateMany({
        where: { productId: product.id, isDefault: true },
        data: { stockQuantity: stockQuantity },
      });

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
      // P-3: the low-stock raw path must honour the same name/sku/barcode
      // search the typed path applies, else "low stock + search" returns
      // unfiltered low-stock results. Parameterised ILIKE (case-insensitive,
      // matching the typed `mode:'insensitive'`); values are bound, not spliced.
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
      brand?: string | null;
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
        stockQuantity?: number;
        imageUrls?: string[];
        isActive?: boolean;
        sortOrder?: number;
      }>;
    },
  ) {
    // updateMany returns count instead of throwing on missing row; that
    // lets us distinguish "wrong shop" from "wrong id" cleanly without
    // a separate guard query. count=0 → either id doesn't exist OR
    // belongs to another shop. Either way: 404 from the controller.
    const { specs, offers, contentBlocks, variantAxes, variants, ...rest } = data;
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

    // Phase E — when the merchant ships a full variants array, replace
    // the product's variants in place. Diff-by-id keeps stable rows so
    // CartItem.variantId references survive an edit. Bare-minimum
    // implementation: existing variants not listed are soft-deleted
    // (isActive=false) so historical references don't break.
    //
    // P-2: variant `stockQuantity` here is display-only breakdown — see
    // the create path. The ledgered product total is authoritative; this
    // write does not (and must not) post to the inventory ledger.
    if (variants !== undefined) {
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
          // Scope the update to THIS product (proven shop-owned by the
          // outer product.updateMany). Without the productId predicate a
          // caller could PATCH their own product with another shop's
          // variant id and overwrite its price/stock/SKU (cross-tenant
          // IDOR). updateMany lets us detect & skip a foreign/unknown id
          // via count===0 instead of mutating it.
          const res = await prisma.productVariant.updateMany({
            where: { id: v.id, productId: id },
            data: {
              sku: v.sku,
              barcode: v.barcode ?? null,
              attributes: v.attributes as Prisma.InputJsonValue,
              mrp: v.mrp,
              sellingPrice: v.sellingPrice,
              purchasePrice: v.purchasePrice,
              stockQuantity: v.stockQuantity ?? 0,
              imageUrls: v.imageUrls ?? [],
              isActive: v.isActive ?? true,
              sortOrder: v.sortOrder ?? i,
            },
          });
          if (res.count === 0) {
            // Variant id doesn't belong to this product — ignore it
            // rather than touching a row in another shop.
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
              stockQuantity: v.stockQuantity ?? 0,
              imageUrls: v.imageUrls ?? [],
              isActive: v.isActive ?? true,
              sortOrder: v.sortOrder ?? i,
              isDefault: false,
            },
          });
        }
      }
    }
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
    // P-6 / MOD-2: a product must carry an explicit tax rate before it can
    // go live, so a null `taxPercent` can never silently zero GST on a
    // customer order. (Unpublishing is always allowed.)
    if (isPublished) {
      const target = await prisma.product.findFirst({
        where: { id, shopId },
        select: { taxPercent: true },
      });
      if (!target) return null;
      if (target.taxPercent === null || target.taxPercent === undefined) {
        throw new HttpError(
          400,
          'TAX_RATE_REQUIRED',
          'Set a GST tax rate on this product before publishing it.',
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

  /// Refresh the `soldLast30d` denorm on every product from the
  /// trailing-30-day window of CONFIRMED invoice items. Runs nightly
  /// from the scheduler; idempotent — safe to invoke on demand from a
  /// debug endpoint while developing. One UPDATE … FROM (SELECT …)
  /// statement so it stays O(rows in window) regardless of catalogue
  /// size, and the zero-out branch resets products that fell out of
  /// the window since the last tick.
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
        FROM (SELECT id FROM products) ids
        LEFT JOIN agg ON agg.product_id = ids.id
       WHERE p.id = ids.id
         AND p.sold_last_30d IS DISTINCT FROM COALESCE(agg.sold, 0)
    `;
    return { updated: Number(result) };
  }
}

export const productsService = new ProductsService();
