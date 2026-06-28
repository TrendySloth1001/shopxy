import { Request, Response } from 'express';
import { z } from 'zod';
import { UNITS } from '../../shared/constants/index.js';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { productsService } from './products.service.js';

// CAT-M5 — stock columns are Decimal(12,3): nine integer digits + three
// fractional. Anything at/above 1e9 overflows the precision (DB throws
// inconsistently), and >3 decimals is silently truncated by Postgres. Bound
// both the product- and variant-level stock at the schema so the API rejects
// these cleanly instead of leaking a DB error or storing a truncated number.
const STOCK_MAX = 999_999_999;
const hasMax3Decimals = (n: number): boolean =>
  Number.isFinite(n) && Math.round(n * 1000) === n * 1000;

// Accepts either an absolute URL (legacy rows, externally-hosted images)
// or a server-relative path like `/images/<key>` (the format our own
// /upload endpoint returns — relative on purpose so the same row works
// against localhost, devtunnels, and prod). Using bare `z.string().url()`
// here silently rejected every fresh upload, leaving newly-created
// products without an image even though the file landed in MinIO.
const productImageRef = z
  .string()
  .min(1)
  .max(2048)
  .refine((v) => /^https?:\/\//i.test(v) || v.startsWith('/'), {
    message: 'Must be an http(s) URL or a server-relative path',
  });

// Phase D — optional `tab` key per spec group. When any group declares
// a tab the customer PDP renders a chip row above the spec sheet and
// filters groups by selection. Empty/absent keeps the legacy flat-list
// render so existing products are unaffected.
// Phase C — A+ content blocks. Five fixed kinds with per-kind payloads,
// hard cap of 8 blocks per product. Markdown sanitisation for TEXT
// blocks happens in the service layer so the DB never sees raw <script>.
const contentBlockSchema = z.discriminatedUnion('kind', [
  z.object({
    kind: z.literal('HERO'),
    // UPLOAD-3: scheme-validate (http(s) or server-relative) so a content
    // block can't smuggle a javascript:/data: URL that renders on the PDP.
    imageUrl: productImageRef,
    headline: z.string().min(1).max(120),
    subtext: z.string().max(240).optional(),
  }),
  z.object({
    kind: z.literal('FEATURE'),
    // UPLOAD-3: scheme-validate (http(s) or server-relative) so a content
    // block can't smuggle a javascript:/data: URL that renders on the PDP.
    imageUrl: productImageRef,
    side: z.enum(['LEFT', 'RIGHT']),
    title: z.string().min(1).max(120),
    body: z.string().min(1).max(500),
  }),
  z.object({
    kind: z.literal('COMPARISON'),
    columns: z
      .array(
        z.object({
          label: z.string().min(1).max(80),
          values: z.array(z.string().max(120)).min(1).max(10),
        }),
      )
      .min(2)
      .max(4),
    rows: z.array(z.string().min(1).max(80)).min(1).max(10),
  }),
  z.object({
    kind: z.literal('GALLERY'),
    images: z
      .array(
        z.object({
          url: productImageRef, // UPLOAD-3: reject javascript:/data: URLs
          caption: z.string().max(140).optional(),
        }),
      )
      .min(1)
      .max(6),
  }),
  z.object({
    kind: z.literal('TEXT'),
    // Restricted markdown subset — the service strips any <script> /
    // <iframe> before saving so the DB column stays render-safe.
    markdown: z.string().min(1).max(2000),
  }),
]);

const contentBlocksSchema = z.array(contentBlockSchema).max(8);

// Phase E — axis definitions and per-variant payloads. Each variant
// must include all axis attributes; missing keys would lead to undefined
// behaviour in the swatch picker. Stock is decimal-shaped to match the
// product table.
const variantAxesSchema = z
  .array(
    z.object({
      name: z.string().min(1).max(40),
      values: z.array(z.string().min(1).max(40)).min(1).max(20),
    }),
  )
  .max(3);

