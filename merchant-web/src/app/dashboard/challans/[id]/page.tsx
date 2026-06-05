"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ClipboardList, FileUp, Phone, ReceiptText, XCircle } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { formatDateTime } from "@/shared/datetime";
import { cancelChallan, convertChallan, getChallan } from "@/features/challans/api";
import {
  CHALLAN_STATUS_CLASSES,
  CHALLAN_STATUS_LABELS,
  type Challan,
  type ChallanItem,
} from "@/features/challans/schema";

const BACK = "/dashboard/challans";

export default function ChallanDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const id = Number(params.id);

  const [challan, setChallan] = useState<Challan | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [confirmCancel, setConfirmCancel] = useState(false);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const c = await getChallan(id);
        if (!active) return;
        setChallan(c);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the challan.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id, nonce]);

  async function onCancel() {
    setBusy(true);
    setActionError(null);
    try {
      await cancelChallan(id);
      setConfirmCancel(false);
      setNonce((n) => n + 1);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not cancel the challan.");
    } finally {
      setBusy(false);
    }
  }

  async function onConvert() {
    setBusy(true);
    setActionError(null);
    try {
      const created = await convertChallan(id);
      router.push(`/dashboard/invoices/${created.id}`);
      router.refresh();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not convert the challan.");
      setBusy(false);
    }
  }

  if (loading) {
    return <p className="w-full px-lg py-xxl text-body-sm text-subtle md:px-xxl">Loading…</p>;
  }
  if (error || !challan) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={BACK} label="Challans" />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? "Challan not found."}
        </p>
      </div>
    );
  }

  const isPending = challan.status === "PENDING";

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Challans" />

      {/* Header */}
      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="flex min-w-0 items-start gap-md">
          <span className="flex size-12 shrink-0 items-center justify-center rounded-lg bg-accent-amber-soft text-accent-amber">
            <ClipboardList size={24} />
          </span>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-sm">
              <h1 className="text-headline-md text-ink">{challan.challanNo}</h1>
              <span
                className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
                  CHALLAN_STATUS_CLASSES[challan.status] ?? "bg-surface-tint text-muted"
                }`}
              >
                {CHALLAN_STATUS_LABELS[challan.status] ?? challan.status}
              </span>
            </div>
            <p className="mt-xs text-body-sm text-muted">{formatDateTime(challan.createdAt)}</p>
          </div>
        </div>
      </div>

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{actionError}</p>
      ) : null}

      {/* Party / meta */}
      <div className="mt-lg rounded-lg border border-hairline p-lg">
        <p className="text-label-md uppercase tracking-wide text-subtle">Delivered to</p>
        <p className="mt-xs text-title-md text-ink">{challan.partyName ?? "—"}</p>
        {challan.partyPhone ? (
          <p className="mt-sm flex items-center gap-sm text-body-sm text-muted">
            <Phone size={14} className="text-subtle" /> {challan.partyPhone}
          </p>
        ) : null}
        {challan.note ? <p className="mt-sm text-body-md text-muted">{challan.note}</p> : null}
        {challan.invoice ? (
          <Link
            href={`/dashboard/invoices/${challan.invoice.id}`}
            className="mt-sm inline-flex items-center gap-xs text-body-sm font-semibold text-success transition-colors hover:underline"
          >
            <ReceiptText size={14} /> Invoice {challan.invoice.invoiceNo}
          </Link>
        ) : null}
      </div>

      {/* Items */}
      <Divider className="my-xl" />
      <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">Items</h2>
      {challan.items.map((it, i) => (
        <ItemRow key={it.id ?? i} item={it} />
      ))}

      {/* Action */}
      {isPending ? (
        <div className="mt-xxl flex flex-wrap items-center gap-sm">
          <button
            type="button"
            onClick={() => setConfirmCancel(true)}
            disabled={busy}
            className="inline-flex h-11 items-center gap-sm rounded-button border border-hairline px-lg text-label-md text-error transition-colors hover:bg-error-soft disabled:text-disabled"
          >
            <XCircle size={16} /> Cancel challan
          </button>
          <button
            type="button"
            onClick={onConvert}
            disabled={busy}
            className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
          >
            <FileUp size={16} /> {busy ? "Working…" : "Convert to invoice"}
          </button>
        </div>
      ) : null}

      {confirmCancel ? (
        <Modal title="Cancel this challan?" onClose={() => setConfirmCancel(false)}>
          <p className="text-body-md text-muted">
            The delivered stock is returned to inventory. This can&rsquo;t be undone.
          </p>
          <ModalActions
            busy={busy}
            danger
            confirmLabel="Cancel challan"
            onCancel={() => setConfirmCancel(false)}
            onConfirm={onCancel}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function ItemRow({ item }: { item: ChallanItem }) {
  return (
    <div className="flex items-center gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{item.productName ?? "Product"}</p>
        {item.productSku ? <p className="text-body-sm text-muted">{item.productSku}</p> : null}
      </div>
      <span className="shrink-0 text-body-md font-semibold text-ink">
        {item.quantity} {item.unit ?? ""}
      </span>
    </div>
  );
}
