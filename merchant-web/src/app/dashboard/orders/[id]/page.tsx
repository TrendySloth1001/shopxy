"use client";

import { use, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import {
  ArrowLeft,
  BadgeCheck,
  Check,
  Copy,
  Mail,
  MessageCircle,
  Phone,
  ReceiptText,
  TriangleAlert,
  X,
} from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import {
  confirmOrder,
  getOrder,
  OrderConfirmError,
  rejectOrder,
} from "@/features/orders/api";
import type { OrderDetail, OrderItem } from "@/features/orders/schema";
import {
  formatDateTime,
  hasStockShortfall,
  itemShortfall,
  itemStockOk,
  money,
  qty,
  relativeTime,
  shortItemCount,
  subtotal,
  unitLabel,
} from "@/features/orders/format";
import { OrderStatusBadge } from "@/features/orders/components/order-status-badge";
import { ProductThumb } from "@/features/products/components/product-thumb";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

const DECLINE_REASONS = [
  "Out of stock",
  "Shop closed",
  "Price changed",
  "Other",
] as const;

export default function OrderDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const orderId = Number(id);

  const [order, setOrder] = useState<OrderDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [shortfallProductId, setShortfallProductId] = useState<number | null>(null);
  const [mode, setMode] = useState<"none" | "confirm" | "decline">("none");

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const o = await getOrder(orderId);
        if (active) {
          setOrder(o);
          setError(null);
        }
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the order.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [orderId, nonce]);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  async function onConfirm() {
    if (!order) return;
    setBusy(true);
    setActionError(null);
    setShortfallProductId(null);
    try {
      const result = await confirmOrder(order.id);
      setSuccess(`Invoice ${result.invoice.invoiceNo} created.`);
      setMode("none");
      reload();
    } catch (e) {
      if (e instanceof OrderConfirmError) {
        setActionError(e.message);
        if (e.code === "INSUFFICIENT_STOCK" && e.productId != null) {
          setShortfallProductId(e.productId);
        }
        // The server is the source of truth for stock — re-pull so the page
        // chips match what just blocked the confirm.
        if (e.code === "INSUFFICIENT_STOCK") reload();
      } else {
        setActionError(e instanceof Error ? e.message : "Could not confirm the order.");
      }
      setMode("none");
    } finally {
      setBusy(false);
    }
  }

  async function onDecline(note: string) {
    if (!order) return;
    setBusy(true);
    setActionError(null);
    try {
      await rejectOrder(order.id, note);
      setSuccess("Order declined.");
      setMode("none");
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not decline the order.");
    } finally {
      setBusy(false);
    }
  }

  if (loading && !order) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink />
        <ListRowsSkeleton rows={5} />
      </div>
    );
  }
  if (error && !order) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink />
        <div className="flex flex-col items-start gap-md py-xxxl">
          <p className="text-body-md text-muted">{error}</p>
          <button
            type="button"
            onClick={reload}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            Try again
          </button>
        </div>
      </div>
    );
  }
  if (!order) return null;

  const pending = order.status === "PENDING";
  const shortfall = hasStockShortfall(order);
  const sub = subtotal(order);
  const totalQty = order.items.reduce((acc, i) => acc + i.quantity, 0);

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink />

      {/* Header */}
      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-sm">
            <h1 className="text-headline-md text-ink">Order #{order.id}</h1>
            <OrderStatusBadge status={order.status} />
          </div>
          <p className="mt-xs text-body-md text-muted">
            {formatDateTime(order.createdAt)} · {relativeTime(order.createdAt)}
          </p>
        </div>
        <CopySummaryButton order={order} />
      </div>

      {success ? (
        <div className="mt-md flex items-center gap-sm rounded-md bg-success-soft px-md py-sm text-body-sm text-success">
          <Check size={16} /> {success}
        </div>
      ) : null}
      {actionError ? (
        <div className="mt-md flex items-center gap-sm rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          <TriangleAlert size={16} /> {actionError}
        </div>
      ) : null}

      {/* Summary stats */}
      <div className="mt-lg grid grid-cols-3 divide-x divide-hairline">
        <SummaryStat label="Items" value={String(order.items.length)} />
        <SummaryStat label="Total qty" value={qty(totalQty)} />
        <SummaryStat label="Order total" value={money(sub)} emphasis />
      </div>

      {/* Shortfall banner */}
      {pending && shortfall ? (
        <div className="mt-lg flex items-start gap-sm rounded-md bg-warning-soft px-md py-md">
          <TriangleAlert size={18} className="mt-px shrink-0 text-warning" />
          <div>
            <p className="text-body-md font-semibold text-warning">
              {shortItemCount(order)} of {order.items.length}{" "}
              {order.items.length === 1 ? "item" : "items"} short on stock
            </p>
            <p className="mt-px text-body-sm text-warning">
              Restock those products before confirming — the invoice will fail to
              post otherwise.
            </p>
          </div>
        </div>
      ) : null}

      <Divider className="my-xl" />

      {/* Customer */}
      <CustomerBlock order={order} />

      {order.customerAddress ? (
        <p className="mt-md max-w-content text-body-sm text-muted">
          {order.customerAddress}
        </p>
      ) : null}

      {order.note ? (
        <div className="mt-md max-w-content rounded-md bg-surface-tint px-md py-sm">
          <p className="text-label-md uppercase tracking-wide text-subtle">
            Customer note
          </p>
          <p className="mt-xs text-body-md text-ink">{order.note}</p>
        </div>
      ) : null}

      {order.decisionNote && !pending ? (
        <p className="mt-md text-body-sm text-muted">
          <span className="text-label-md uppercase tracking-wide text-subtle">
            Decision note:{" "}
          </span>
          {order.decisionNote}
        </p>
      ) : null}

      {/* Status journey */}
      <div className="mt-xl">
        <StatusJourney order={order} />
      </div>

      <Divider className="my-xl" />

      {/* Items */}
      <h2 className="text-title-md text-ink">Items</h2>
      <ul className="mt-sm">
        {order.items.map((item) => (
          <ItemRow
            key={item.id}
            item={item}
            highlight={item.productId === shortfallProductId}
          />
        ))}
      </ul>

      {/* Totals */}
      <div className="mt-lg max-w-form">
        <TotalLine label="Subtotal" value={money(sub)} />
        <TotalLine label="Tax" value={money(0)} muted />
        <TotalLine label="Discount" value={`−${money(0)}`} muted />
        <Divider className="my-sm" />
        <TotalLine label="Total" value={money(sub)} emphasis />
        {pending && shortfall ? (
          <p className="mt-sm text-body-sm text-muted">
            Tax and discount are finalised on the invoice.
          </p>
        ) : null}
      </div>

      {/* Shipping timeline */}
      {order.events.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <h2 className="text-title-md text-ink">Shipping updates</h2>
          <ul className="mt-sm flex flex-col gap-sm">
            {order.events.map((ev) => (
              <li key={ev.id} className="flex items-baseline gap-md">
                <span className="text-body-md text-ink">
                  {ev.type.replace(/_/g, " ").toLowerCase()}
                </span>
                <span className="text-body-sm text-muted">
                  {formatDateTime(ev.occurredAt)}
                  {ev.courier ? ` · ${ev.courier}` : ""}
                  {ev.awb ? ` · ${ev.awb}` : ""}
                </span>
              </li>
            ))}
          </ul>
        </>
      ) : null}

      {/* Linked invoice CTA */}
      {order.invoice ? (
        <div className="mt-xl">
          <Link
            href={`/dashboard/invoices/${order.invoice.id}`}
            className="inline-flex h-11 items-center gap-sm rounded-button bg-brand-soft px-lg text-label-lg text-brand-strong transition-colors hover:bg-brand-soft/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <ReceiptText size={18} /> Open invoice {order.invoice.invoiceNo}
          </Link>
        </div>
      ) : null}

      {/* Pending action bar */}
      {pending ? (
        <ActionArea
          mode={mode}
          busy={busy}
          shortfall={shortfall}
          onOpenConfirm={() => {
            setMode("confirm");
            setActionError(null);
          }}
          onOpenDecline={() => {
            setMode("decline");
            setActionError(null);
          }}
          onCancel={() => setMode("none")}
          onConfirm={onConfirm}
          onDecline={onDecline}
        />
      ) : null}
    </div>
  );
}

