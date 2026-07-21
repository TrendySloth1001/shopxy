"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  BadgeIndianRupee,
  CheckCircle2,
  CircleDot,
  MapPin,
  MessageSquare,
  PackageCheck,
  Truck,
} from "@/shared/icons";
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
  RETURN_STATUS_CLASSES,
  canApprove,
  canMarkPickedUp,
  canMarkReceived,
  canRefund,
  customerName,
  refundStatusMessageKey,
  type MerchantReturn,
  type RefundResult,
  type ReturnEvent,
  type ReturnItem,
} from "@/features/returns/schema";
import { DetailSkeleton } from "@/shared/ui/skeleton";

const BACK = "/dashboard/returns";

export default function ReturnDetailPage() {
  const t = useTranslations("returns");
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [ret, setRet] = useState<MerchantReturn | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const reload = () => setNonce((n) => n + 1);

  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [refundResult, setRefundResult] = useState<RefundResult | null>(null);
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
        if (active) setError(e instanceof Error ? e.message : t("detail.loadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id, nonce, t]);

  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setActionError(null);
    try {
      await fn();
      setModal(null);
      setNote("");
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("detail.updateError"));
    } finally {
      setBusy(false);
    }
  }

  async function runRefund() {
    setBusy(true);
    setActionError(null);
    try {
      const result = await refundReturn(id, note.trim() || undefined);
      setRefundResult(result);
      setModal(null);
      setNote("");
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("detail.refundError"));
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
        <BackLink href={BACK} label={t("list.title")} />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? t("detail.notFound")}
        </p>
      </div>
    );
  }

  const name = customerName(ret, t("customerFallback", { id: ret.id }));

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label={t("list.title")} />

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
              {t(`status.${ret.status}`)}
            </span>
          </div>
          <p className="mt-xs text-body-sm text-muted">
            {ret.request?.customerOrderId ? `${t("detail.orderNo", { id: ret.request.customerOrderId })} · ` : ""}
            {formatDateTime(ret.createdAt)}
          </p>
          {ret.request?.customerAddress ? (
            <p className="mt-xs flex items-center gap-sm text-body-sm text-muted">
              <MapPin size={14} className="text-subtle" /> {ret.request.customerAddress}
            </p>
          ) : null}
        </div>
        <div className="text-right">
          <p className="text-label-md uppercase tracking-wide text-subtle">{t("detail.refundLabel")}</p>
          <p className="text-headline-md font-bold text-ink">{formatINR2(ret.refundAmount)}</p>
        </div>
      </div>

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{actionError}</p>
      ) : null}

      {refundResult ? (
        <p className="mt-lg flex items-center gap-sm rounded-md bg-success-soft px-md py-sm text-body-sm text-success">
          <BadgeIndianRupee size={15} />{" "}
          {t(refundStatusMessageKey(refundResult), { amount: formatINR2(refundResult.refundAmount) })}
        </p>
      ) : ret.refundMethod ? (
        <p className="mt-lg flex items-center gap-sm rounded-md bg-success-soft px-md py-sm text-body-sm text-success">
          <BadgeIndianRupee size={15} />{" "}
          {t("detail.refundedToOriginal", { amount: formatINR2(ret.refundAmount), name })}
        </p>
      ) : null}

      {/* Items */}
      <Divider className="my-xl" />
      <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">{t("detail.itemsHeading")}</h2>
      {ret.items.map((it) => (
        <ItemRow key={it.id} item={it} />
      ))}

      {/* Notes */}
      {ret.note ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm flex items-center gap-sm text-label-md uppercase tracking-wide text-subtle">
            <MessageSquare size={14} /> {t("detail.buyerNote")}
          </h2>
          <p className="text-body-md text-muted">{ret.note}</p>
        </>
      ) : null}
      {ret.decisionNote ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">{t("detail.yourNote")}</h2>
          <p className="text-body-md text-muted">{ret.decisionNote}</p>
        </>
      ) : null}

      {/* Timeline */}
      {ret.events.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">{t("detail.timeline")}</h2>
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
              {t("actions.reject")}
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
              <CheckCircle2 size={16} /> {t("actions.approve")}
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
            <Truck size={16} /> {t("actions.markPickedUp")}
          </button>
        ) : null}
        {canMarkReceived(ret) ? (
          <button
            type="button"
            onClick={() => run(() => markReceived(id))}
            disabled={busy}
            className="inline-flex h-11 items-center gap-sm rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            <PackageCheck size={16} /> {t("actions.markReceived")}
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
            <BadgeIndianRupee size={16} /> {t("actions.refundAmount", { amount: formatINR2(ret.refundAmount) })}
          </button>
        ) : null}
      </div>

      {/* Modals */}
      {modal === "approve" ? (
        <Modal title={t("approveModal.title")} onClose={() => setModal(null)}>
          <p className="text-body-md text-muted">{t("approveModal.body")}</p>
          <TextAreaField label={t("noteOptionalLabel")} value={note} onChange={setNote} rows={2} />
          <ModalActions
            busy={busy}
            confirmLabel={t("actions.approve")}
            onCancel={() => setModal(null)}
            onConfirm={() => run(() => approveReturn(id, note.trim() || undefined))}
          />
        </Modal>
      ) : null}
      {modal === "reject" ? (
        <Modal title={t("rejectModal.title")} onClose={() => setModal(null)}>
          <p className="text-body-md text-muted">{t("rejectModal.body")}</p>
          <TextAreaField label={t("reasonLabel")} value={note} onChange={setNote} rows={2} />
          <ModalActions
            busy={busy}
            danger
            disabled={!note.trim()}
            confirmLabel={t("actions.reject")}
            onCancel={() => setModal(null)}
            onConfirm={() => run(() => rejectReturn(id, note.trim()))}
          />
        </Modal>
      ) : null}
      {modal === "refund" ? (
        <Modal title={t("refundModal.title", { amount: formatINR2(ret.refundAmount) })} onClose={() => setModal(null)}>
          <p className="text-body-md text-muted">{t("refundModal.body")}</p>
          <TextAreaField label={t("noteOptionalLabel")} value={note} onChange={setNote} rows={2} />
          <ModalActions
            busy={busy}
            confirmLabel={t("actions.refund")}
            onCancel={() => setModal(null)}
            onConfirm={() => void runRefund()}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function ItemRow({ item }: { item: ReturnItem }) {
  const t = useTranslations("returns");
  const pri = item.purchaseRequestItem;
  return (
    <div className="flex items-start gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{pri?.productName ?? t("detail.productFallback")}</p>
        <p className="text-body-sm text-muted">
          {item.quantity} {pri?.unit ?? ""} × {formatINR2(pri?.unitPrice ?? 0)}
        </p>
        {item.reason ? (
          <span className="mt-xs inline-flex items-center rounded-full bg-surface-tint px-sm py-px text-body-sm text-muted">
            {t(`reason.${item.reason}`)}
          </span>
        ) : null}
      </div>
      <span className="shrink-0 text-body-md font-semibold text-ink">{formatINR2(item.refundAmount)}</span>
    </div>
  );
}

function EventRow({ event }: { event: ReturnEvent }) {
  const t = useTranslations("returns");
  return (
    <div className="flex items-center gap-md border-b border-hairline py-sm">
      <CircleDot size={14} className="shrink-0 text-subtle" />
      <div className="min-w-0 flex-1">
        <p className="text-body-md text-ink">{t(`status.${event.type}`)}</p>
        {event.note ? <p className="text-body-sm text-muted">{event.note}</p> : null}
      </div>
      <span className="shrink-0 text-body-sm text-subtle">{formatDateTime(event.occurredAt)}</span>
    </div>
  );
}
