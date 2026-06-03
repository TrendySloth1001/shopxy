/**
 * Provider registry — resolves a provider name to its adapter, gated on env.
 *
 * A gateway is only enabled when its credentials are present. Adding a second
 * gateway is exactly two lines here (the import + the register call) plus the
 * adapter file. Nothing in the core or other adapters changes — that is the
 * whole point of the ports/adapters split.
 */
import type { PaymentGatewayPort } from '../ports/payment-provider.port.js';
import { RazorpayProvider } from './razorpay.provider.js';

let cache: Map<string, PaymentGatewayPort> | null = null;

/** Lazily build the map once, so missing env doesn't throw at import time. */
function providers(): Map<string, PaymentGatewayPort> {
  if (cache) return cache;
  const m = new Map<string, PaymentGatewayPort>();

  if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET) {
    m.set('RAZORPAY', new RazorpayProvider());
  }
  // To add Stripe later:
  //   if (process.env.STRIPE_SECRET_KEY) m.set('STRIPE', new StripeProvider());

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

/** Test seam — forget the cached map (e.g. after mutating env in a test). */
export function resetProviderRegistry(): void {
  cache = null;
}