function BackLink() {
  return (
    <Link
      href="/dashboard/orders"
      className="inline-flex items-center gap-sm text-body-md text-muted transition-colors hover:text-ink"
    >
      <ArrowLeft size={16} /> Orders
    </Link>
  );
}

function SummaryStat({
  label,
  value,
  emphasis,
}: {
  label: string;
  value: string;
  emphasis?: boolean;
}) {
  return (
    <div className="px-md first:pl-0">
      <p
        className={`text-headline-sm tabular-nums ${emphasis ? "text-brand-strong" : "text-ink"}`}
      >
        {value}
      </p>
      <p className="mt-xs text-label-md uppercase tracking-wide text-subtle">
        {label}
      </p>
    </div>
  );
}

function CustomerBlock({ order }: { order: OrderDetail }) {
  const initial = order.customerName.trim().charAt(0).toUpperCase() || "?";
  const phone = order.customerPhone?.trim();
  const email = order.customerEmail?.trim();
  const linked = order.party?.linkedUserId != null;
  const waDigits = phone ? phone.replace(/[^0-9]/g, "") : "";

  return (
    <div className="flex flex-wrap items-start gap-md">
      {/* Avatar + identity */}
      <div className="flex min-w-0 flex-1 items-start gap-md">
        <span
          aria-hidden
          className="flex size-12 shrink-0 items-center justify-center rounded-md bg-hero-panel text-title-md text-ink"
        >
          {initial}
        </span>
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-sm">
            <p className="text-title-md text-ink">{order.customerName}</p>
            {linked ? (
              <span className="inline-flex items-center gap-xs rounded-full border border-success bg-white px-sm py-px text-body-sm font-bold text-success">
                <BadgeCheck size={14} /> Linked party
              </span>
            ) : null}
          </div>
          {phone ? <p className="text-body-sm text-muted">{phone}</p> : null}
          {email ? <p className="text-body-sm text-muted">{email}</p> : null}
        </div>
      </div>

      {/* Reachability — beside the name on desktop, below it on mobile. */}
      {phone || email ? (
        <div className="flex w-full flex-wrap gap-sm sm:w-auto sm:self-center">
          {phone ? (
            <ReachButton href={`tel:${phone}`} icon={<Phone size={14} />} label="Call" />
          ) : null}
          {phone ? (
            <ReachButton
              href={`https://wa.me/${waDigits}?text=${encodeURIComponent(`Hi ${order.customerName}, regarding your order #${order.id}.`)}`}
              icon={<MessageCircle size={14} />}
              label="WhatsApp"
              external
            />
          ) : null}
          {email ? (
            <ReachButton
              href={`mailto:${email}?subject=${encodeURIComponent(`Order #${order.id}`)}`}
              icon={<Mail size={14} />}
              label="Email"
            />
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function ReachButton({
  href,
  icon,
  label,
  external,
}: {
  href: string;
  icon: React.ReactNode;
  label: string;
  external?: boolean;
}) {
  return (
    <a
      href={href}
      {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
      className="inline-flex h-9 items-center gap-sm rounded-full bg-surface-tint px-md text-label-md text-ink transition-colors hover:bg-hairline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      {icon}
      {label}
    </a>
  );
}

function CopySummaryButton({ order }: { order: OrderDetail }) {
  const [copied, setCopied] = useState(false);
  async function copy() {
    const lines = [
      `Order #${order.id} from ${order.customerName}`,
      formatDateTime(order.createdAt),
      "",
      ...order.items.map(
        (i) =>
          `• ${i.productName} × ${qty(i.quantity)} ${i.unit} — ${money(i.total)}`,
      ),
      "",
      `Total: ${money(subtotal(order))}`,
    ];
    try {
      await navigator.clipboard.writeText(lines.join("\n"));
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      /* clipboard unavailable — no-op */
    }
  }
  return (
    <button
      type="button"
      onClick={copy}
      className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      {copied ? <Check size={16} /> : <Copy size={16} />}
      {copied ? "Copied" : "Copy summary"}
    </button>
  );
}

function StatusJourney({ order }: { order: OrderDetail }) {
  const declined = order.status === "REJECTED" || order.status === "CANCELLED";
  const confirmed = order.status === "CONFIRMED";
  const invoiced = order.invoice != null;
  const paid = order.invoice?.paymentStatus === "PAID";

  const steps: Array<{ label: string; done: boolean; failed?: boolean }> = [
    { label: "Placed", done: true },
    {
      label: order.status === "REJECTED"
        ? "Declined"
        : order.status === "CANCELLED"
          ? "Cancelled"
          : "Confirmed",
      done: confirmed,
      failed: declined,
    },
    { label: "Invoiced", done: invoiced },
    { label: "Paid", done: paid },
  ];

  // A segment is "lit" when the step it leads into is reached. Each step paints
  // the half-segment on either side of its dot with the matching colour so the
  // line stays continuous while dots remain centred over their labels.
  const segmentLit = (step: { done: boolean; failed?: boolean }) =>
    step.done || step.failed ? "bg-brand" : "bg-hairline";

  return (
    <div className="flex items-start">
      {steps.map((s, i) => {
        const color = s.failed
          ? "text-error"
          : s.done
            ? "text-brand-strong"
            : "text-subtle";
        const dot = s.failed
          ? "border-error bg-error"
          : s.done
            ? "border-brand bg-brand"
            : "border-hairline bg-white";
        const isFirst = i === 0;
        const isLast = i === steps.length - 1;
        const next = steps[i + 1];
        return (
          <div key={s.label} className="flex flex-1 flex-col items-center">
            <div className="flex w-full items-center">
              <span
                className={`h-px flex-1 ${isFirst ? "bg-transparent" : segmentLit(s)}`}
              />
              <span
                className={`flex size-4 shrink-0 items-center justify-center rounded-full border ${dot}`}
              >
                {s.done && !s.failed ? (
                  <Check size={10} className="text-white" />
                ) : null}
              </span>
              <span
                className={`h-px flex-1 ${isLast || !next ? "bg-transparent" : segmentLit(next)}`}
              />
            </div>
            <span className={`mt-xs text-center text-label-md ${color}`}>
              {s.label}
            </span>
          </div>
        );
      })}
    </div>
  );
}

function ItemRow({ item, highlight }: { item: OrderItem; highlight: boolean }) {
  const imageUrl = item.product?.images?.[0]?.url;
  return (
    <li
      className={`flex items-start gap-md border-t border-hairline py-md ${
        highlight ? "bg-warning-soft" : ""
      }`}
    >
      <ProductThumb url={imageUrl} alt={item.productName} size={48} />
      <div className="min-w-0 flex-1">
        <p className="text-body-md font-semibold text-ink">{item.productName}</p>
        <p className="text-body-sm text-muted">
          {item.productSku} · {money(item.unitPrice)} / {item.unit}
        </p>
        <div className="mt-xs">
          <StockChip item={item} />
        </div>
      </div>
      <div className="flex shrink-0 flex-col items-end">
        <span className="text-body-md text-muted">
          {qty(item.quantity)} {item.unit}
        </span>
        <span className="mt-px text-body-md font-semibold tabular-nums text-ink">
          {money(item.total)}
        </span>
      </div>
    </li>
  );
}

function StockChip({ item }: { item: OrderItem }) {
  const active = item.product?.isActive ?? true;
  const stock = item.product?.stockQuantity;
  let styles: string;
  let label: string;

  if (!active) {
    styles = "bg-error-soft text-error";
    label = "Inactive product";
  } else if (stock == null) {
    styles = "bg-surface-tint text-muted";
    label = "Stock unknown";
  } else if (itemStockOk(item)) {
    styles = "bg-success-soft text-success";
    label = `Asked ${qty(item.quantity)} · ${qty(stock)} ${unitLabel(item.unit)} in stock`;
  } else {
    styles = "bg-warning-soft text-warning";
    label = `Asked ${qty(item.quantity)} · in stock ${qty(stock)} · short ${qty(itemShortfall(item))}`;
  }

  return (
    <span
      className={`inline-flex items-center rounded-full px-sm py-px text-body-sm ${styles}`}
    >
      {label}
    </span>
  );
}

function TotalLine({
  label,
  value,
  muted,
  emphasis,
}: {
  label: string;
  value: string;
  muted?: boolean;
  emphasis?: boolean;
}) {
  return (
    <div className="flex items-baseline justify-between py-xs">
      <span
        className={
          emphasis
            ? "text-title-md text-ink"
            : muted
              ? "text-body-md text-muted"
              : "text-body-md text-ink"
        }
      >
        {label}
      </span>
      <span
        className={`tabular-nums ${emphasis ? "text-title-md text-ink" : muted ? "text-body-md text-muted" : "text-body-md text-ink"}`}
      >
        {value}
      </span>
    </div>
  );
}

function ActionArea({
  mode,
  busy,
  shortfall,
  onOpenConfirm,
  onOpenDecline,
  onCancel,
  onConfirm,
  onDecline,
}: {
  mode: "none" | "confirm" | "decline";
  busy: boolean;
  shortfall: boolean;
  onOpenConfirm: () => void;
  onOpenDecline: () => void;
  onCancel: () => void;
  onConfirm: () => void;
  onDecline: (note: string) => void;
}) {
  if (mode === "confirm") {
    return (
      <ConfirmPanel
        busy={busy}
        shortfall={shortfall}
        onCancel={onCancel}
        onConfirm={onConfirm}
      />
    );
  }
  if (mode === "decline") {
    return <DeclinePanel busy={busy} onCancel={onCancel} onDecline={onDecline} />;
  }
  return (
    <div className="sticky bottom-0 mt-xl -mx-lg border-t border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
      <div className="flex gap-md">
        <button
          type="button"
          onClick={onOpenDecline}
          className="inline-flex h-11 flex-1 items-center justify-center gap-sm rounded-button border border-error px-md text-label-lg text-error transition-colors hover:bg-error-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error-soft sm:flex-none sm:px-xl"
        >
          <X size={18} /> Decline
        </button>
        <button
          type="button"
          onClick={onOpenConfirm}
          className="inline-flex h-11 flex-[2] items-center justify-center gap-sm rounded-button bg-brand px-md text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft sm:flex-none sm:px-xl"
        >
          <Check size={18} /> Confirm &amp; create invoice
        </button>
      </div>
    </div>
  );
}

function ConfirmPanel({
  busy,
  shortfall,
  onCancel,
  onConfirm,
}: {
  busy: boolean;
  shortfall: boolean;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  return (
    <div className="mt-xl rounded-md border border-hairline p-lg">
      <p className="text-title-md text-ink">
        {shortfall ? "Stock looks short — confirm anyway?" : "Confirm this order?"}
      </p>
      <p className="mt-sm max-w-content text-body-md text-muted">
        Confirming creates a SALE invoice and decrements stock for each line.
        {shortfall
          ? " Some items have less stock than requested, so the invoice may fail to post."
          : ""}
      </p>
      <div className="mt-lg flex gap-md">
        <button
          type="button"
          onClick={onCancel}
          disabled={busy}
          className="inline-flex h-11 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          Not yet
        </button>
        <button
          type="button"
          onClick={onConfirm}
          disabled={busy}
          className={`inline-flex h-11 items-center gap-sm rounded-button px-lg text-label-lg text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled ${
            shortfall ? "bg-warning hover:opacity-90" : "bg-brand hover:bg-brand-strong"
          }`}
        >
          <Check size={18} /> {busy ? "Confirming…" : "Confirm order"}
        </button>
      </div>
    </div>
  );
}

function DeclinePanel({
  busy,
  onCancel,
  onDecline,
}: {
  busy: boolean;
  onCancel: () => void;
  onDecline: (note: string) => void;
}) {
  const [reason, setReason] = useState<string | null>(null);
  const [note, setNote] = useState("");

  function pickReason(r: string) {
    setReason(r);
    setNote(r === "Other" ? "" : r);
  }

  return (
    <div className="mt-xl rounded-md border border-hairline p-lg">
      <p className="text-title-md text-ink">Decline this order?</p>
      <p className="mt-xs text-body-md text-muted">
        The customer is notified. Pick a reason or add a note.
      </p>
      <div className="mt-md flex flex-wrap gap-sm">
        {DECLINE_REASONS.map((r) => (
          <button
            key={r}
            type="button"
            onClick={() => pickReason(r)}
            aria-pressed={reason === r}
            className={`inline-flex h-9 items-center rounded-full px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
              reason === r ? "bg-ink text-white" : "bg-surface-tint text-ink hover:bg-hairline"
            }`}
          >
            {r}
          </button>
        ))}
      </div>
      <textarea
        value={note}
        onChange={(e) => setNote(e.target.value)}
        placeholder="Optional note to the customer"
        rows={2}
        maxLength={500}
        className="mt-md w-full max-w-content rounded-input border border-hairline bg-white px-md py-sm text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
      />
      <div className="mt-md flex gap-md">
        <button
          type="button"
          onClick={onCancel}
          disabled={busy}
          className="inline-flex h-11 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={() => onDecline(note.trim())}
          disabled={busy}
          className="inline-flex h-11 items-center gap-sm rounded-button bg-error px-lg text-label-lg text-white transition-colors hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error-soft disabled:bg-disabled"
        >
          <X size={18} /> {busy ? "Declining…" : "Decline order"}
        </button>
      </div>
    </div>
  );
}
