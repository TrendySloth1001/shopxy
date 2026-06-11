"use client";

import { use, useState, useCallback, useEffect, useRef } from "react";
import Link from "next/link";
import { ArrowLeft, MapPin, Store, Download, Info, RotateCcw, X } from "lucide-react";
import { AppHeader } from "@/features/auth/components/app-header";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { OrderTimeline } from "@/features/orders/components/order-timeline";
import { OrderDetailSkeleton } from "@/features/orders/components/order-skeleton";
import { ShopOrderStatusChip, aggregateStatusHeadline } from "@/features/orders/components/status-chip";
import { Snackbar, type SnackMessage } from "@/features/orders/components/snackbar";
import { RequestReturnDialog } from "@/features/returns/components/request-return-dialog";
import {
  fetchOrderDetail,
  cancelShopOrder,
  reorderOrder,
  payForOrder,
  syncOrderPayment,
  invoicePdfUrl,
} from "@/features/orders/api";
import { openRazorpayCheckout } from "@/shared/razorpay";
import { formatINR } from "@/shared/format";
import { setCartQty } from "@/features/cart/api";
import type { CustomerOrderDetail, ShopOrderDetail } from "@/features/orders/types";
import { orderNeedsOnlinePayment, orderPayableRemainder } from "@/features/orders/types";

// ─── Helpers ─────────────────────────────────────────────────────────────────

function cancelUnavailableNote(child: ShopOrderDetail): string | null {
  if (child.canCancel) return null;
  if (child.status !== "CONFIRMED") return null;
  if (child.deliveredAt) return null;
  const why =
    child.cancellationPolicy === "UNTIL_CONFIRMED"
      ? "this shop accepts cancellations only until it confirms the order"
      : child.cancellationPolicy === "UNTIL_PACKED"
        ? "this shop accepts cancellations only until the order is packed"
        : child.cancellationPolicy === "UNTIL_SHIPPED"
          ? "this shop accepts cancellations only until the order is shipped"
          : "the shop's cancellation window has passed";
  return `This order can no longer be cancelled — ${why}.`;
}

function returnUnavailableNote(child: ShopOrderDetail): string | null {
  if (child.canReturn) return null;
  if (child.status !== "CONFIRMED") return null;
  if (!child.deliveredAt) return null;
  const shop = child.shop;
  if (!shop) return null;
  if (!shop.returnsEnabled) return "This shop doesn't accept returns.";
  const windowEnd = new Date(
    new Date(child.deliveredAt).getTime() + shop.returnWindowDays * 86400000,
  );
  if (new Date() > windowEnd)
    return `The ${shop.returnWindowDays}-day return window for this order has closed.`;
  return null;
}

function isReorderable(order: CustomerOrderDetail): boolean {
  return order.shopOrders.some(
    (c) => c.items.length > 0 && ["CONFIRMED", "REJECTED", "CANCELLED"].includes(c.status),
  );
}

// ─── Detail page ─────────────────────────────────────────────────────────────

// Map ?toast= values from the checkout redirect
function toastFromParam(toast: string | undefined): SnackMessage | null {
  switch (toast) {
    case "payment_success":
      return { message: "Payment successful — order confirmed.", tone: "success" };
    case "payment_pending":
      return { message: "Payment received — being confirmed. This can take a minute.", tone: "info" };
    case "payment_dismissed":
      return { message: "Payment not completed — nothing was charged. Tap \"Pay Now\" whenever you're ready.", tone: "info" };
    case "payment_failed":
      return { message: "Payment failed — please try again.", tone: "error" };
    default:
      return null;
  }
}

