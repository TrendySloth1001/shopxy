declare global {
  interface Window {
    Razorpay?: new (opts: RazorpayOptions) => RazorpayInstance;
  }
}

interface RazorpayOptions {
  key: string;
  order_id: string;
  amount: number;
  currency: string;
  name?: string;
  description?: string;
  prefill?: { email?: string; contact?: string };
  retry?: { enabled: boolean; max_count: number };
  handler?: (response: RazorpaySuccessResponse) => void;
  modal?: { ondismiss?: () => void };
  theme?: { color?: string };
}

interface RazorpaySuccessResponse {
  razorpay_payment_id: string;
  razorpay_order_id: string;
  razorpay_signature: string;
}

interface RazorpayInstance {
  open(): void;
  on(event: string, handler: (response: { error: { code: string; description: string } }) => void): void;
}

export interface RazorpayClientParams {
  key: string;
  order_id: string;
  amount: number;
  currency?: string;
}

export interface PaySession {
  intentId: string;
  provider: string;
  providerOrderRef: string;
  amount: number;
  currency: string;
  clientParams: RazorpayClientParams;
  reused: boolean;
}

export type RazorpayOutcome = "success" | "dismissed" | "failed";

export interface RazorpayResult {
  outcome: RazorpayOutcome;
  paymentId?: string;
  message?: string;
}

const CDN = "https://checkout.razorpay.com/v1/checkout.js";
let scriptPromise: Promise<void> | null = null;

export function loadRazorpay(): Promise<void> {
  if (scriptPromise) return scriptPromise;
  if (typeof window !== "undefined" && window.Razorpay) {
    scriptPromise = Promise.resolve();
    return scriptPromise;
  }
  scriptPromise = new Promise<void>((resolve, reject) => {
    const script = document.createElement("script");
    script.src = CDN;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => {
      scriptPromise = null;
      reject(new Error("Failed to load Razorpay checkout script."));
    };
    document.head.appendChild(script);
  });
  return scriptPromise;
}

export interface OpenCheckoutOpts {
  onSuccess?: (result: RazorpayResult) => void;
  onDismiss?: () => void;
  onFailure?: (result: RazorpayResult) => void;
  name?: string;
  description?: string;
}

export async function openRazorpayCheckout(
  session: PaySession,
  opts: OpenCheckoutOpts = {},
): Promise<RazorpayResult> {
  await loadRazorpay();
  if (!window.Razorpay) throw new Error("Razorpay SDK failed to initialise.");

  const { clientParams } = session;

  return new Promise<RazorpayResult>((resolve) => {
    let settled = false;
    function finish(result: RazorpayResult) {
      if (settled) return;
      settled = true;
      resolve(result);
    }

    const rzp = new window.Razorpay!({
      key: clientParams.key,
      order_id: clientParams.order_id,
      amount: clientParams.amount,
      currency: clientParams.currency ?? "INR",
      name: opts.name ?? "ShopXY",
      description: opts.description,
      retry: { enabled: true, max_count: 1 },
      handler: (response: RazorpaySuccessResponse) => {
        const result: RazorpayResult = { outcome: "success", paymentId: response.razorpay_payment_id };
        opts.onSuccess?.(result);
        finish(result);
      },
      modal: {
        ondismiss: () => {
          if (!settled) {
            opts.onDismiss?.();
            finish({ outcome: "dismissed" });
          }
        },
      },
    });

    rzp.on("payment.failed", (response: { error: { code: string; description: string } }) => {
      const result: RazorpayResult = { outcome: "failed", message: response.error?.description };
      opts.onFailure?.(result);
      finish(result);
    });

    rzp.open();
  });
}
