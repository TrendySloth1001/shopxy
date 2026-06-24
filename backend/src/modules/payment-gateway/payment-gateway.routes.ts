import { Router } from 'express';
import express from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { paymentGatewayController } from './payment-gateway.controller.js';

/**
 * Authenticated, customer-facing top-up surfaces. Mount AFTER requireAuth.
 * Suggested mount: app.use('/me/wallet/topup', walletTopUpRouter) next to the
 * existing '/me/wallet' mount (app.ts).
 *
 * WALLET DEPRECATION — top-up is DISABLED. Loading real money into a spendable
 * in-app wallet makes it a semi-closed Prepaid Payment Instrument, which needs
 * RBI authorization under the PSS Act, 2007 / PPI Master Direction. The wallet
 * is being removed; no new money may enter it. The POST returns 410 Gone. The
 * GET stays so a client can still resolve an intent created before this change.
 */
export const walletTopUpRouter = Router();
walletTopUpRouter.post('/', (_req, res) => {
  res.status(410).json({
    error: 'WALLET_DISABLED',
    message:
      'Wallet top-up has been removed. Payments are made directly via the gateway.',
  });
});
walletTopUpRouter.get(
  '/:id',
  asyncHandler((req, res) => paymentGatewayController.getIntent(req, res)),
);

/**
 * Public webhook + meta surfaces. The webhook is UNAUTHENTICATED (verified by
 * signature) and needs the RAW body — so it carries its own express.raw() and
 * MUST be mounted BEFORE the global express.json() and BEFORE requireAuth.
 * Suggested mount: app.use('/payment-gateway', paymentGatewayPublicRouter)
 * high up in app.ts (near the other pre-auth mounts).
 */
export const paymentGatewayPublicRouter = Router();
paymentGatewayPublicRouter.post(
  '/webhook/:provider',
  express.raw({ type: '*/*', limit: '1mb' }),
  asyncHandler((req, res) => paymentGatewayController.webhook(req, res)),
);
paymentGatewayPublicRouter.get(
  '/providers',
  asyncHandler((req, res) => paymentGatewayController.providers(req, res)),
);