function OrderDetailContent({
  orderId,
  initialToast,
}: {
  orderId: number;
  initialToast?: string;
}) {
  const [order, setOrder] = useState<CustomerOrderDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [cancellingChildId, setCancellingChildId] = useState<number | null>(null);
  const [cancelConfirmChild, setCancelConfirmChild] = useState<ShopOrderDetail | null>(null);
  const [reordering, setReordering] = useState(false);
  const [paying, setPaying] = useState(false);
  const payingRef = useRef(false);
  const [returnDialogChild, setReturnDialogChild] = useState<ShopOrderDetail | null>(null);
  const [snack, setSnack] = useState<SnackMessage | null>(() => toastFromParam(initialToast));
  const snackTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  function showSnack(s: SnackMessage) {
    setSnack(s);
    if (snackTimer.current) clearTimeout(snackTimer.current);
    snackTimer.current = setTimeout(() => setSnack(null), 4500);
  }

  // Auto-clear the initial (checkout redirect) toast after the same duration
  const initialToastRef = useRef(initialToast);
  useEffect(() => {
    if (!initialToastRef.current) return;
    const t = setTimeout(() => setSnack(null), 4500);
    return () => clearTimeout(t);
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const o = await fetchOrderDetail(orderId);
      setOrder(o);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load order.");
    } finally {
      setLoading(false);
    }
  }, [orderId]);

  useEffect(() => {
    let cancelled = false;
    async function run() {
      await load();
    }
    if (!cancelled) void run();
    return () => { cancelled = true; };
  }, [load]);

  // ── Cancel child ────────────────────────────────────────────────────────
  async function doCancel(child: ShopOrderDetail) {
    setCancelConfirmChild(null);
    setCancellingChildId(child.id);
    const sellerName = child.shop?.shopName ?? child.shop?.name ?? "this seller";
    try {
      await cancelShopOrder(orderId, child.id);
      showSnack({ message: `Items from ${sellerName} cancelled`, tone: "success" });
      await load();
    } catch (e) {
      const err = e as Error & { code?: string };
      if (err.code === "NOT_CANCELLABLE") {
        showSnack({
          message: err.message || "This order has passed the shop's cancellation window.",
          tone: "info",
        });
        await load();
      } else {
        showSnack({ message: err.message || "Could not cancel.", tone: "error" });
      }
    } finally {
      setCancellingChildId(null);
    }
  }

  // ── Reorder ──────────────────────────────────────────────────────────────
  async function handleReorder() {
    if (reordering) return;
    setReordering(true);
    try {
      const result = await reorderOrder(orderId);
      if (result.items.length === 0) {
        showSnack({ message: "None of the items are available right now", tone: "error" });
        return;
      }
      // Sync to server cart — best-effort
      for (const item of result.items) {
        try { await setCartQty(item.productId, item.quantity); } catch { /* skip unavailable */ }
      }
      const added = result.items.length;
      const skipped = result.skipped.length;
      const msg =
        skipped === 0
          ? `${added} ${added === 1 ? "item" : "items"} added to cart`
          : `${added} added · ${skipped} unavailable`;
      showSnack({ message: msg, tone: "success" });
    } catch (e) {
      showSnack({ message: e instanceof Error ? e.message : "Could not reorder.", tone: "error" });
    } finally {
      setReordering(false);
    }
  }

  // ── Pay now ───────────────────────────────────────────────────────────────
  async function handlePayNow() {
    if (payingRef.current || !order) return;
    payingRef.current = true;
    setPaying(true);
    try {
      const session = await payForOrder(orderId);
      const result = await openRazorpayCheckout(session, {
        description: `Order #${orderId}`,
      });
      let syncedStatus: string | null = null;
      if (result.outcome === "success") {
        try { syncedStatus = await syncOrderPayment(orderId); } catch { /* non-fatal */ }
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
          message: "Payment not completed — nothing was charged. Tap \"Pay Now\" whenever you're ready.",
          tone: "info",
        });
      } else {
        showSnack({
          message: `${result.message ?? "Payment failed"} — you can retry with "Pay Now".`,
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
      payingRef.current = false;
      setPaying(false);
      await load();
    }
  }

  if (loading && !order) {
    return <OrderDetailSkeleton />;
  }

  if (error && !order) {
    return (
      <div className="py-massive px-lg text-center">
        <p className="text-title-sm font-bold text-ink mb-xs">Something went wrong</p>
        <p className="text-body-sm text-muted mb-xl">{error}</p>
        <button
          onClick={() => void load()}
          className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
        >
          Try again
        </button>
      </div>
    );
  }

  if (!order) return null;

  const needsPayment = orderNeedsOnlinePayment(order);
  const payable = orderPayableRemainder(order);
  const reorderable = isReorderable(order);
  const statusVis = aggregateStatusHeadline(order);
  const StatusIcon = statusVis.Icon;
  const children = order.shopOrders;
  const hasAddress = !!order.customerAddress?.trim();
  const hasNote = !!order.note?.trim();

  // Order total: prefer invoiced amounts
  let orderTotal = 0;
  let usedInvoices = false;
  for (const c of children) {
    if (c.invoice) {
      orderTotal += c.invoice.total;
      usedInvoices = true;
    } else if (c.status !== "CANCELLED" && c.status !== "REJECTED") {
      orderTotal += c.estimatedTotal;
    }
  }

  return (
    <>
      {/* Delivery section */}
      {hasAddress && (
        <>
          <SectionLabel text="DELIVERING TO" />
          <div className="flex items-start gap-sm px-lg py-xs pb-md">
            <MapPin size={16} className="text-muted mt-[2px] flex-shrink-0" />
            <div>
              <p className="text-body-md font-extrabold text-ink">{order.customerName}</p>
              <p className="text-body-sm text-muted whitespace-pre-line">{order.customerAddress}</p>
              {order.customerPhone && (
                <p className="mt-xs text-body-sm text-muted">{order.customerPhone}</p>
              )}
            </div>
          </div>
          <div className="h-px bg-hairline" />
        </>
      )}

      {/* Multiple packages eyebrow */}
      {children.length > 1 && (
        <SectionLabel
          text={`${children.length} PACKAGES · ${order.shopOrders.reduce((s, c) => s + c.items.length, 0)} ITEMS`}
        />
      )}

      {/* Per-vendor sections */}
      {children.map((child, i) => (
        <div key={child.id}>
          {i > 0 && <div className="h-px bg-hairline" />}
          <ShopSection
            child={child}
            packageIndex={children.length > 1 ? i + 1 : undefined}
            packageCount={children.length}
            cancelling={cancellingChildId === child.id}
            parentOrderId={orderId}
            onCancel={() => setCancelConfirmChild(child)}
            onRequestReturn={() => setReturnDialogChild(child)}
          />
        </div>
      ))}

      <div className="h-px bg-hairline" />

      {/* Buy again */}
      {reorderable && (
        <>
          <div className="flex items-center justify-between px-lg py-md">
            <div className="flex items-center gap-md">
              <RotateCcw size={20} className="text-brand flex-shrink-0" />
              <div>
                <p className="text-body-md font-extrabold text-ink">Buy again</p>
                <p className="text-body-sm text-muted">Adds items from this order to your cart</p>
              </div>
            </div>
            <button
              onClick={() => void handleReorder()}
              disabled={reordering}
              className="inline-flex h-9 items-center gap-sm rounded-button bg-ink px-md text-label-md font-extrabold text-white disabled:opacity-60 hover:bg-ink/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors flex-shrink-0"
            >
              {reordering && (
                <span className="h-4 w-4 rounded-full border-2 border-white/30 border-t-white animate-spin" />
              )}
              Add to cart
            </button>
          </div>
          <div className="h-px bg-hairline" />
        </>
      )}

      {/* Order summary */}
      <SectionLabel text="ORDER SUMMARY" />
      <div className="px-lg pb-md">
        {/* Aggregate status row */}
        <div className="mb-sm flex items-center gap-sm">
          <StatusIcon size={14} className={statusVis.colorClass} />
          <p className={`text-body-md font-extrabold flex-1 ${statusVis.colorClass}`}>
            {statusVis.headline}
          </p>
          {statusVis.subtext && (
            <span className={`text-label-sm font-bold ${statusVis.colorClass}`}>
              {statusVis.subtext}
            </span>
          )}
        </div>
        <div className="h-px bg-hairline mb-sm" />
        <BillRow label="Items total" value={orderTotal} />
        <BillRow label="Delivery" valueLabel="FREE" valueLabelClass="text-success" />
        {(order.couponDiscount ?? 0) > 0 && (
          <BillRow label="Coupon discount" value={-(order.couponDiscount ?? 0)} />
        )}
        {(order.walletPaid ?? 0) > 0 && (
          <BillRow label="Wallet applied" value={-(order.walletPaid ?? 0)} />
        )}
        <div className="my-md h-px bg-hairline" />
        {(() => {
          // When invoices are used, orderTotal is already net (coupon baked in by backend).
          // When not, subtract coupon/wallet to show the true payable amount.
          const displayTotal = usedInvoices
            ? orderTotal
            : Math.max(0, orderTotal - (order.couponDiscount ?? 0) - (order.walletPaid ?? 0));
          return (
            <BillRow
              label={usedInvoices ? "Final total" : "Total payable"}
              value={displayTotal}
              bold
              valueClass={usedInvoices ? "text-success" : undefined}
            />
          );
        })()}
        <p className="mt-xs text-[11px] text-muted">
          {usedInvoices
            ? "Confirmed totals from the shops' invoices."
            : "The shops will confirm the final amount when they accept your order."}
        </p>
      </div>

      {/* Customer note */}
      {hasNote && (
        <>
          <div className="h-px bg-hairline" />
          <SectionLabel text="YOUR NOTE" />
          <p className="px-lg pb-md text-body-md leading-relaxed text-ink">{order.note}</p>
        </>
      )}

      {/* Pay Now bar */}
      {needsPayment && (
        <div className="sticky bottom-0 left-0 right-0 z-20 border-t border-hairline bg-white px-lg py-md">
          <div className="mx-auto flex max-w-shell items-center justify-between gap-md">
            <div>
              <p className="text-body-sm font-semibold text-muted">Payment pending</p>
              <p className="text-title-sm font-extrabold text-ink">
                {formatINR(payable, { decimals: 2 })}
              </p>
            </div>
            <button
              onClick={() => void handlePayNow()}
              disabled={paying}
              className="inline-flex h-10 items-center gap-sm rounded-button bg-ink px-xl text-label-md font-extrabold text-white disabled:opacity-60 hover:bg-ink/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
            >
              {paying && (
                <span className="h-4 w-4 rounded-full border-2 border-white/30 border-t-white animate-spin" />
              )}
              Pay Now
            </button>
          </div>
        </div>
      )}

      {/* Cancel confirm dialog */}
      {cancelConfirmChild && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink/40 px-lg">
          <div className="w-full max-w-sm rounded-dialog bg-white p-xl">
            <h2 className="text-title-md font-extrabold text-ink">Cancel these items?</h2>
            <p className="mt-sm text-body-sm text-muted">
              Items from{" "}
              <span className="font-bold text-ink">
                {cancelConfirmChild.shop?.shopName ?? cancelConfirmChild.shop?.name ?? "this seller"}
              </span>{" "}
              will be cancelled. Items from other sellers in this order will continue.
            </p>
            <div className="mt-xl flex gap-sm">
              <button
                onClick={() => setCancelConfirmChild(null)}
                className="inline-flex h-10 flex-1 items-center justify-center rounded-button border border-hairline bg-white text-label-md text-ink hover:bg-canvas focus-visible:outline-none"
              >
                Keep items
              </button>
              <button
                onClick={() => void doCancel(cancelConfirmChild)}
                className="inline-flex h-10 flex-1 items-center justify-center rounded-button bg-error text-label-md font-bold text-white hover:opacity-90 focus-visible:outline-none"
              >
                Cancel items
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Return dialog */}
      {returnDialogChild && (
        <RequestReturnDialog
          parentOrderId={orderId}
          shopOrder={returnDialogChild}
          onClose={() => setReturnDialogChild(null)}
          onSubmitted={(returnId) => {
            setReturnDialogChild(null);
            showSnack({ message: `Return submitted · #${returnId}`, tone: "success" });
            void load();
          }}
        />
      )}

      <Snackbar snack={snack} />
    </>
  );
}

