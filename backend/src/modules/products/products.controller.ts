import { Request, Response } from 'express';
import { z } from 'zod';
import { UNITS } from '../../shared/constants/index.js';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { decodeId } from '../../shared/ids/publicId.js';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { productsService } from './products.service.js';

const STOCK_MAX = 999_999_999;

const PRODUCT_CATALOGUE_MAX = 5_000;
const hasMax3Decimals = (n: number): boolean =>
  Number.isFinite(n) && Math.round(n * 1000) === n * 1000;

const productImageRef = z
  .string()
  .min(1)
  .max(2048)
  .refine((v) => /^https?:\/\//i.test(v) || v.startsWith('/'), {
    message: 'Must be an http(s) URL or a server-relative path',
  });

const contentBlockSchema = z.discriminatedUnion('kind', [
  z.object({
    kind: z.literal('HERO'),
    imageUrl: productImageRef,
    headline: z.string().min(1).max(120),
    subtext: z.string().max(240).optional(),
  }),
  z.object({
    kind: z.literal('FEATURE'),
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
          url: productImageRef,
          caption: z.string().max(140).optional(),
        }),
      )
      .min(1)
      .max(6),
  }),
  z.object({
    kind: z.literal('TEXT'),
    markdown: z.string().min(1).max(2000),
  }),
]);

const contentBlocksSchema = z.array(contentBlockSchema).max(8);

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
    id: zPublicId.optional(),
    sku: z.string().min(1).max(60),
    barcode: z.string().max(60).nullable().optional(),
    attributes: z.record(z.string(), z.string()),
    mrp: z.number().positive(),
    sellingPrice: z.number().positive(),
    purchasePrice: z.number().nonnegative(),
    hsnCode: z.string().max(20).nullable().optional(),
    taxPercent: z.number().min(0).max(100).optional(),
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
  countryOfOrigin: z.string().min(1).max(60).optional(),
  brand: z.string().min(1).max(80).optional(),
  imageUrls: z.array(productImageRef).max(10).optional(),
  mrp: z.number().positive(),
  sellingPrice: z.number().positive(),
  purchasePrice: z.number().nonnegative(),
  taxPercent: z.number().min(0).max(100).optional(),
  cessRate: z.number().min(0).max(300).optional(),
  pricingMode: z.enum(['TAX_EXCLUSIVE', 'TAX_INCLUSIVE', 'NO_GST']).optional(),
  stockQuantity: z
    .number()
    .nonnegative()
    .max(STOCK_MAX, `Stock cannot exceed ${STOCK_MAX}`)
    .refine(hasMax3Decimals, 'Stock supports at most 3 decimal places')
    .optional(),
  lowStockThreshold: z.number().nonnegative().optional(),
  unit: z.enum(UNITS).optional(),
  categoryId: zPublicId.optional(),
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
    countryOfOrigin: z.string().min(1).max(60).nullable().optional(),
    brand: z.string().min(1).max(80).nullable().optional(),
    mrp: z.number().positive().optional(),
    sellingPrice: z.number().positive().optional(),
    purchasePrice: z.number().nonnegative().optional(),
    taxPercent: z.number().min(0).max(100).optional(),
    cessRate: z.number().min(0).max(300).optional(),
    pricingMode: z.enum(['TAX_EXCLUSIVE', 'TAX_INCLUSIVE', 'NO_GST']).optional(),
    lowStockThreshold: z.number().nonnegative().optional(),
    unit: z.enum(UNITS).optional(),
    categoryId: zPublicId.nullable().optional(),
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
  .refine(
    (d) => d.mrp === undefined || d.sellingPrice === undefined || d.sellingPrice <= d.mrp,
    { message: 'Selling price cannot exceed MRP', path: ['sellingPrice'] },
  );

const setPublishedSchema = z.object({ isPublished: z.boolean() });

const listProductsQuerySchema = z.object({
  search: z.string().max(200).optional(),
  categoryId: zPublicId.optional(),
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
  orderedIds: z.array(zPublicId).min(1),
});

function parseId(raw: string): number | null {
  return decodeId(raw);
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

  async catalogue(req: Request, res: Response): Promise<void> {
    const { products, total, truncated } = await productsService.listCatalogue({
      shopId: req.shopId!,
      limit: PRODUCT_CATALOGUE_MAX,
    });

    res.json({ data: products, total, truncated, limit: PRODUCT_CATALOGUE_MAX });
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
