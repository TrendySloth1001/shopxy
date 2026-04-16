import { Request, Response } from 'express';
import { z } from 'zod';
import { UNITS } from '../../shared/constants/index.js';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { productsService } from './products.service.js';

const createProductSchema = z.object({
  name: z.string().min(1).max(200),
  description: z.string().max(1000).optional(),
  sku: z.string().min(1).max(50),
  barcode: z.string().max(50).optional(),
  hsnCode: z.string().max(20).optional(),
  imageUrl: z.string().url().optional(),
  mrp: z.number().positive(),
  sellingPrice: z.number().positive(),
  purchasePrice: z.number().nonnegative(),
  taxPercent: z.number().min(0).max(100).optional(),
  stockQuantity: z.number().nonnegative().optional(),
  lowStockThreshold: z.number().nonnegative().optional(),
  unit: z.enum(UNITS).optional(),
  categoryId: z.number().int().positive().optional(),
});

const updateProductSchema = z
  .object({
    name: z.string().min(1).max(200).optional(),
    description: z.string().max(1000).nullable().optional(),
    sku: z.string().min(1).max(50).optional(),
    barcode: z.string().max(50).nullable().optional(),
    hsnCode: z.string().max(20).nullable().optional(),
    imageUrl: z.string().url().nullable().optional(),
    mrp: z.number().positive().optional(),
    sellingPrice: z.number().positive().optional(),
    purchasePrice: z.number().nonnegative().optional(),
    taxPercent: z.number().min(0).max(100).optional(),
    lowStockThreshold: z.number().nonnegative().optional(),
    unit: z.enum(UNITS).optional(),
    categoryId: z.number().int().positive().nullable().optional(),
    isActive: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
  });

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class ProductsController {
  async create(req: Request, res: Response): Promise<void> {
    const payload = createProductSchema.parse(req.body);
    const product = await productsService.createProduct(payload);
    res.status(201).json(product);
  }

  async list(req: Request, res: Response): Promise<void> {
    const { page, limit, skip } = parsePagination(req);
    const search = (req.query.search as string) || '';
    const categoryId = req.query.categoryId ? Number(req.query.categoryId) : undefined;
    const lowStock = req.query.lowStock === 'true';
    const activeOnly = req.query.active !== 'false';
    const sortBy = (req.query.sortBy as string) || 'updatedAt';
    const sortOrder = req.query.sortOrder === 'asc' ? 'asc' : 'desc';

    const { products, total } = await productsService.listProducts({
      activeOnly,
      lowStock,
      categoryId,
      search,
      sortBy,
      sortOrder,
      page,
      limit,
      skip,
    });

    res.json(paginatedResponse(products, total, { page, limit, skip }));
  }

  async lookup(req: Request, res: Response): Promise<void> {
    const code = req.query.code as string;
    if (!code) {
      res.status(400).json({ error: 'Query parameter "code" is required' });
      return;
    }

    const product = await productsService.lookupProduct(code);
    if (!product) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }

    res.json(product);
  }

  async getById(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    const product = await productsService.getProductById(id);
    if (!product) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }

    res.json(product);
  }

  async update(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    const payload = updateProductSchema.parse(req.body);
    const product = await productsService.updateProduct(id, payload);
    res.json(product);
  }

  async delete(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    await productsService.deleteProduct(id);
    res.status(204).send();
  }
}

export const productsController = new ProductsController();
