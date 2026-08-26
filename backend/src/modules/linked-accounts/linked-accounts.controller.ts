import type { Request, Response } from 'express';
import { z } from 'zod';
import { linkedAccountsService } from './linked-accounts.service.js';

const PAN = /^[A-Z]{5}[0-9]{4}[A-Z]$/;
const GST = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z][Z][0-9A-Z]$/;

const startSchema = z.object({
  email: z.string().email(),
  phone: z.string().min(8).max(15),
  legalBusinessName: z.string().min(1).max(200),
  customerFacingBusinessName: z.string().min(1).max(255).optional(),
  businessType: z.string().min(1).max(40),
  contactName: z.string().min(1).max(120),
  category: z.string().min(1).max(40),
  subcategory: z.string().min(1).max(40).optional(),
  pan: z.string().trim().toUpperCase().pipe(z.string().regex(PAN, 'invalid PAN')),
  gst: z
    .string()
    .trim()
    .toUpperCase()
    .pipe(z.string().regex(GST, 'invalid GST'))
    .optional(),
  registeredAddress: z.object({
    street1: z.string().min(1).max(255),
    street2: z.string().min(1).max(255).optional(),
    city: z.string().min(1).max(120),
    state: z.string().min(1).max(120),
    postalCode: z.string().regex(/^\d{6}$/, 'invalid PIN code'),
    country: z.string().length(2).default('IN'),
  }),
  beneficiaryName: z.string().min(1).max(120),
  bankAccountNumber: z.string().min(6).max(20).regex(/^\d+$/, 'digits only'),
  bankIfsc: z.string().regex(/^[A-Z]{4}0[A-Z0-9]{6}$/, 'invalid IFSC'),
});

const connectSchema = z.object({
  accountId: z.string().trim().regex(/^acc_[A-Za-z0-9]+$/, 'invalid account id'),
});

export const linkedAccountsController = {
  async start(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId;
    if (shopId == null) {
      res.status(403).json({ error: 'No shop linked to this account.' });
      return;
    }
    const parsed = startSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid onboarding details', details: parsed.error.flatten() });
      return;
    }
    const result = await linkedAccountsService.startOnboarding({ shopId, ...parsed.data });
    if ('error' in result) {
      res.status(503).json({ error: 'Onboarding is not available (payment provider not configured).' });
      return;
    }
    res.status(201).json(result.account);
  },

  async connectVerify(req: Request, res: Response): Promise<void> {
    if (req.shopId == null) {
      res.status(403).json({ error: 'No shop linked to this account.' });
      return;
    }
    const parsed = connectSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid account id (expected acc_…).' });
      return;
    }
    const result = await linkedAccountsService.verifyConnect(parsed.data.accountId);
    if ('error' in result) {
      res
        .status(result.error === 'PROVIDER_UNAVAILABLE' ? 503 : 404)
        .json({
          error:
            result.error === 'PROVIDER_UNAVAILABLE'
              ? 'Payouts are not available (payment provider not configured).'
              : "That account wasn't found, or isn't linked to ShopXY.",
        });
      return;
    }
    res.json(result.details);
  },

  async connectConfirm(req: Request, res: Response): Promise<void> {
    if (req.shopId == null) {
      res.status(403).json({ error: 'No shop linked to this account.' });
      return;
    }
    const parsed = connectSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid account id (expected acc_…).' });
      return;
    }
    const result = await linkedAccountsService.confirmConnect(req.shopId, parsed.data.accountId);
    if ('error' in result) {
      const status = result.error === 'PROVIDER_UNAVAILABLE' ? 503 : result.error === 'ALREADY_LINKED' ? 409 : 404;
      const error =
        result.error === 'PROVIDER_UNAVAILABLE'
          ? 'Payouts are not available (payment provider not configured).'
          : result.error === 'ALREADY_LINKED'
            ? 'This shop already has a different payout account linked.'
            : "That account wasn't found, or isn't linked to ShopXY.";
      res.status(status).json({ error });
      return;
    }
    res.status(201).json(result.account);
  },

  async status(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId;
    if (shopId == null) {
      res.status(403).json({ error: 'No shop linked to this account.' });
      return;
    }
    const account =
      req.query.refresh === '1'
        ? await linkedAccountsService.refreshStatus(shopId)
        : await linkedAccountsService.getStatus(shopId);
    if (!account) {
      res.status(404).json({ error: 'No linked account — onboarding not started.' });
      return;
    }
    res.json(account);
  },
};