const variantSchema = z
  .object({
    id: z.number().int().positive().optional(),
    sku: z.string().min(1).max(60),
    barcode: z.string().max(60).nullable().optional(),
    attributes: z.record(z.string(), z.string()),
    mrp: z.number().positive(),
    sellingPrice: z.number().positive(),
    purchasePrice: z.number().nonnegative(),
    // CAT-H1 — optional per-variant GST source. When two variants of a
    // product sit in different HSN/GST slabs the merchant declares each
    // variant's own hsnCode / taxPercent; null/omitted inherits the
    // product-level slab at invoice time. Bounds mirror the product fields.
    hsnCode: z.string().max(20).nullable().optional(),
    taxPercent: z.number().min(0).max(100).optional(),
    // CAT-M5 — bound the variant display stock at write. The column is
    // Decimal(12,3): values above the funded product total are already
    // clamped in the service (CAT-C1), but the schema must also refuse
    // absurd magnitudes (>1e9 overflows the precision and throws
    // inconsistently at the DB layer) and >3 decimal places (silently
    // truncated by Postgres). Keep the same bound on the product field.
    stockQuantity: z
      .number()
      .nonnegative()
      .max(STOCK_MAX, `Stock cannot exceed ${STOCK_MAX}`)
      .refine(hasMax3Decimals, 'Stock supports at most 3 decimal places')
      .default(0),
    imageUrls: z.array(z.string().min(1).max(2048)).max(8).optional(),
    isActive: z.boolean().optional(),
    sortOrder: z.number().int().nonnegative().optional(),
  })
  // CAT-C3 — Legal Metrology s.18/s.36: a variant must never be sold above
  // its declared MRP. Cross-field so the message points at sellingPrice.
  .refine((v) => v.sellingPrice <= v.mrp, {
    message: 'Selling price cannot exceed MRP',
    path: ['sellingPrice'],
  });
const variantsSchema = z.array(variantSchema).max(50);

const specGroupSchema = z.object({
  title: z.string().min(1).max(80),
  tab: z.string().min(1).max(40).optional(),
  rows: z
    .array(
      z.object({
        label: z.string().min(1).max(80),
        value: z.string().min(1).max(200),
      }),
    )
    .min(1)
    .max(20),
});

const createProductSchema = z.object({
  name: z.string().min(1).max(200),
  description: z.string().max(1000).optional(),
  sku: z.string().min(1).max(50),
  barcode: z.string().max(50).optional(),
  hsnCode: z.string().max(20).optional(),
  // CAT-C2 — country of manufacture/origin. Required on the printed
  // invoice/label for imported goods (Legal Metrology); optional here so
  // domestic goods without a declared origin stay valid.
  countryOfOrigin: z.string().min(1).max(60).optional(),
  // Phase B — free-text brand surfaced under the PDP title.
  brand: z.string().min(1).max(80).optional(),
  imageUrls: z.array(productImageRef).max(10).optional(),
  mrp: z.number().positive(),
  sellingPrice: z.number().positive(),
  purchasePrice: z.number().nonnegative(),
  taxPercent: z.number().min(0).max(100).optional(),
  // Compensation cess is ad valorem up to 290% (tobacco) — wider bound
  // than GST on purpose.
  cessRate: z.number().min(0).max(300).optional(),
  // CAT-M5 — same Decimal(12,3) bound as the variant field.
  stockQuantity: z
    .number()
    .nonnegative()
    .max(STOCK_MAX, `Stock cannot exceed ${STOCK_MAX}`)
    .refine(hasMax3Decimals, 'Stock supports at most 3 decimal places')
    .optional(),
  lowStockThreshold: z.number().nonnegative().optional(),
  unit: z.enum(UNITS).optional(),
  categoryId: z.number().int().positive().optional(),
  tags: z.array(z.string().min(1).max(40)).max(20).optional(),
  // V2 PDP descriptive fields. All optional; the customer screen
  // hides the relevant section when the array / object is empty.
  highlights: z.array(z.string().min(1).max(140)).max(8).optional(),
  specs: z
    .array(specGroupSchema)
    .max(10)
    .nullable()
    .optional(),
  offers: z
    .array(
      z.object({
        kind: z.enum(['BANK', 'COUPON', 'EMI', 'EXCHANGE']),
        headline: z.string().min(1).max(140),
        detail: z.string().max(200).optional(),
        code: z.string().max(40).optional(),
      }),
    )
    .max(6)
    .nullable()
    .optional(),
  contentBlocks: contentBlocksSchema.nullable().optional(),
  variantAxes: variantAxesSchema.nullable().optional(),
  variants: variantsSchema.optional(),
})
  // CAT-C3 — Legal Metrology s.18/s.36: product-level selling price must
  // never exceed MRP. Variant-level prices are validated on variantSchema.
  .refine((d) => d.sellingPrice <= d.mrp, {
    message: 'Selling price cannot exceed MRP',
    path: ['sellingPrice'],
  });

