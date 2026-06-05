"use client";

import { useCallback, useEffect, useState } from "react";
import { Check, Inbox, Info, RefreshCw, ShoppingBasket, X } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { TextAreaField } from "@/shared/ui/form";
import { formatDateTime } from "@/shared/datetime";
import { formatINR } from "@/shared/money";
import {
  approveCautionRequest,
  listShopCautionRequests,
  rejectCautionRequest,
} from "@/features/caution/api";
import { requestPartyName, type CautionRequest } from "@/features/caution/schema";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

export default function CautionRequestsPage() {
  const [rows, setRows] = useState<CautionRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [busyId, setBusyId] = useState<number | null>(null);
  const [rejectTarget, setRejectTarget] = useState<CautionRequest | null>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [infoOpen, setInfoOpen] = useState(false);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await listShopCautionRequests();
        if (!active) return;
        setRows(data);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load caution requests.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce]);

  async function approve(r: CautionRequest) {
    setBusyId(r.id);
    setError(null);
    try {
      await approveCautionRequest(r.partyId, r.id);
      setRows((prev) => prev.filter((x) => x.id !== r.id));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not approve the request.");
    } finally {
      setBusyId(null);
    }
  }

  async function confirmReject() {
    if (!rejectTarget) return;
    setBusyId(rejectTarget.id);
    try {
      await rejectCautionRequest(rejectTarget.partyId, rejectTarget.id, rejectNote || null);
      setRows((prev) => prev.filter((x) => x.id !== rejectTarget.id));
      setRejectTarget(null);
      setRejectNote("");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not decline the request.");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Inbox}
        tone="indigo"
        title="Caution requests"
        subtitle="Customers can ask to place a security deposit with you. Approving a request adds the amount to that customer's held balance."
      >
        <button
          type="button"
          onClick={() => setInfoOpen(true)}
          aria-label="About caution requests"
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint"
        >
          <Info size={16} />
        </button>
        <button
          type="button"
          onClick={reload}
          disabled={loading}
          aria-label="Refresh"
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
      </PageHeader>

      {infoOpen ? (
        <Modal title="Caution requests" onClose={() => setInfoOpen(false)}>
          <p className="text-body-md text-muted">
            Customers can ask to place a caution deposit with you. Review each request here.
          </p>
          <div className="flex flex-col gap-md">
            <InfoRow tone="success" icon={<Check size={16} />} title="Approve" body="Confirms the deposit and adds it to the customer's held balance — it shows up as a Deposit in their history." />
            <InfoRow tone="error" icon={<X size={16} />} title="Decline" body="Rejects the request. You can add an optional reason the customer will see." />
            <InfoRow tone="indigo" icon={<ShoppingBasket size={16} />} title="Plans to buy" body="Items the customer intends to purchase against the deposit, if they attached a basket." />
          </div>
        </Modal>
      ) : null}

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl">
        {loading ? (
          <ListRowsSkeleton />
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-accent-indigo-soft text-accent-indigo">
              <Inbox size={22} />
            </span>
            <p className="text-body-md text-muted">No pending caution requests.</p>
          </div>
        ) : (
          rows.map((r) => (
            <RequestRow
              key={r.id}
              request={r}
              busy={busyId === r.id}
              onApprove={() => approve(r)}
              onReject={() => {
                setRejectNote("");
                setRejectTarget(r);
              }}
            />
          ))
        )}
      </div>

      {rejectTarget ? (
        <Modal title={`Decline ${requestPartyName(rejectTarget)}'s request?`} onClose={() => setRejectTarget(null)}>
          <p className="text-body-md text-muted">
            Optionally add a reason the customer will see.
          </p>
          <TextAreaField label="Reason (optional)" value={rejectNote} onChange={setRejectNote} rows={2} />
          <ModalActions
            busy={busyId === rejectTarget.id}
            danger
            confirmLabel="Decline"
            onCancel={() => setRejectTarget(null)}
            onConfirm={confirmReject}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function RequestRow({
  request,
  busy,
  onApprove,
  onReject,
}: {
  request: CautionRequest;
  busy: boolean;
  onApprove: () => void;
  onReject: () => void;
}) {
  const basket = request.basket ?? [];
  const shown = basket.slice(0, 4);
  const extra = basket.length - shown.length;
  return (
    <div className="flex flex-col gap-sm border-b border-hairline py-lg">
      <div className="flex items-start gap-md">
        <div className="min-w-0 flex-1">
          <p className="text-body-md font-semibold text-ink">{requestPartyName(request)}</p>
          <p className="text-body-sm text-muted">
            {formatDateTime(request.createdAt)}
            {request.mode ? ` · ${request.mode}` : ""}
            {request.modeReference ? ` · ${request.modeReference}` : ""}
          </p>
          {request.note ? <p className="mt-xs text-body-sm text-subtle">{request.note}</p> : null}
        </div>
        <p className="shrink-0 text-title-md font-bold text-accent-indigo">{formatINR(request.amount)}</p>
      </div>

      {shown.length > 0 ? (
        <div className="rounded-md bg-surface-tint px-md py-sm">
          <p className="flex items-center gap-xs text-label-md text-subtle">
            <ShoppingBasket size={13} /> Plans to buy
          </p>
          <div className="mt-xs flex flex-wrap gap-x-md gap-y-xs text-body-sm text-muted">
            {shown.map((b, i) => (
              <span key={i}>
                {b.name ?? "Item"}
                {b.qty ? ` ×${b.qty}` : ""}
              </span>
            ))}
            {extra > 0 ? <span className="text-subtle">+{extra} more</span> : null}
          </div>
        </div>
      ) : null}

      <div className="flex items-center justify-end gap-sm">
        <button
          type="button"
          onClick={onReject}
          disabled={busy}
          className="inline-flex h-9 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-error transition-colors hover:bg-error-soft disabled:text-disabled"
        >
          <X size={15} /> Decline
        </button>
        <button
          type="button"
          onClick={onApprove}
          disabled={busy}
          className="inline-flex h-9 items-center gap-xs rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          <Check size={15} /> {busy ? "Approving…" : "Approve"}
        </button>
      </div>
    </div>
  );
}

function InfoRow({
  tone,
  icon,
  title,
  body,
}: {
  tone: "success" | "error" | "indigo";
  icon: React.ReactNode;
  title: string;
  body: string;
}) {
  const puck = {
    success: "bg-success-soft text-success",
    error: "bg-error-soft text-error",
    indigo: "bg-accent-indigo-soft text-accent-indigo",
  }[tone];
  return (
    <div className="flex items-start gap-md">
      <span className={`flex size-8 shrink-0 items-center justify-center rounded-full ${puck}`}>{icon}</span>
      <div className="min-w-0">
        <p className="text-body-md text-ink">{title}</p>
        <p className="text-body-sm text-muted">{body}</p>
      </div>
    </div>
  );
}
