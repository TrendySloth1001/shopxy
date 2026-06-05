"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { ArrowDownLeft, ArrowUpRight, Undo2 } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { TextAreaField } from "@/shared/ui/form";
import { formatDateTime } from "@/shared/datetime";
import { getAdjustment, reverseAdjustment } from "@/features/stock-adjustments/api";
import {
  ADJUSTMENT_REASON_CLASSES,
  ADJUSTMENT_REASON_LABELS,
  type Adjustment,
  type AdjustmentItem,
} from "@/features/stock-adjustments/schema";
import { DetailSkeleton } from "@/shared/ui/skeleton";

const BACK = "/dashboard/stock-adjustments";

export default function AdjustmentDetailPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [adjustment, setAdjustment] = useState<Adjustment | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [reverseOpen, setReverseOpen] = useState(false);
  const [reverseNote, setReverseNote] = useState("");
  const [reversed, setReversed] = useState(false);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const a = await getAdjustment(id);
        if (!active) return;
        setAdjustment(a);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the adjustment.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id, nonce]);

  async function onReverse() {
    setBusy(true);
    setActionError(null);
    try {
      await reverseAdjustment(id, reverseNote.trim() || undefined);
      setReverseOpen(false);
      setReversed(true);
      setNonce((n) => n + 1);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not reverse the adjustment.");
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return <DetailSkeleton />;
  }
  if (error || !adjustment) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={BACK} label="Stock adjustments" />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? "Adjustment not found."}
        </p>
      </div>
    );
  }

  const isIn = adjustment.direction === "IN";

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Stock adjustments" />

      {/* Header */}
      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="flex min-w-0 items-start gap-md">
          <span
            className={`flex size-12 shrink-0 items-center justify-center rounded-lg ${
              isIn ? "bg-success-soft text-success" : "bg-error-soft text-error"
            }`}
          >
            {isIn ? <ArrowDownLeft size={24} /> : <ArrowUpRight size={24} />}
          </span>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-sm">
              <h1 className="text-headline-md text-ink">{adjustment.adjustmentNo}</h1>
              <span
                className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
                  ADJUSTMENT_REASON_CLASSES[adjustment.reasonCode] ?? "bg-surface-tint text-muted"
                }`}
              >
                {ADJUSTMENT_REASON_LABELS[adjustment.reasonCode] ?? adjustment.reasonCode}
              </span>
            </div>
            <p className="mt-xs text-body-sm text-muted">
              {isIn ? "Stock added" : "Stock removed"}
              {adjustment.createdBy?.name ? ` · by ${adjustment.createdBy.name}` : ""}
              {" · "}
              {formatDateTime(adjustment.createdAt)}
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={() => setReverseOpen(true)}
          disabled={busy || reversed}
          className="inline-flex h-10 shrink-0 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <Undo2 size={16} /> {reversed ? "Reversed" : "Reverse"}
        </button>
      </div>

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{actionError}</p>
      ) : null}
      {reversed ? (
        <p className="mt-md rounded-md bg-success-soft px-md py-sm text-body-sm text-success">
          This adjustment has been reversed — the ledger movements were undone.
        </p>
      ) : null}

      {adjustment.note ? <p className="mt-lg text-body-md text-muted">{adjustment.note}</p> : null}

      {/* Items */}
      <Divider className="my-xl" />
      <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">Products</h2>
      {adjustment.items.map((it, i) => (
        <ItemRow key={it.id ?? i} item={it} isIn={isIn} />
      ))}

      {reverseOpen ? (
        <Modal title="Reverse this adjustment?" onClose={() => setReverseOpen(false)}>
          <p className="text-body-md text-muted">
            Posts an equal and opposite movement to the ledger, undoing the stock change. The original entry is
            kept as an audit trail.
          </p>
          <TextAreaField label="Note (optional)" value={reverseNote} onChange={setReverseNote} rows={2} />
          <ModalActions
            busy={busy}
            danger
            confirmLabel="Reverse"
            onCancel={() => setReverseOpen(false)}
            onConfirm={onReverse}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function ItemRow({ item, isIn }: { item: AdjustmentItem; isIn: boolean }) {
  return (
    <div className="flex items-center gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{item.productName ?? "Product"}</p>
        {item.productSku ? <p className="text-body-sm text-muted">{item.productSku}</p> : null}
      </div>
      <span className={`shrink-0 text-body-md font-semibold ${isIn ? "text-success" : "text-error"}`}>
        {isIn ? "+" : "−"}
        {item.quantity} {item.unit ?? ""}
      </span>
    </div>
  );
}