const updateProductSchema = z
  .object({
    name: z.string().min(1).max(200).optional(),
    description: z.string().max(1000).nullable().optional(),
    sku: z.string().min(1).max(50).optional(),
    barcode: z.string().max(50).nullable().optional(),
    hsnCode: z.string().max(20).nullable().optional(),
    // CAT-C2 — nullable so the merchant can clear a previously-set origin.
    countryOfOrigin: z.string().min(1).max(60).nullable().optional(),
    brand: z.string().min(1).max(80).nullable().optional(),
    mrp: z.number().positive().optional(),
    sellingPrice: z.number().positive().optional(),
    purchasePrice: z.number().nonnegative().optional(),
    taxPercent: z.number().min(0).max(100).optional(),
    cessRate: z.number().min(0).max(300).optional(),
    lowStockThreshold: z.number().nonnegative().optional(),
    unit: z.enum(UNITS).optional(),
    categoryId: z.number().int().positive().nullable().optional(),
    isActive: z.boolean().optional(),
    isPublished: z.boolean().optional(),
    tags: z.array(z.string().min(1).max(40)).max(20).optional(),
    highlights: z.array(z.string().min(1).max(140)).max(8).optional(),
    specs: z
      .array(specGroupSchema)
      .max(10)
      .nullable()
      .optional(),
    offers: z
      .array(
        z.object({
          kind: z.enum(['BANK', 'COUPON', 'EMI', 'EXCHANGE']),
          headline: z.string().min(1).max(140),
          detail: z.string().max(200).optional(),
          code: z.string().max(40).optional(),
        }),
      )
      .max(6)
      .nullable()
      .optional(),
    contentBlocks: contentBlocksSchema.nullable().optional(),
    variantAxes: variantAxesSchema.nullable().optional(),
    variants: variantsSchema.optional(),
  })
  .refine((d) => Object.keys(d).length > 0, { message: 'At least one field is required' })
  // CAT-C3 — when both mrp and sellingPrice are supplied in the same patch
  // we can enforce the invariant up front. A patch touching only ONE of the
  // pair is re-checked against the persisted row in the service layer.
  .refine(
    (d) => d.mrp === undefined || d.sellingPrice === undefined || d.sellingPrice <= d.mrp,
    { message: 'Selling price cannot exceed MRP', path: ['sellingPrice'] },
  );

const setPublishedSchema = z.object({ isPublished: z.boolean() });

// All query-string params coerced + bounded here so the service trusts
// its inputs and clients get 400s instead of weird db queries.
const listProductsQuerySchema = z.object({
  search: z.string().max(200).optional(),
  categoryId: z.coerce.number().int().positive().optional(),
  lowStock: z.enum(['true', 'false']).optional(),
  outOfStock: z.enum(['true', 'false']).optional(),
  active: z.enum(['true', 'false']).optional(),
  sortBy: z.enum(['updatedAt', 'name', 'sellingPrice', 'createdAt']).optional(),
  sortOrder: z.enum(['asc', 'desc']).optional(),
});

