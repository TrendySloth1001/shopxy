import { PaymentGatewayService } from './payment-gateway.service.js';
import {
  gatewayPaymentRepository,
  gatewayRefundRepository,
  webhookEventRepository,
} from './persistence/prisma-gateway.repository.js';

export const paymentGatewayService = new PaymentGatewayService(
  gatewayPaymentRepository,
  webhookEventRepository,
  gatewayRefundRepository,
);

export { listEnabledProviders } from './providers/registry.js';
