import { Request, Response } from 'express';
import { decodeId } from '../../shared/ids/publicId.js';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { z } from 'zod';
import { couponsService, type DiscountType } from './coupons.service.js';

const validateSchema = z.object({
  code: z.string().min(1).max(40),
  subtotal: z.number().nonnegative(),
  shopIds: z.array(zPublicId).max(40).default([]),
});

const ERROR_MESSAGES: Record<string, string> = {
  NOT_FOUND: "This code isn't valid.",
  INACTIVE: 'This coupon has been disabled.',
  NOT_STARTED: 'This coupon isn\'t active yet.',
  EXPIRED: 'This coupon has expired.',
  MIN_ORDER_NOT_MET: 'Your cart doesn\'t meet the minimum order for this coupon.',
  SHOP_NOT_IN_CART: 'This coupon only applies to specific sellers.',
  PER_USER_LIMIT_REACHED: 'You\'ve already used this coupon.',
  TOTAL_CAP_REACHED: 'This coupon has run out.',
  NOT_FIRST_ORDER: 'This coupon is only for first-time customers.',
};

export class CouponsController {
  /// GET /me/coupons — list available coupons for the caller.
  async listAvailable(req: Request, res: Response): Promise<void> {
    const data = await couponsService.listAvailableForUser(req.user!.sub);
    res.json({ data });
  }

  /// POST /me/coupons/auto-apply — given the current cart context,
  /// returns the single best PUBLIC coupon (if any) so the checkout
  /// page can pre-apply it without the customer typing a code. Public
  /// coupons are the "everyone-gets-this" use-case; making the
  /// customer copy a code that's already in their carousel was the
  /// "coupons not working" complaint.
  async autoApply(req: Request, res: Response): Promise<void> {
    const payload = autoApplySchema.parse(req.body);
    const result = await couponsService.pickBestPublicForCart({
      userId: req.user!.sub,
      subtotal: payload.subtotal,
      shopIds: payload.shopIds,
    });
    if (result == null) {
      res.json({ ok: false });
      return;
    }
    res.json({ ok: true, coupon: result.coupon });
  }

  /// POST /me/coupons/validate — preview the discount without applying.
  async validate(req: Request, res: Response): Promise<void> {
    const payload = validateSchema.parse(req.body);
    const result = await couponsService.validate({
      userId: req.user!.sub,
      code: payload.code,
      context: { subtotal: payload.subtotal, shopIds: payload.shopIds },
    });
    if ('error' in result) {
      res.status(400).json({
        ok: false,
        code: result.error,
        message: ERROR_MESSAGES[result.error] ?? result.error,
      });
      return;
    }
    res.json({ ok: true, coupon: result.coupon });
  }

  // ── Merchant ──────────────────────────────────────────────────────

  /// GET /me/coupons-admin — every coupon attached to the caller's shop.
  async listMerchant(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const data = await couponsService.listForShop(shopId);
    res.json({ data });
  }

  async getMerchant(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const id = decodeId(req.params.id);
    if (id === null) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const coupon = await couponsService.getForShop(shopId, id);
    if (!coupon) {
      res.status(404).json({ error: 'Coupon not found' });
      return;
    }
    res.json(coupon);
  }

  async redemptionsMerchant(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const id = decodeId(req.params.id);
    if (id === null) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const rows = await couponsService.redemptionsForShop(shopId, id);
    if (rows === null) {
      res.status(404).json({ error: 'Coupon not found' });
      return;
    }
    res.json({ data: rows });
  }

  async createMerchant(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const payload = writeSchema.parse(req.body);
    const result = await couponsService.createForShop(shopId, {
      ...payload,
      discountType: payload.discountType as DiscountType,
      validFrom: new Date(payload.validFrom),
      validUntil: new Date(payload.validUntil),
    });
    if ('error' in result) {
      res.status(result.error === 'CODE_TAKEN' ? 409 : 400).json(result);
      return;
    }
    res.status(201).json(result);
  }

  async updateMerchant(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const id = decodeId(req.params.id);
    if (id === null) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = patchSchema.parse(req.body);
    const result = await couponsService.updateForShop(shopId, id, {
      ...payload,
      discountType: payload.discountType
        ? (payload.discountType as DiscountType)
        : undefined,
      validFrom: payload.validFrom ? new Date(payload.validFrom) : undefined,
      validUntil: payload.validUntil ? new Date(payload.validUntil) : undefined,
    });
    if ('error' in result) {
      res.status(result.error === 'NOT_FOUND' ? 404 : 400).json(result);
      return;
    }
    res.status(204).send();
  }

  async deactivateMerchant(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const id = decodeId(req.params.id);
    if (id === null) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const result = await couponsService.deactivateForShop(shopId, id);
    if ('error' in result) {
      res.status(404).json(result);
      return;
    }
    res.status(204).send();
  }
}

const writeSchema = z.object({
  code: z.string().min(2).max(40),
  title: z.string().min(1).max(120),
  description: z.string().max(2000).nullable().optional(),
  discountType: z.enum(['PERCENT', 'FLAT']),
  discountValue: z.number().positive(),
  maxDiscount: z.number().positive().nullable().optional(),
  minOrderAmount: z.number().nonnegative().optional(),
  validFrom: z.string().datetime(),
  validUntil: z.string().datetime(),
  perUserLimit: z.number().int().min(0).max(1000).optional(),
  totalCap: z.number().int().min(0).optional(),
  isPublic: z.boolean().optional(),
  firstOrderOnly: z.boolean().optional(),
  isActive: z.boolean().optional(),
});
const patchSchema = writeSchema.partial();

const autoApplySchema = z.object({
  subtotal: z.number().nonnegative(),
  shopIds: z.array(zPublicId).max(40).default([]),
});

export const couponsController = new CouponsController();