const lookupQuerySchema = z.object({
  code: z.string().min(1).max(120),
});

const addImageSchema = z.object({
  url: productImageRef,
  sortOrder: z.number().int().nonnegative().optional(),
});

const reorderImagesSchema = z.object({
  orderedIds: z.array(z.number().int().positive()).min(1),
});

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class ProductsController {
  async create(req: Request, res: Response): Promise<void> {
    const payload = createProductSchema.parse(req.body);
    const product = await productsService.createProduct(payload, {
      createdById: req.user!.sub,
      shopId: req.shopId!,
    });
    res.status(201).json(product);
  }

  async list(req: Request, res: Response): Promise<void> {
    const parsed = listProductsQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid query', issues: parsed.error.issues });
      return;
    }
    const q = parsed.data;
    const { page, limit, skip } = parsePagination(req);

    const { products, total } = await productsService.listProducts({
      shopId: req.shopId!,
      activeOnly: q.active !== 'false',
      lowStock: q.lowStock === 'true',
      outOfStock: q.outOfStock === 'true',
      categoryId: q.categoryId,
      search: q.search ?? '',
      sortBy: q.sortBy ?? 'updatedAt',
      sortOrder: q.sortOrder ?? 'desc',
      page,
      limit,
      skip,
    });

    res.json(paginatedResponse(products, total, { page, limit, skip }));
  }

  async lookup(req: Request, res: Response): Promise<void> {
    const parsed = lookupQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'Query parameter "code" is required' });
      return;
    }
    const product = await productsService.lookupProduct(req.shopId!, parsed.data.code);
    if (!product) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }

    res.json(product);
  }

  async getById(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const product = await productsService.getProductById(req.shopId!, id);
    if (!product) { res.status(404).json({ error: 'Product not found' }); return; }

    res.json(product);
  }

  async update(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const payload = updateProductSchema.parse(req.body);
    const product = await productsService.updateProduct(req.shopId!, id, payload);
    if (!product) { res.status(404).json({ error: 'Product not found' }); return; }
    res.json(product);
  }

  async setPublished(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const { isPublished } = setPublishedSchema.parse(req.body);
    const product = await productsService.setPublished(req.shopId!, id, isPublished);
    if (!product) { res.status(404).json({ error: 'Product not found' }); return; }
    res.json(product);
  }

  async delete(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const result = await productsService.deleteProduct(req.shopId!, id);
    if (result === null) { res.status(404).json({ error: 'Product not found' }); return; }
    res.status(204).send();
  }

  // ── Image management ──────────────────────────────────────────────

  async addImage(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const { url, sortOrder } = addImageSchema.parse(req.body);
    const image = await productsService.addImage(req.shopId!, id, url, sortOrder);
    if (image === null) { res.status(404).json({ error: 'Product not found' }); return; }
    res.status(201).json(image);
  }

  async deleteImage(req: Request, res: Response): Promise<void> {
    const productId = parseId(req.params.id);
    const imageId = parseId(req.params.imageId);
    if (!productId || !imageId) { res.status(400).json({ error: 'Invalid id' }); return; }

    const result = await productsService.deleteImage(req.shopId!, productId, imageId);
    if ('error' in result) { res.status(404).json({ error: result.error }); return; }
    res.status(204).send();
  }

  async reorderImages(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const { orderedIds } = reorderImagesSchema.parse(req.body);
    const images = await productsService.reorderImages(req.shopId!, id, orderedIds);
    if (images === null) { res.status(404).json({ error: 'Product not found' }); return; }
    res.json(images);
  }
}

export const productsController = new ProductsController();