// ─── Section primitives ───────────────────────────────────────────────────────

function SectionLabel({ text }: { text: string }) {
  return (
    <p className="px-lg pt-md pb-sm text-[11px] font-extrabold tracking-[0.6px] text-muted uppercase">
      {text}
    </p>
  );
}

function BillRow({
  label,
  value,
  valueLabel,
  valueLabelClass,
  bold = false,
  valueClass,
}: {
  label: string;
  value?: number;
  valueLabel?: string;
  valueLabelClass?: string;
  bold?: boolean;
  valueClass?: string;
}) {
  const labelCls = bold ? "text-body-md font-extrabold text-ink" : "text-body-md font-semibold text-muted";
  const valCls = bold ? "text-body-lg font-extrabold" : "text-body-md font-extrabold";
  return (
    <div className="flex items-center justify-between py-[3px]">
      <span className={labelCls}>{label}</span>
      {valueLabel ? (
        <span className={`${valCls} ${valueLabelClass ?? "text-ink"}`}>{valueLabel}</span>
      ) : (
        <span className={`${valCls} ${valueClass ?? "text-ink"}`}>
          {formatINR(value ?? 0, { decimals: 2 })}
        </span>
      )}
    </div>
  );
}

// ─── Shop order section ────────────────────────────────────────────────────────

