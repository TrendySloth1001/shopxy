import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { categoriesService } from './categories.service.js';

const createCategorySchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  imageUrl: z.string().url().optional(),
  sortOrder: z.number().int().min(0).optional(),
});

const updateCategorySchema = z
  .object({
    name: z.string().min(1).max(100).optional(),
    description: z.string().max(500).nullable().optional(),
    imageUrl: z.string().url().nullable().optional(),
    sortOrder: z.number().int().min(0).optional(),
    isActive: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
  });

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) ? id : null;
}

export class CategoriesController {
  async create(req: Request, res: Response): Promise<void> {
    const payload = createCategorySchema.parse(req.body);
    const category = await categoriesService.createCategory(payload);
    res.status(201).json(category);
  }

  async list(req: Request, res: Response): Promise<void> {
    const activeOnly = req.query.active !== 'false';
    const { page, limit, skip } = parsePagination(req);
    const { categories, total } = await categoriesService.listCategories({
      activeOnly,
      page,
      limit,
      skip,
    });

    res.json(paginatedResponse(categories, total, { page, limit, skip }));
  }

  async getById(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    const category = await categoriesService.getCategoryById(id);
    if (!category) {
      res.status(404).json({ error: 'Category not found' });
      return;
    }

    res.json(category);
  }

  async update(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    const payload = updateCategorySchema.parse(req.body);
    const category = await categoriesService.updateCategory(id, payload);
    res.json(category);
  }

  async delete(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    await categoriesService.deleteCategory(id);
    res.status(204).send();
  }
}

export const categoriesController = new CategoriesController();
