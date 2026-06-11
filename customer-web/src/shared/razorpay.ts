/**
 * Razorpay Web SDK loader + checkout wrapper.
 *
 * Mirrors the Flutter `RazorpayCheckout` class in
 * `customer/lib/features/payments/razorpay_checkout.dart`:
 *   - Script is injected once and reused.
 *   - `openRazorpayCheckout` consumes the exact `clientParams` shape that
 *     `POST /me/orders/:id/pay` returns.
 *   - Outcome is 'success' | 'dismissed' | 'failed', matching the Flutter enum.
 *
 * IMPORTANT: a 'success' result here is the client-side handshake only.
 * The backend webhook / `POST /me/orders/:id/payment/sync` is the authoritative
 * settlement path — treat success as "sheet completed, now sync the order".
 */

/** Minimal type for the Razorpay constructor available after the script loads. */
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
  modal?: {
    ondismiss?: () => void;
  };
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

/** The fields the backend returns inside `clientParams` from `POST /me/orders/:id/pay`. */
export interface RazorpayClientParams {
  key: string;
  order_id: string;
  /** Paise (minor units). */
  amount: number;
  currency?: string;
}

/** Full pay-session envelope as returned by the BFF pay endpoint. */
export interface PaySession {
  intentId: number;
  provider: "RAZORPAY";
  providerOrderRef: string;
  /** Rupees (major units). */
  amount: number;
  currency: "INR";
  clientParams: RazorpayClientParams;
  reused: boolean;
}

export type RazorpayOutcome = "success" | "dismissed" | "failed";

export interface RazorpayResult {
  outcome: RazorpayOutcome;
  /** Razorpay `rzp_pay_…` id — client UX only; not the authoritative source. */
  paymentId?: string;
  message?: string;
}

const CDN = "https://checkout.razorpay.com/v1/checkout.js";
let scriptPromise: Promise<void> | null = null;

/**
 * Injects the Razorpay checkout.js script once and resolves when it is ready.
 * Subsequent calls reuse the in-flight or completed promise.
 */
export function loadRazorpay(): Promise<void> {
  if (scriptPromise) return scriptPromise;
  // Script already injected by a previous page render.
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
      scriptPromise = null; // allow a retry
      reject(new Error("Failed to load Razorpay checkout script."));
    };
    document.head.appendChild(script);
  });
  return scriptPromise;
}

export interface OpenCheckoutOpts {
  /** Called when the sheet completes successfully. */
  onSuccess?: (result: RazorpayResult) => void;
  /** Called when the user closes the sheet without paying. */
  onDismiss?: () => void;
  /** Called on a payment failure (not a dismiss). */
  onFailure?: (result: RazorpayResult) => void;
  /** Display name shown inside the Razorpay modal. Defaults to "ShopXY". */
  name?: string;
  description?: string;
  prefillEmail?: string;
  prefillContact?: string;
}

/**
 * Load the Razorpay SDK (once) and open the payment sheet for the given session.
 *
 * Resolves to the outcome after the sheet closes.
 * Consumes the exact `clientParams` shape from `POST /me/orders/:id/pay`.
 */
export async function openRazorpayCheckout(
  session: PaySession,
  opts: OpenCheckoutOpts = {},
): Promise<RazorpayResult> {
  await loadRazorpay();

  if (!window.Razorpay) {
    throw new Error("Razorpay SDK failed to initialise.");
  }

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
      amount: clientParams.amount, // paise
      currency: clientParams.currency ?? "INR",
      name: opts.name ?? "ShopXY",
      description: opts.description,
      prefill: {
        email: opts.prefillEmail,
        contact: opts.prefillContact,
      },
      retry: { enabled: true, max_count: 1 },
      handler: (response: RazorpaySuccessResponse) => {
        const result: RazorpayResult = {
          outcome: "success",
          paymentId: response.razorpay_payment_id,
        };
        opts.onSuccess?.(result);
        finish(result);
      },
      modal: {
        ondismiss: () => {
          // ondismiss fires for both user-dismiss and payment failure; we
          // distinguish via the `payment.failed` event below (which fires first).
          if (!settled) {
            opts.onDismiss?.();
            finish({ outcome: "dismissed" });
          }
        },
      },
    });

    // Razorpay fires this event before ondismiss on a payment failure.
    rzp.on(
      "payment.failed",
      (response: { error: { code: string; description: string } }) => {
        const result: RazorpayResult = {
          outcome: "failed",
          message: response.error?.description,
        };
        opts.onFailure?.(result);
        finish(result);
      },
    );

    rzp.open();
  });
}
