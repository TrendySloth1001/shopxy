import type { PaymentGatewayPort } from '../ports/payment-provider.port.js';
import { RazorpayProvider } from './razorpay.provider.js';

let cache: Map<string, PaymentGatewayPort> | null = null;

function providers(): Map<string, PaymentGatewayPort> {
  if (cache) return cache;
  const m = new Map<string, PaymentGatewayPort>();

  if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET) {
    m.set('RAZORPAY', new RazorpayProvider());
  }

  cache = m;
  return m;
}

export function getProvider(name: string): PaymentGatewayPort {
  const p = providers().get(name.toUpperCase());
  if (!p) {
    throw Object.assign(new Error(`Payment provider not enabled: ${name}`), {
      status: 400,
    });
  }
  return p;
}

export function listEnabledProviders(): string[] {
  return Array.from(providers().keys());
}

export function resetProviderRegistry(): void {
  cache = null;
}