function ShopSection({
  child,
  packageIndex,
  packageCount,
  cancelling,
  parentOrderId,
  onCancel,
  onRequestReturn,
}: {
  child: ShopOrderDetail;
  packageIndex?: number;
  packageCount: number;
  cancelling: boolean;
  parentOrderId: number;
  onCancel: () => void;
  onRequestReturn: () => void;
}) {
  const cancelNote = cancelUnavailableNote(child);
  const returnNote = returnUnavailableNote(child);
  const vendorName = child.shop?.shopName ?? child.shop?.name ?? "Seller";
  const showTimeline =
    child.events.length > 0 &&
    child.status !== "PENDING" &&
    child.status !== "REJECTED" &&
    child.status !== "CANCELLED";

  // Invoice visuals
  function invoiceVisual(): { colorClass: string; label: string } | null {
    const inv = child.invoice;
    if (!inv) return null;
    if (inv.paymentStatus === "PAID")
      return { colorClass: "text-success", label: `Paid · Invoice ${inv.invoiceNo}` };
    if (inv.paidAmount > 0)
      return {
        colorClass: "text-warning",
        label: `${formatINR(inv.paidAmount, { decimals: 2 })} of ${formatINR(inv.total, { decimals: 2 })} paid · Invoice ${inv.invoiceNo}`,
      };
    return { colorClass: "text-muted", label: `Invoice ${inv.invoiceNo} · payment pending` };
  }

  const invVis = invoiceVisual();
  const pdfUrl = child.invoice ? invoicePdfUrl(parentOrderId, child.id) : null;

  return (
    <div>
      {/* Header */}
      <div className="px-lg pt-md pb-sm">
        <div className="flex items-center justify-between mb-xs">
          {packageIndex ? (
            <span className="text-[10px] font-extrabold tracking-[0.6px] text-muted uppercase">
              Package {packageIndex} of {packageCount}
            </span>
          ) : (
            <span />
          )}
          <ShopOrderStatusChip status={child.status} />
        </div>
        <div className="flex items-start gap-sm">
          <Store size={14} className="text-muted mt-[2px] flex-shrink-0" />
          <p className="text-body-sm text-muted font-semibold">
            Sold by{" "}
            <span className="text-body-md font-extrabold text-ink">{vendorName}</span>
          </p>
        </div>
      </div>

      <div className="h-px bg-hairline mx-lg" />

      {/* Items */}
      {child.items.map((item, idx) => {
        const img = item.product?.images?.[0]?.url;
        const imgSrc = img ? `/api/media/${img.replace(/^\//, "")}` : null;
        return (
          <div key={item.id}>
            <div className="flex items-start gap-md px-lg py-md">
              {/* Product image */}
              <div className="h-12 w-12 flex-shrink-0 rounded-md bg-hero-panel overflow-hidden">
                {imgSrc ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={imgSrc}
                    alt={item.productName}
                    className="h-full w-full object-cover"
                  />
                ) : null}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-body-sm font-extrabold text-ink line-clamp-2">{item.productName}</p>
                <div className="mt-xs flex flex-wrap gap-sm items-center">
                  <span className="rounded-full bg-hero-panel px-sm py-[2px] text-[11px] font-bold text-ink">
                    Qty {formatQty(item.quantity)}
                  </span>
                  <span className="text-[11px] text-muted">{item.unit}</span>
                  <span className="text-[11px] text-muted">
                    {formatINR(item.unitPrice, { decimals: 2 })} each
                  </span>
                </div>
              </div>
              <span className="text-body-sm font-extrabold text-ink flex-shrink-0">
                {formatINR(item.total, { decimals: 2 })}
              </span>
            </div>
            {idx < child.items.length - 1 && <div className="h-px bg-hairline mx-lg" />}
          </div>
        );
      })}

      {/* Tracking timeline */}
      {showTimeline && (
        <>
          <div className="h-px bg-hairline mx-lg" />
          <OrderTimeline events={child.events} status={child.status} />
        </>
      )}

      {/* Invoice footer */}
      {invVis && pdfUrl && (
        <>
          <div className="h-px bg-hairline mx-lg" />
          <div className="flex items-center gap-sm px-lg py-sm pb-md">
            <span className={`flex-1 text-body-sm font-bold ${invVis.colorClass}`}>
              {invVis.label}
            </span>
            <a
              href={pdfUrl}
              target="_blank"
              rel="noopener noreferrer"
              className={`flex h-8 w-8 items-center justify-center rounded-full hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${invVis.colorClass}`}
              title="Download invoice"
            >
              <Download size={16} />
            </a>
          </div>
        </>
      )}

      {/* Rejection note */}
      {child.status === "REJECTED" && child.decisionNote && (
        <div className="mx-lg my-sm rounded-md bg-error-soft p-sm flex gap-sm">
          <Info size={14} className="text-error flex-shrink-0 mt-[1px]" />
          <p className="text-body-sm text-error">{child.decisionNote}</p>
        </div>
      )}

      {/* Cancel action */}
      {child.canCancel && (
        <div className="flex justify-end px-lg pb-md pt-xs">
          <button
            onClick={onCancel}
            disabled={cancelling}
            className="inline-flex h-8 items-center gap-xs rounded-full bg-error-soft px-md text-label-md font-extrabold text-error disabled:opacity-60 hover:bg-error-soft/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error transition-colors"
          >
            {cancelling ? (
              <span className="h-3 w-3 rounded-full border-2 border-error/30 border-t-error animate-spin" />
            ) : (
              <X size={13} />
            )}
            Cancel items
          </button>
        </div>
      )}

      {/* Return action */}
      {child.canReturn && child.items.length > 0 && (
        <div className="flex justify-end px-lg pb-md pt-xs">
          <button
            onClick={onRequestReturn}
            className="inline-flex h-8 items-center gap-xs rounded-full bg-brand-soft px-md text-label-md font-extrabold text-brand hover:bg-brand-soft/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
          >
            <RotateCcw size={13} />
            Request a return
          </button>
        </div>
      )}

      {/* Unavailability notes */}
      {cancelNote && (
        <div className="mx-lg mb-md mt-xs flex items-start gap-sm">
          <Info size={13} className="text-muted flex-shrink-0 mt-[2px]" />
          <p className="text-label-md text-muted leading-[1.3]">{cancelNote}</p>
        </div>
      )}
      {returnNote && (
        <div className="mx-lg mb-md mt-xs flex items-start gap-sm">
          <Info size={13} className="text-muted flex-shrink-0 mt-[2px]" />
          <p className="text-label-md text-muted leading-[1.3]">{returnNote}</p>
        </div>
      )}
    </div>
  );
}

function formatQty(n: number): string {
  return Number.isInteger(n) ? String(n) : n.toFixed(2);
}

// ─── Page wrapper ─────────────────────────────────────────────────────────────

export default function OrderDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ toast?: string }>;
}) {
  const { id } = use(params);
  const { toast } = use(searchParams);
  const orderId = parseInt(id, 10);

  return (
    <RequireAuth>
      <AppHeader />
      <main className="min-h-screen bg-white">
        <div className="mx-auto max-w-shell">
          {/* Back nav */}
          <div className="flex items-center gap-sm px-lg pt-md pb-xs">
            <Link
              href="/orders"
              className="flex h-8 w-8 items-center justify-center rounded-full text-muted hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
            >
              <ArrowLeft size={16} />
            </Link>
            <h1 className="text-title-md font-extrabold text-ink">Order #{orderId}</h1>
          </div>
        </div>
        <div className="mx-auto max-w-shell">
          <OrderDetailContent orderId={orderId} initialToast={toast} />
        </div>
      </main>
    </RequireAuth>
  );
}
