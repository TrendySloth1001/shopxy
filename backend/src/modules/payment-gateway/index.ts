/**
 * Module composition root. Wires the core service to the Prisma persistence.
 * Controllers import `paymentGatewayService` from here.
 */
import { PaymentGatewayService } from './payment-gateway.service.js';
import {
  gatewayPaymentRepository,
  webhookEventRepository,
} from './persistence/prisma-gateway.repository.js';

export const paymentGatewayService = new PaymentGatewayService(
  gatewayPaymentRepository,
  webhookEventRepository,
);

export { listEnabledProviders } from './providers/registry.js';
