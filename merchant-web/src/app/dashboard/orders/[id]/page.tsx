"use client";

import { use, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import {
  ArrowLeft,
  BadgeCheck,
  Check,
  Copy,
  Mail,
  MessageCircle,
  Phone,
  ReceiptText,
  Truck,
  TriangleAlert,
  X,
} from "@/shared/icons";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { DateTimeField, SelectField, TextField } from "@/shared/ui/form";
import { useCanManage } from "@/features/auth/use-can";
import {
  addShippingEvent,
  confirmOrder,
  getOrder,
  OrderConfirmError,
  rejectOrder,
  SHIPPING_MILESTONES,
  SHIPPING_MILESTONE_LABELS,
  type ShippingMilestone,
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
  "outOfStock",
  "shopClosed",
  "priceChanged",
  "other",
] as const;

export default function OrderDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const t = useTranslations("orders");
  const { id } = use(params);
  const orderId = id;

  const [order, setOrder] = useState<OrderDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [shortfallProductId, setShortfallProductId] = useState<string | null>(null);
  const [mode, setMode] = useState<"none" | "confirm" | "decline">("none");
  const [shippingOpen, setShippingOpen] = useState(false);
  const canManageOrders = useCanManage("orders");

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
        if (active) setError(e instanceof Error ? e.message : t("detail.loadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [orderId, nonce, t]);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  async function onConfirm() {
    if (!order) return;
    setBusy(true);
    setActionError(null);
    setShortfallProductId(null);
    try {
      const result = await confirmOrder(order.id);
      setSuccess(t("detail.invoiceCreated", { invoiceNo: result.invoice.invoiceNo }));
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
        setActionError(e instanceof Error ? e.message : t("detail.confirmError"));
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
      setSuccess(t("detail.declined"));
      setMode("none");
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("detail.declineError"));
    } finally {
      setBusy(false);
    }
  }

  async function onShipping(input: {
    type: ShippingMilestone;
    courier?: string;
    awb?: string;
    eta?: string;
    note?: string;
  }) {
    if (!order) return;
    setBusy(true);
    setActionError(null);
    try {
      await addShippingEvent(order.id, input);
      setSuccess(
        t("detail.shippingMarked", {
          milestone: SHIPPING_MILESTONE_LABELS[input.type].toLowerCase(),
        }),
      );
      setShippingOpen(false);
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("detail.shippingError"));
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
            {t("detail.tryAgain")}
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
            <h1 className="text-headline-md text-ink">{t("detail.heading", { id: order.id })}</h1>
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
        <SummaryStat label={t("detail.statItems")} value={String(order.items.length)} />
        <SummaryStat label={t("detail.statTotalQty")} value={qty(totalQty)} />
        <SummaryStat label={t("detail.statOrderTotal")} value={money(sub)} emphasis />
      </div>

      {/* Shortfall banner */}
      {pending && shortfall ? (
        <div className="mt-lg flex items-start gap-sm rounded-md bg-warning-soft px-md py-md">
          <TriangleAlert size={18} className="mt-px shrink-0 text-warning" />
          <div>
            <p className="text-body-md font-semibold text-warning">
              {t("detail.shortfallTitle", {
                short: shortItemCount(order),
                total: order.items.length,
              })}
            </p>
            <p className="mt-px text-body-sm text-warning">
              {t("detail.shortfallBody")}
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
            {t("detail.customerNote")}
          </p>
          <p className="mt-xs text-body-md text-ink">{order.note}</p>
        </div>
      ) : null}

      {order.decisionNote && !pending ? (
        <p className="mt-md text-body-sm text-muted">
          <span className="text-label-md uppercase tracking-wide text-subtle">
            {t("detail.decisionNote")}{" "}
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
      <h2 className="text-title-md text-ink">{t("detail.itemsHeading")}</h2>
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
        <TotalLine label={t("detail.subtotal")} value={money(sub)} />
        <TotalLine label={t("detail.tax")} value={money(0)} muted />
        <TotalLine label={t("detail.discount")} value={`−${money(0)}`} muted />
        <Divider className="my-sm" />
        <TotalLine label={t("detail.total")} value={money(sub)} emphasis />
        {pending && shortfall ? (
          <p className="mt-sm text-body-sm text-muted">
            {t("detail.taxDiscountNote")}
          </p>
        ) : null}
      </div>

      {/* Shipping timeline — milestones apply once an order is confirmed. */}
      {!pending || order.events.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <div className="flex flex-wrap items-center justify-between gap-sm">
            <h2 className="text-title-md text-ink">{t("detail.shippingHeading")}</h2>
            {!pending && canManageOrders ? (
              <button
                type="button"
                onClick={() => setShippingOpen(true)}
                className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                <Truck size={16} /> {t("detail.updateShipping")}
              </button>
            ) : null}
          </div>
          {order.events.length > 0 ? (
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
          ) : (
            <p className="mt-sm text-body-sm text-subtle">{t("detail.noShippingUpdates")}</p>
          )}
        </>
      ) : null}

      {shippingOpen ? <ShippingModal busy={busy} onClose={() => setShippingOpen(false)} onSubmit={onShipping} /> : null}

      {/* Linked invoice CTA */}
      {order.invoice ? (
        <div className="mt-xl">
          <Link
            href={`/dashboard/invoices/${order.invoice.id}`}
            className="inline-flex h-11 items-center gap-sm rounded-button bg-brand-soft px-lg text-label-lg text-brand-strong transition-colors hover:bg-brand-soft/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <ReceiptText size={18} /> {t("detail.openInvoice", { invoiceNo: order.invoice.invoiceNo })}
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

function ShippingModal({
  busy,
  onClose,
  onSubmit,
}: {
  busy: boolean;
  onClose: () => void;
  onSubmit: (input: {
    type: ShippingMilestone;
    courier?: string;
    awb?: string;
    eta?: string;
    note?: string;
  }) => void;
}) {
  const t = useTranslations("orders");
  const [type, setType] = useState<ShippingMilestone>("PACKED");
  const [courier, setCourier] = useState("");
  const [awb, setAwb] = useState("");
  const [eta, setEta] = useState<string | null>(null);
  const [note, setNote] = useState("");

  // Courier/AWB are meaningful once shipped/out-for-delivery.
  const showLogistics = type === "SHIPPED" || type === "OUT_FOR_DELIVERY";

  return (
    <Modal title={t("shipping.title")} onClose={onClose}>
      <SelectField
        label={t("shipping.milestoneLabel")}
        value={type}
        onChange={(v) => setType(v as ShippingMilestone)}
        options={SHIPPING_MILESTONES.map((m) => ({ value: m, label: SHIPPING_MILESTONE_LABELS[m] }))}
      />
      {showLogistics ? (
        <>
          <TextField label={t("shipping.courierLabel")} value={courier} onChange={setCourier} placeholder={t("shipping.courierPlaceholder")} />
          <TextField label={t("shipping.awbLabel")} value={awb} onChange={setAwb} placeholder={t("shipping.awbPlaceholder")} />
          <DateTimeField label={t("shipping.etaLabel")} value={eta} onChange={setEta} />
        </>
      ) : null}
      <TextField label={t("shipping.noteLabel")} value={note} onChange={setNote} />
      <ModalActions
        busy={busy}
        confirmLabel={t("shipping.save")}
        onCancel={onClose}
        onConfirm={() =>
          onSubmit({
            type,
            courier: showLogistics && courier.trim() ? courier.trim() : undefined,
            awb: showLogistics && awb.trim() ? awb.trim() : undefined,
            eta: showLogistics && eta ? eta : undefined,
            note: note.trim() || undefined,
          })
        }
      />
    </Modal>
  );
}

function BackLink() {
  const t = useTranslations("orders");
  return (
    <Link
      href="/dashboard/orders"
      className="inline-flex items-center gap-sm text-body-md text-muted transition-colors hover:text-ink"
    >
      <ArrowLeft size={16} /> {t("detail.back")}
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
  const t = useTranslations("orders");
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
              <span className="inline-flex items-center gap-xs rounded-full border border-success bg-surface px-sm py-px text-body-sm font-bold text-success">
                <BadgeCheck size={14} /> {t("detail.linkedParty")}
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
            <ReachButton href={`tel:${phone}`} icon={<Phone size={14} />} label={t("detail.call")} />
          ) : null}
          {phone ? (
            <ReachButton
              href={`https://wa.me/${waDigits}?text=${encodeURIComponent(t("detail.whatsappMessage", { name: order.customerName, id: order.id }))}`}
              icon={<MessageCircle size={14} />}
              label={t("detail.whatsapp")}
              external
            />
          ) : null}
          {email ? (
            <ReachButton
              href={`mailto:${email}?subject=${encodeURIComponent(t("detail.emailSubject", { id: order.id }))}`}
              icon={<Mail size={14} />}
              label={t("detail.email")}
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
  const t = useTranslations("orders");
  const [copied, setCopied] = useState(false);
  async function copy() {
    const lines = [
      t("detail.copyHeader", { id: order.id, name: order.customerName }),
      formatDateTime(order.createdAt),
      "",
      ...order.items.map(
        (i) =>
          `• ${i.productName} × ${qty(i.quantity)} ${i.unit} — ${money(i.total)}`,
      ),
      "",
      t("detail.copyTotal", { total: money(subtotal(order)) }),
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
      {copied ? t("detail.copied") : t("detail.copySummary")}
    </button>
  );
}

function StatusJourney({ order }: { order: OrderDetail }) {
  const t = useTranslations("orders");
  const declined = order.status === "REJECTED" || order.status === "CANCELLED";
  const confirmed = order.status === "CONFIRMED";
  const invoiced = order.invoice != null;
  const paid = order.invoice?.paymentStatus === "PAID";

  const steps: Array<{ key: string; label: string; done: boolean; failed?: boolean }> = [
    { key: "placed", label: t("journey.placed"), done: true },
    {
      key: "confirmed",
      label: order.status === "REJECTED"
        ? t("journey.declined")
        : order.status === "CANCELLED"
          ? t("journey.cancelled")
          : t("journey.confirmed"),
      done: confirmed,
      failed: declined,
    },
    { key: "invoiced", label: t("journey.invoiced"), done: invoiced },
    { key: "paid", label: t("journey.paid"), done: paid },
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
            : "border-hairline bg-surface";
        const isFirst = i === 0;
        const isLast = i === steps.length - 1;
        const next = steps[i + 1];
        return (
          <div key={s.key} className="flex flex-1 flex-col items-center">
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
  const t = useTranslations("orders");
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
        <div className="mt-xs flex flex-wrap items-center gap-sm">
          <StockChip item={item} />
          {item.product?.isActive !== false && !itemStockOk(item) ? (
            <Link
              href={`/dashboard/products/${item.productId}`}
              className="inline-flex items-center gap-xs text-label-md text-brand-strong underline-offset-2 hover:underline focus-visible:underline focus-visible:outline-none"
            >
              <Truck size={14} /> {t("detail.restock")}
            </Link>
          ) : null}
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
  const t = useTranslations("orders");
  const active = item.product?.isActive ?? true;
  const stock = item.product?.stockQuantity;
  let styles: string;
  let label: string;

  if (!active) {
    styles = "bg-error-soft text-error";
    label = t("stock.inactive");
  } else if (stock == null) {
    styles = "bg-surface-tint text-muted";
    label = t("stock.unknown");
  } else if (itemStockOk(item)) {
    styles = "bg-success-soft text-success";
    label = t("stock.ok", {
      asked: qty(item.quantity),
      stock: qty(stock),
      unit: unitLabel(item.unit),
    });
  } else {
    styles = "bg-warning-soft text-warning";
    label = t("stock.short", {
      asked: qty(item.quantity),
      stock: qty(stock),
      short: qty(itemShortfall(item)),
    });
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
  const t = useTranslations("orders");
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
          <X size={18} /> {t("actions.decline")}
        </button>
        <button
          type="button"
          onClick={onOpenConfirm}
          className="inline-flex h-11 flex-[2] items-center justify-center gap-sm rounded-button bg-brand px-md text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft sm:flex-none sm:px-xl"
        >
          <Check size={18} /> {t("actions.confirmAndInvoice")}
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
  const t = useTranslations("orders");
  return (
    <div className="mt-xl rounded-md border border-hairline p-lg">
      <p className="text-title-md text-ink">
        {shortfall ? t("confirm.titleShort") : t("confirm.title")}
      </p>
      <p className="mt-sm max-w-content text-body-md text-muted">
        {t("confirm.body")}
        {shortfall ? ` ${t("confirm.bodyShort")}` : ""}
      </p>
      <div className="mt-lg flex gap-md">
        <button
          type="button"
          onClick={onCancel}
          disabled={busy}
          className="inline-flex h-11 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          {t("confirm.notYet")}
        </button>
        <button
          type="button"
          onClick={onConfirm}
          disabled={busy}
          className={`inline-flex h-11 items-center gap-sm rounded-button px-lg text-label-lg text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled ${
            shortfall ? "bg-warning hover:opacity-90" : "bg-brand hover:bg-brand-strong"
          }`}
        >
          <Check size={18} /> {busy ? t("confirm.confirming") : t("confirm.confirmOrder")}
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
  const t = useTranslations("orders");
  const [reason, setReason] = useState<string | null>(null);
  const [note, setNote] = useState("");

  function pickReason(r: string) {
    setReason(r);
    setNote(r === "other" ? "" : t(`decline.reasons.${r}`));
  }

  return (
    <div className="mt-xl rounded-md border border-hairline p-lg">
      <p className="text-title-md text-ink">{t("decline.title")}</p>
      <p className="mt-xs text-body-md text-muted">
        {t("decline.subtitle")}
      </p>
      <div className="mt-md flex flex-wrap gap-sm">
        {DECLINE_REASONS.map((r) => (
          <button
            key={r}
            type="button"
            onClick={() => pickReason(r)}
            aria-pressed={reason === r}
            className={`inline-flex h-9 items-center rounded-full px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
              reason === r ? "bg-inverse-surface text-on-inverse" : "bg-surface-tint text-ink hover:bg-hairline"
            }`}
          >
            {t(`decline.reasons.${r}`)}
          </button>
        ))}
      </div>
      <textarea
        value={note}
        onChange={(e) => setNote(e.target.value)}
        placeholder={t("decline.notePlaceholder")}
        rows={2}
        maxLength={500}
        className="mt-md w-full max-w-content rounded-input border border-hairline bg-field px-md py-sm text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
      />
      <div className="mt-md flex gap-md">
        <button
          type="button"
          onClick={onCancel}
          disabled={busy}
          className="inline-flex h-11 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          {t("decline.cancel")}
        </button>
        <button
          type="button"
          onClick={() => onDecline(note.trim())}
          disabled={busy}
          className="inline-flex h-11 items-center gap-sm rounded-button bg-error px-lg text-label-lg text-white transition-colors hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error-soft disabled:bg-disabled"
        >
          <X size={18} /> {busy ? t("decline.declining") : t("decline.declineOrder")}
        </button>
      </div>
    </div>
  );
}
