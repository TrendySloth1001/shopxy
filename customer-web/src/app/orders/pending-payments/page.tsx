"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import Link from "next/link";
import { ArrowLeft, CheckCircle } from "lucide-react";
import { AppHeader } from "@/features/auth/components/app-header";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { Snackbar, type SnackMessage } from "@/features/orders/components/snackbar";
import { fetchOrders, payForOrder, syncOrderPayment } from "@/features/orders/api";
import { openRazorpayCheckout } from "@/shared/razorpay";
import { formatINR } from "@/shared/format";
import { formatDateTime } from "@/shared/datetime";
import { orderNeedsOnlinePayment, orderPayableRemainder, type CustomerOrder } from "@/features/orders/types";

function PendingPaymentsContent() {
  const [orders, setOrders] = useState<CustomerOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [payingId, setPayingId] = useState<number | null>(null);
  const [snack, setSnack] = useState<SnackMessage | null>(null);
  const snackTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  function showSnack(s: SnackMessage) {
    setSnack(s);
    if (snackTimer.current) clearTimeout(snackTimer.current);
    snackTimer.current = setTimeout(() => setSnack(null), 4500);
  }

  const loadOrders = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await fetchOrders({ page: 1, limit: 50 });
      setOrders(result.data.filter(orderNeedsOnlinePayment));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load orders.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function run() { await loadOrders(); }
    if (!cancelled) void run();
    return () => { cancelled = true; };
  }, [loadOrders]);

  async function handlePay(order: CustomerOrder) {
    if (payingId !== null) return;
    setPayingId(order.id);
    try {
      const session = await payForOrder(order.id);
      const result = await openRazorpayCheckout(session, {
        description: `Order #${order.id}`,
      });
      let syncedStatus: string | null = null;
      if (result.outcome === "success") {
        try { syncedStatus = await syncOrderPayment(order.id); } catch { /* non-fatal */ }
      }
      if (result.outcome === "success") {
        const confirmed = syncedStatus === "PAID";
        showSnack({
          message: confirmed
            ? "Payment successful"
            : "Payment received — being confirmed. This can take a minute.",
          tone: confirmed ? "success" : "info",
        });
      } else if (result.outcome === "dismissed") {
        showSnack({
          message: "Payment not completed — nothing was charged. Pay whenever you're ready.",
          tone: "info",
        });
      } else {
        showSnack({
          message: `${result.message ?? "Payment failed"} — you can retry from here.`,
          tone: "error",
        });
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : "";
      const alreadyPaid = msg.includes("ALREADY_PAID") || msg.includes("already paid");
      showSnack({
        message: alreadyPaid ? "This order is already paid" : `Could not start payment: ${msg}`,
        tone: alreadyPaid ? "info" : "error",
      });
    } finally {
      setPayingId(null);
      await loadOrders();
    }
  }

  if (loading) {
    return (
      <div className="px-lg py-xl space-y-md animate-pulse">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="flex items-center justify-between">
            <div className="space-y-xs">
              <div className="h-3 w-20 rounded bg-surface-tint" />
              <div className="h-5 w-28 rounded bg-surface-tint" />
            </div>
            <div className="h-9 w-24 rounded-button bg-surface-tint" />
          </div>
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="py-massive px-lg text-center">
        <p className="text-body-md text-muted mb-xl">{error}</p>
        <button
          onClick={() => void loadOrders()}
          className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
        >
          Try again
        </button>
      </div>
    );
  }

  if (orders.length === 0) {
    return (
      <div className="flex flex-col items-center py-massive px-lg text-center">
        <CheckCircle size={52} className="text-success mb-md" />
        <p className="text-title-sm font-extrabold text-ink">You&apos;re all paid up</p>
        <p className="mt-xs text-body-md text-muted">No orders are waiting on a payment right now.</p>
      </div>
    );
  }

  const total = orders.reduce((sum, o) => sum + orderPayableRemainder(o), 0);

  return (
    <>
      {/* Total due header */}
      <div className="px-lg py-lg">
        <p className="text-[11px] font-extrabold tracking-[0.8px] text-muted uppercase">Total due</p>
        <p className="text-display-sm font-extrabold text-ink tracking-tight">
          {formatINR(total, { decimals: 2 })}
        </p>
      </div>
      <div className="h-px bg-hairline" />

      {orders.map((order) => (
        <div key={order.id}>
          <div className="flex items-center gap-md px-lg py-lg">
            <Link
              href={`/orders/${order.id}`}
              className="flex-1 min-w-0 hover:opacity-80 focus-visible:outline-none focus-visible:underline"
            >
              <p className="text-body-sm font-semibold text-muted">
                Order #{order.id} · {formatDateTime(order.createdAt)}
              </p>
              <p className="text-title-sm font-extrabold text-ink tracking-tight">
                {formatINR(orderPayableRemainder(order), { decimals: 2 })}
              </p>
            </Link>
            <button
              onClick={() => void handlePay(order)}
              disabled={payingId !== null}
              className="inline-flex h-9 flex-shrink-0 items-center gap-sm rounded-button bg-ink px-lg text-label-md font-extrabold text-white disabled:opacity-60 hover:bg-ink/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
            >
              {payingId === order.id && (
                <span className="h-3 w-3 rounded-full border-2 border-white/30 border-t-white animate-spin" />
              )}
              Pay now
            </button>
          </div>
          <div className="h-px bg-hairline" />
        </div>
      ))}

      <Snackbar snack={snack} />
    </>
  );
}

export default function PendingPaymentsPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <main className="min-h-screen bg-canvas">
        <div className="mx-auto max-w-shell px-lg pt-md pb-xs flex items-center gap-sm">
          <Link
            href="/orders"
            className="flex h-8 w-8 items-center justify-center rounded-full text-muted hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
          >
            <ArrowLeft size={16} />
          </Link>
          <h1 className="text-title-md font-extrabold text-ink">Pending Payments</h1>
        </div>
        <div className="mx-auto max-w-shell">
          <PendingPaymentsContent />
        </div>
      </main>
    </RequireAuth>
  );
}
