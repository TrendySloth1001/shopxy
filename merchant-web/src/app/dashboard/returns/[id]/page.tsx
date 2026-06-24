"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import {
  BadgeIndianRupee,
  CheckCircle2,
  CircleDot,
  MapPin,
  MessageSquare,
  PackageCheck,
  Truck,
} from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { TextAreaField } from "@/shared/ui/form";
import { formatDateTime } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import {
  approveReturn,
  getReturn,
  markPickedUp,
  markReceived,
  refundReturn,
  rejectReturn,
} from "@/features/returns/api";
import {
  RETURN_REASON_LABELS,
  RETURN_STATUS_CLASSES,
  RETURN_STATUS_LABELS,
  canApprove,
  canMarkPickedUp,
  canMarkReceived,
  canRefund,
  customerName,
  refundStatusMessage,
  type MerchantReturn,
  type ReturnEvent,
  type ReturnItem,
} from "@/features/returns/schema";
import { DetailSkeleton } from "@/shared/ui/skeleton";

const BACK = "/dashboard/returns";

export default function ReturnDetailPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [ret, setRet] = useState<MerchantReturn | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const reload = () => setNonce((n) => n + 1);

  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [refundNotice, setRefundNotice] = useState<string | null>(null);
  const [modal, setModal] = useState<"approve" | "reject" | "refund" | null>(null);
  const [note, setNote] = useState("");

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const r = await getReturn(id);
        if (!active) return;
        setRet(r);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the return.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id, nonce]);

  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setActionError(null);
    try {
      await fn();
      setModal(null);
      setNote("");
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not update the return.");
    } finally {
      setBusy(false);
    }
  }

  async function runRefund() {
    setBusy(true);
    setActionError(null);
    try {
      const result = await refundReturn(id, note.trim() || undefined);
      setRefundNotice(refundStatusMessage(result));
      setModal(null);
      setNote("");
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not refund the return.");
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return <DetailSkeleton />;
  }
  if (error || !ret) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={BACK} label="Returns" />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? "Return not found."}
        </p>
      </div>
    );
  }

  const name = customerName(ret);

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Returns" />

      {/* Header */}
      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-sm">
            <h1 className="text-headline-md text-ink">{name}</h1>
            <span
              className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
                RETURN_STATUS_CLASSES[ret.status] ?? "bg-surface-tint text-muted"
              }`}
            >
              {RETURN_STATUS_LABELS[ret.status] ?? ret.status}
            </span>
          </div>
          <p className="mt-xs text-body-sm text-muted">
            {ret.request?.customerOrderId ? `Order #${ret.request.customerOrderId} · ` : ""}
            {formatDateTime(ret.createdAt)}
          </p>
          {ret.request?.customerAddress ? (
            <p className="mt-xs flex items-center gap-sm text-body-sm text-muted">
              <MapPin size={14} className="text-subtle" /> {ret.request.customerAddress}
            </p>
          ) : null}
        </div>
        <div className="text-right">
          <p className="text-label-md uppercase tracking-wide text-subtle">Refund</p>
          <p className="text-headline-md font-bold text-ink">{formatINR2(ret.refundAmount)}</p>
        </div>
      </div>

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{actionError}</p>
      ) : null}

      {refundNotice ? (
        <p className="mt-lg flex items-center gap-sm rounded-md bg-success-soft px-md py-sm text-body-sm text-success">
          <BadgeIndianRupee size={15} /> {refundNotice}
        </p>
      ) : ret.refundMethod ? (
        <p className="mt-lg flex items-center gap-sm rounded-md bg-success-soft px-md py-sm text-body-sm text-success">
          <BadgeIndianRupee size={15} /> Refunded {formatINR2(ret.refundAmount)} to {name}&rsquo;s original payment
          method.
        </p>
      ) : null}

      {/* Items */}
      <Divider className="my-xl" />
      <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">Items</h2>
      {ret.items.map((it) => (
        <ItemRow key={it.id} item={it} />
      ))}

      {/* Notes */}
      {ret.note ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm flex items-center gap-sm text-label-md uppercase tracking-wide text-subtle">
            <MessageSquare size={14} /> Buyer note
          </h2>
          <p className="text-body-md text-muted">{ret.note}</p>
        </>
      ) : null}
      {ret.decisionNote ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">Your note</h2>
          <p className="text-body-md text-muted">{ret.decisionNote}</p>
        </>
      ) : null}

      {/* Timeline */}
      {ret.events.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">Timeline</h2>
          {ret.events.map((e) => (
            <EventRow key={e.id} event={e} />
          ))}
        </>
      ) : null}

      {/* Action bar */}
      <div className="mt-xxl flex flex-wrap items-center gap-sm">
        {canApprove(ret) ? (
          <>
            <button
              type="button"
              onClick={() => {
                setNote("");
                setModal("reject");
              }}
              disabled={busy}
              className="inline-flex h-11 items-center gap-sm rounded-button border border-hairline px-lg text-label-md text-error transition-colors hover:bg-error-soft disabled:text-disabled"
            >
              Reject
            </button>
            <button
              type="button"
              onClick={() => {
                setNote("");
                setModal("approve");
              }}
              disabled={busy}
              className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong disabled:bg-disabled"
            >
              <CheckCircle2 size={16} /> Approve
            </button>
          </>
        ) : null}
        {canMarkPickedUp(ret) ? (
          <button
            type="button"
            onClick={() => run(() => markPickedUp(id))}
            disabled={busy}
            className="inline-flex h-11 items-center gap-sm rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            <Truck size={16} /> Mark picked up
          </button>
        ) : null}
        {canMarkReceived(ret) ? (
          <button
            type="button"
            onClick={() => run(() => markReceived(id))}
            disabled={busy}
            className="inline-flex h-11 items-center gap-sm rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            <PackageCheck size={16} /> Mark received
          </button>
        ) : null}
        {canRefund(ret) ? (
          <button
            type="button"
            onClick={() => {
              setNote("");
              setModal("refund");
            }}
            disabled={busy}
            className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
          >
            <BadgeIndianRupee size={16} /> Refund {formatINR2(ret.refundAmount)}
          </button>
        ) : null}
      </div>

      {/* Modals */}
      {modal === "approve" ? (
        <Modal title="Approve return?" onClose={() => setModal(null)}>
          <p className="text-body-md text-muted">
            The customer is notified to send the items back. Add pickup instructions if you like.
          </p>
          <TextAreaField label="Note (optional)" value={note} onChange={setNote} rows={2} />
          <ModalActions
            busy={busy}
            confirmLabel="Approve"
            onCancel={() => setModal(null)}
            onConfirm={() => run(() => approveReturn(id, note.trim() || undefined))}
          />
        </Modal>
      ) : null}
      {modal === "reject" ? (
        <Modal title="Reject return?" onClose={() => setModal(null)}>
          <p className="text-body-md text-muted">Tell the customer why — this reason is shown to them.</p>
          <TextAreaField label="Reason" value={note} onChange={setNote} rows={2} />
          <ModalActions
            busy={busy}
            danger
            disabled={!note.trim()}
            confirmLabel="Reject"
            onCancel={() => setModal(null)}
            onConfirm={() => run(() => rejectReturn(id, note.trim()))}
          />
        </Modal>
      ) : null}
      {modal === "refund" ? (
        <Modal title={`Refund ${formatINR2(ret.refundAmount)}?`} onClose={() => setModal(null)}>
          <p className="text-body-md text-muted">
            This refunds the buyer to their original payment method and restocks the returned items. It can&rsquo;t be
            undone.
          </p>
          <TextAreaField label="Note (optional)" value={note} onChange={setNote} rows={2} />
          <ModalActions
            busy={busy}
            confirmLabel="Refund"
            onCancel={() => setModal(null)}
            onConfirm={() => void runRefund()}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function ItemRow({ item }: { item: ReturnItem }) {
  const pri = item.purchaseRequestItem;
  return (
    <div className="flex items-start gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{pri?.productName ?? "Product"}</p>
        <p className="text-body-sm text-muted">
          {item.quantity} {pri?.unit ?? ""} × {formatINR2(pri?.unitPrice ?? 0)}
        </p>
        {item.reason ? (
          <span className="mt-xs inline-flex items-center rounded-full bg-surface-tint px-sm py-px text-body-sm text-muted">
            {RETURN_REASON_LABELS[item.reason] ?? item.reason}
          </span>
        ) : null}
      </div>
      <span className="shrink-0 text-body-md font-semibold text-ink">{formatINR2(item.refundAmount)}</span>
    </div>
  );
}

function EventRow({ event }: { event: ReturnEvent }) {
  return (
    <div className="flex items-center gap-md border-b border-hairline py-sm">
      <CircleDot size={14} className="shrink-0 text-subtle" />
      <div className="min-w-0 flex-1">
        <p className="text-body-md text-ink">{RETURN_STATUS_LABELS[event.type] ?? event.type}</p>
        {event.note ? <p className="text-body-sm text-muted">{event.note}</p> : null}
      </div>
      <span className="shrink-0 text-body-sm text-subtle">{formatDateTime(event.occurredAt)}</span>
    </div>
  );
}
