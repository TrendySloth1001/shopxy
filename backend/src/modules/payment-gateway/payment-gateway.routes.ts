import { Router } from 'express';
import express from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { paymentGatewayController } from './payment-gateway.controller.js';

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
