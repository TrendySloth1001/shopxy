import { Request, Response } from 'express';
import { z } from 'zod';
import {
  CUSTOM_FIELD_TYPES,
  customFieldsService,
} from './customFields.service.js';

const createDefinitionSchema = z.object({
  name: z.string().min(1).max(60),
  type: z.enum(CUSTOM_FIELD_TYPES),
  options: z.array(z.string().min(1).max(60)).max(50).optional(),
  unitSuffix: z.string().max(20).optional(),
  icon: z.string().max(40).optional(),
  sectionId: z.number().int().positive().nullable().optional(),
  sortOrder: z.number().int().nonnegative().optional(),
});

const updateDefinitionSchema = z
  .object({
    name: z.string().min(1).max(60).optional(),
    type: z.enum(CUSTOM_FIELD_TYPES).optional(),
    options: z.array(z.string().min(1).max(60)).max(50).nullable().optional(),
    unitSuffix: z.string().max(20).nullable().optional(),
    icon: z.string().max(40).nullable().optional(),
    sectionId: z.number().int().positive().nullable().optional(),
    sortOrder: z.number().int().nonnegative().optional(),
    isActive: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
  });

const createSectionSchema = z.object({
  name: z.string().min(1).max(60),
  icon: z.string().max(40).optional(),
  sortOrder: z.number().int().nonnegative().optional(),
});

const updateSectionSchema = z
  .object({
    name: z.string().min(1).max(60).optional(),
    icon: z.string().max(40).nullable().optional(),
    sortOrder: z.number().int().nonnegative().optional(),
    isActive: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
  });

const applyTemplateSchema = z.object({
  templateId: z.string().min(1).max(40),
});

const reorderSchema = z.object({
  orderedIds: z.array(z.number().int().positive()).min(1),
});

const bulkValuesSchema = z.object({
  values: z
    .array(
      z.object({
        definitionId: z.number().int().positive(),
        value: z.string().max(4000),
      }),
    )
    .max(100),
});

const setValueSchema = z.object({
  value: z.string().max(4000),
});

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

function requireShopId(req: Request, res: Response): number | null {
  const shopId = req.user?.shopId;
  if (!shopId) {
    res.status(403).json({ error: 'This account has no shop linked.' });
    return null;
  }
  return shopId;
}

export class CustomFieldsController {
  async getTree(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const activeOnly = req.query.active !== 'false';
    const tree = await customFieldsService.getTree(shopId, { activeOnly });
    res.json(tree);
  }

  async listTemplates(_req: Request, res: Response): Promise<void> {
    res.json(customFieldsService.listTemplates());
  }

  async applyTemplate(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const { templateId } = applyTemplateSchema.parse(req.body);
    const result = await customFieldsService.applyTemplate(shopId, templateId);
    if ('error' in result) {
      res.status(404).json({ error: result.error });
      return;
    }
    res.json(result);
  }

  async listSections(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const activeOnly = req.query.active !== 'false';
    const sections = await customFieldsService.listSections(shopId, { activeOnly });
    res.json(sections);
  }

  async createSection(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const payload = createSectionSchema.parse(req.body);
    const section = await customFieldsService.createSection(shopId, payload);
    res.status(201).json(section);
  }

  async updateSection(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = updateSectionSchema.parse(req.body);
    const section = await customFieldsService.updateSection(shopId, id, {
      ...payload,
      icon: payload.icon ?? undefined,
    });
    if (!section) {
      res.status(404).json({ error: 'Section not found' });
      return;
    }
    res.json(section);
  }

  async deleteSection(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const result = await customFieldsService.softDeleteSection(shopId, id);
    if (!result) {
      res.status(404).json({ error: 'Section not found' });
      return;
    }
    res.status(204).send();
  }

  async reorderSections(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const { orderedIds } = reorderSchema.parse(req.body);
    const sections = await customFieldsService.reorderSections(shopId, orderedIds);
    res.json(sections);
  }

  async listDefinitions(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const activeOnly = req.query.active !== 'false';
    const definitions = await customFieldsService.listDefinitions(shopId, {
      activeOnly,
    });
    res.json(definitions);
  }

  async createDefinition(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const payload = createDefinitionSchema.parse(req.body);
    const created = await customFieldsService.createDefinition(shopId, payload);
    if ('error' in created) {
      res.status(400).json({ error: created.error });
      return;
    }
    res.status(201).json(created);
  }

  async updateDefinition(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = updateDefinitionSchema.parse(req.body);
    const updated = await customFieldsService.updateDefinition(shopId, id, {
      ...payload,
      options: payload.options ?? undefined,
      unitSuffix: payload.unitSuffix ?? undefined,
    });
    if (!updated) {
      res.status(404).json({ error: 'Definition not found' });
      return;
    }
    res.json(updated);
  }

  async deleteDefinition(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const result = await customFieldsService.softDeleteDefinition(shopId, id);
    if (!result) {
      res.status(404).json({ error: 'Definition not found' });
      return;
    }
    res.status(204).send();
  }

  async reorderDefinitions(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const { orderedIds } = reorderSchema.parse(req.body);
    const definitions = await customFieldsService.reorderDefinitions(
      shopId,
      orderedIds,
    );
    res.json(definitions);
  }

  async listValuesForProduct(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const productId = parseId(req.params.id);
    if (!productId) {
      res.status(400).json({ error: 'Invalid product id' });
      return;
    }
    const values = await customFieldsService.listValuesForProduct(shopId, productId);
    res.json(values);
  }

  async setValueForProduct(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const productId = parseId(req.params.id);
    const definitionId = parseId(req.params.definitionId);
    if (!productId || !definitionId) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const { value } = setValueSchema.parse(req.body);
    const result = await customFieldsService.setValue(
      shopId,
      productId,
      definitionId,
      value,
    );
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json(result);
  }

  async bulkSetValuesForProduct(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const productId = parseId(req.params.id);
    if (!productId) {
      res.status(400).json({ error: 'Invalid product id' });
      return;
    }
    const { values } = bulkValuesSchema.parse(req.body);
    const result = await customFieldsService.bulkSetValues(shopId, productId, values);
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json(result);
  }

  async deleteValueForProduct(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const productId = parseId(req.params.id);
    const definitionId = parseId(req.params.definitionId);
    if (!productId || !definitionId) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    await customFieldsService.deleteValue(shopId, productId, definitionId);
    res.status(204).send();
  }
}

export const customFieldsController = new CustomFieldsController();
