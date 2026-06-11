"use client";

import { useEffect, useState, useCallback, useRef, startTransition } from "react";
import { useParams, useRouter } from "next/navigation";
import { PiggyBank, Plus, Bolt, X, Info, AlertCircle } from "lucide-react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import {
  fetchCautionLedger,
  fetchCautionRequests,
  postCautionRequest,
  cancelCautionRequest,
  payCautionRequest,
  syncCautionRequestPayment,
} from "@/features/merchant-ledger/api";
import {
  TxnIcon,
  SkeletonLine,
  SkeletonBlock,
  Snackbar,
  type SnackMsg,
} from "@/features/merchant-ledger/components/shared";
import {
  txnLabel,
  txnIncreasesHeld,
  requestStatusLabel,
  type CautionTxn,
  type CautionRequest,
  type CautionLedger,
} from "@/features/merchant-ledger/types";
import { formatINR } from "@/shared/format";
import { formatDate } from "@/shared/datetime";
import { openRazorpayCheckout } from "@/shared/razorpay";
import type { PaySession } from "@/shared/razorpay";

// ─── Skeleton ─────────────────────────────────────────────────────────────────

function CautionSkeleton() {
  return (
    <div className="space-y-xl">
      {/* Balance header */}
      <div className="space-y-md px-lg py-lg">
        <div className="flex items-center gap-sm">
          <SkeletonBlock className="h-5 w-5 rounded-sm" />
          <SkeletonLine className="h-3 w-40" />
        </div>
        <SkeletonLine className="h-9 w-40" />
        <div className="flex gap-md">
          {[1, 2].map((i) => (
            <div key={i} className="flex-1 space-y-xs">
              <SkeletonLine className="h-2 w-14" />
              <SkeletonLine className="h-4 w-20" />
            </div>
          ))}
        </div>
      </div>
      <div className="h-px bg-hairline" />
      <SkeletonBlock className="h-11 mx-lg rounded-button" />
      <div className="h-px bg-hairline" />
      {/* History rows */}
      <div className="px-lg space-y-xs">
        <SkeletonLine className="h-3 w-16 mb-sm" />
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} className="flex items-center gap-md py-md border-t border-hairline">
            <SkeletonBlock className="h-10 w-10 shrink-0 rounded-md" />
            <div className="flex-1 space-y-xs">
              <SkeletonLine className="h-4 w-28" />
              <SkeletonLine className="h-3 w-48" />
            </div>
            <SkeletonLine className="h-4 w-16" />
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Txn history row ─────────────────────────────────────────────────────────

function TxnRow({ txn }: { txn: CautionTxn }) {
  const increases = txnIncreasesHeld(txn.type);
  const subtitle = [
    formatDate(txn.createdAt),
    txn.type === "ADJUSTMENT" && txn.invoiceNo ? `Inv ${txn.invoiceNo}` : null,
    txn.type !== "ADJUSTMENT" && txn.type !== "FORFEIT" && txn.mode ? txn.mode : null,
    txn.receiptNo ?? null,
  ]
    .filter(Boolean)
    .join(" · ");

  return (
    <div className="flex items-center gap-md py-md border-t border-hairline">
      <TxnIcon type={txn.type} />
      <div className="flex-1 min-w-0">
        <p className="text-body-md font-bold text-ink">{txnLabel(txn.type)}</p>
        <p className="text-body-sm text-muted truncate">{subtitle}</p>
      </div>
      <p
        className={`text-body-md font-extrabold tabular-nums shrink-0 ${
          increases ? "text-success" : "text-error"
        }`}
      >
        {increases ? "+" : "−"}{formatINR(txn.amount, { decimals: 2 })}
      </p>
    </div>
  );
}

// ─── Request row ─────────────────────────────────────────────────────────────

function RequestRow({
  req,
  partyId,
  onChanged,
  shopName,
}: {
  req: CautionRequest;
  partyId: string;
  onChanged: () => Promise<void>;
  shopName: string;
}) {
  const [paying, setPaying] = useState(false);
  const payingRef = useRef(false);
  const [cancelling, setCancelling] = useState(false);
  const [localSnack, setLocalSnack] = useState<SnackMsg | null>(null);
  const snackTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  function showSnack(msg: SnackMsg) {
    setLocalSnack(msg);
    if (snackTimer.current) clearTimeout(snackTimer.current);
    snackTimer.current = setTimeout(() => setLocalSnack(null), 4000);
  }

  const isPending = req.status === "PENDING";
  const isApproved = req.status === "APPROVED";
  const isPaidOnline = req.channel === "GATEWAY";
  const { label, color, bg } = requestStatusLabel(req.status);

  const subtitle = [
    formatDate(req.createdAt),
    isPaidOnline
      ? "Paid online"
      : req.mode ?? null,
    req.basket && Array.isArray(req.basket) && req.basket.length > 0
      ? `${req.basket.length} item(s)`
      : null,
    req.status === "REJECTED" && req.reviewNote ? req.reviewNote : null,
  ]
    .filter(Boolean)
    .join(" · ");

  async function handleCancel() {
    if (cancelling || paying) return;
    setCancelling(true);
    try {
      await cancelCautionRequest(partyId, req.id);
      await onChanged();
    } catch (e) {
      showSnack({
        message: e instanceof Error ? e.message : "Could not cancel request.",
        tone: "error",
      });
    } finally {
      setCancelling(false);
    }
  }

  async function handlePayOnline() {
    if (payingRef.current || cancelling) return;
    payingRef.current = true;
    setPaying(true);
    try {
      const session = await payCautionRequest(partyId, req.id);
      const result = await openRazorpayCheckout(session as unknown as PaySession, {
        name: "ShopXY",
        description: `Caution deposit — ${shopName}`,
      });

      if (result.outcome === "success") {
        let settled = false;
        try {
          const sync = await syncCautionRequestPayment(partyId, req.id);
          settled = sync.settled;
        } catch {
          // Non-fatal — webhook will settle
        }
        showSnack({
          message: settled
            ? "Deposit confirmed"
            : "Payment received — being confirmed. This can take a minute.",
          tone: settled ? "success" : "info",
        });
        await onChanged();
      } else if (result.outcome === "dismissed") {
        showSnack({
          message:
            "Payment not completed — nothing was charged. You can pay this deposit here whenever you're ready.",
          tone: "info",
        });
      } else {
        showSnack({
          message: `${result.message ?? "Payment failed"} — you can retry from this page.`,
          tone: "error",
        });
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Could not initiate payment.";
      // If request is no longer pending, refresh
      if (msg.includes("NOT_PENDING") || msg.includes("ALREADY_PAID")) {
        showSnack({ message: "This request is no longer pending — refreshing.", tone: "info" });
        await onChanged();
      } else {
        showSnack({ message: msg, tone: "error" });
      }
    } finally {
      payingRef.current = false;
      setPaying(false);
    }
  }

  return (
    <div className="border-t border-hairline py-md">
      <div className="flex items-start justify-between gap-md">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-sm flex-wrap">
            <span className="text-body-md font-extrabold text-ink tabular-nums">
              {formatINR(req.amount)}
            </span>
            <span
              className={`inline-flex items-center rounded-full px-sm py-[3px] text-[10px] font-extrabold tracking-[0.4px] ${color} ${bg}`}
            >
              {label}
            </span>
            {isApproved && (
              <span className="inline-flex items-center rounded-full px-sm py-[3px] text-[10px] font-extrabold tracking-[0.4px] text-success bg-success-soft">
                ✓ Held
              </span>
            )}
          </div>
          <p className="text-body-sm text-muted mt-[2px]">{subtitle}</p>
          {req.note && <p className="text-body-sm text-muted italic mt-xs truncate">{req.note}</p>}
        </div>
        {isPending && (
          <button
            disabled={cancelling || paying}
            onClick={handleCancel}
            className="inline-flex h-8 items-center gap-xs rounded-button px-sm text-body-sm font-bold text-error hover:bg-error-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error disabled:opacity-50"
          >
            <X size={14} />
            {cancelling ? "Cancelling…" : "Cancel"}
          </button>
        )}
      </div>

      {/* Pay online CTA for pending requests */}
      {isPending && (
        <button
          disabled={paying || cancelling}
          onClick={handlePayOnline}
          className="mt-sm flex w-full items-center justify-center gap-sm rounded-button bg-brand px-lg py-sm text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-60"
        >
          {paying ? (
            <>
              <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
              Processing…
            </>
          ) : (
            <>
              <Bolt size={16} />
              Pay online
            </>
          )}
        </button>
      )}

      {/* Local snackbar feedback */}
      {localSnack && (
        <div
          role="status"
          aria-live="polite"
          className={`mt-sm rounded-md px-md py-sm text-body-sm font-bold ${
            localSnack.tone === "success"
              ? "bg-success-soft text-success"
              : localSnack.tone === "error"
                ? "bg-error-soft text-error"
                : "bg-info-soft text-info"
          }`}
        >
          {localSnack.message}
        </div>
      )}
    </div>
  );
}

// ─── Post request form (inline) ───────────────────────────────────────────────

function PostRequestForm({
  partyId,
  onSubmitted,
  onClose,
}: {
  partyId: string;
  onSubmitted: () => Promise<void>;
  onClose: () => void;
}) {
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const amt = parseFloat(amount);
    if (!amt || amt <= 0) {
      setError("Enter a valid amount.");
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await postCautionRequest(partyId, { amount: amt, note: note.trim() || undefined });
      await onSubmitted();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not submit request.");
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="border border-hairline rounded-lg p-lg space-y-md mx-lg">
      <div className="flex items-center justify-between">
        <p className="text-body-md font-extrabold text-ink">Request deposit</p>
        <button
          type="button"
          onClick={onClose}
          className="flex h-8 w-8 items-center justify-center rounded-button text-muted hover:bg-surface-tint"
        >
          <X size={16} />
        </button>
      </div>

      <div>
        <label className="block text-body-sm font-bold text-ink mb-xs" htmlFor="caution-amount">
          Amount (₹) <span className="text-error">*</span>
        </label>
        <input
          id="caution-amount"
          type="number"
          min="1"
          step="1"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="e.g. 5000"
          className="w-full rounded-input border border-hairline bg-white px-md py-sm text-body-md text-ink focus:outline-none focus:ring-2 focus:ring-brand focus:border-brand"
          required
        />
      </div>

      <div>
        <label className="block text-body-sm font-bold text-ink mb-xs" htmlFor="caution-note">
          Note (optional)
        </label>
        <textarea
          id="caution-note"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          maxLength={500}
          rows={2}
          placeholder="Anything the shop should know"
          className="w-full rounded-input border border-hairline bg-white px-md py-sm text-body-md text-ink resize-none focus:outline-none focus:ring-2 focus:ring-brand focus:border-brand"
        />
      </div>

      {error && <p className="text-body-sm text-error">{error}</p>}

      <button
        type="submit"
        disabled={submitting}
        className="flex w-full items-center justify-center gap-sm rounded-button bg-brand px-lg py-sm text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-60"
      >
        {submitting ? (
          <>
            <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
            Sending…
          </>
        ) : (
          "Send request"
        )}
      </button>
    </form>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

function CautionPageContent() {
  const params = useParams<{ role: string; id: string }>();
  const router = useRouter();
  const partyId = params.id;
  const role = params.role;

  const [ledger, setLedger] = useState<CautionLedger | null>(null);
  const [requests, setRequests] = useState<CautionRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [snack, setSnack] = useState<SnackMsg | null>(null);
  const snackTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Caution is only available for parties (linked customers), not vendors
  useEffect(() => {
    if (role !== "party") {
      router.replace(`/merchants/${role}/${partyId}/invoices`);
    }
  }, [role, partyId, router]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [ledgerData, reqData] = await Promise.all([
        fetchCautionLedger(partyId),
        fetchCautionRequests(partyId),
      ]);
      setLedger(ledgerData);
      setRequests(reqData.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load caution data.");
    } finally {
      setLoading(false);
    }
  }, [partyId]);

  useEffect(() => {
    startTransition(() => { void load(); });
  }, [load]);

  function showSnack(msg: SnackMsg) {
    setSnack(msg);
    if (snackTimer.current) clearTimeout(snackTimer.current);
    snackTimer.current = setTimeout(() => setSnack(null), 5000);
  }

  if (loading && !ledger) {
    return (
      <div className="mx-auto max-w-shell px-0 sm:px-lg py-xxxl">
        <div className="mx-auto max-w-content">
          <CautionSkeleton />
        </div>
      </div>
    );
  }

  if (error && !ledger) {
    return (
      <div className="mx-auto max-w-shell px-lg py-xxxl">
        <div className="mx-auto max-w-content flex flex-col items-center gap-md py-huge text-center">
          <AlertCircle size={40} className="text-error" />
          <p className="text-body-md text-muted">{error}</p>
          <button
            onClick={load}
            className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  const txns = ledger?.data ?? [];
  const balance = ledger?.balance ?? 0;

  // Stats breakdown (only show categories > 0)
  function sumOf(type: string) {
    return txns.filter((t) => t.type === type).reduce((s, t) => s + t.amount, 0);
  }
  const stats = [
    { label: "Deposited", value: sumOf("DEPOSIT") },
    { label: "Returned", value: sumOf("REFUND") },
    { label: "Set-off", value: sumOf("ADJUSTMENT") },
    { label: "Forfeited", value: sumOf("FORFEIT") },
  ].filter((s) => s.value > 0);

  const pendingRequests = requests.filter((r) => r.status === "PENDING");
  const settledRequests = requests.filter((r) => r.status !== "PENDING").slice(0, 8);
  const allReqRows = [...pendingRequests, ...settledRequests];

  return (
    <div className="mx-auto max-w-shell px-0 sm:px-lg py-xxxl">
      <div className="mx-auto max-w-content">
        {/* Balance header */}
        <div className="px-lg py-lg space-y-md">
          <div className="flex items-center gap-sm">
            <PiggyBank size={18} className="text-brand" />
            <p className="text-[10px] font-extrabold tracking-[0.5px] text-muted uppercase">
              Held by this shop
            </p>
            <button
              title="About caution deposits"
              className="ml-auto flex h-8 w-8 items-center justify-center rounded-full text-muted hover:bg-surface-tint"
              onClick={() =>
                showSnack({
                  message:
                    "Caution deposits are security amounts held by the shop. They are refunded or set off against invoices per your agreement.",
                  tone: "info",
                })
              }
            >
              <Info size={16} />
            </button>
          </div>
          <p className="text-display-sm font-extrabold text-brand-strong tabular-nums">
            {formatINR(balance)}
          </p>
          {stats.length > 0 && (
            <div className="flex gap-md flex-wrap">
              {stats.map((s) => (
                <div key={s.label} className="flex flex-col">
                  <p className="text-[9px] font-extrabold tracking-[0.5px] text-muted uppercase">
                    {s.label}
                  </p>
                  <p className="text-body-md font-bold text-ink tabular-nums">
                    {formatINR(s.value)}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="h-px bg-hairline" />

        {/* Post deposit CTA */}
        {!showForm && (
          <div className="px-lg py-md">
            <button
              onClick={() => setShowForm(true)}
              className="flex w-full items-center justify-center gap-sm rounded-button bg-brand px-lg py-sm text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
            >
              <Plus size={18} />
              Request deposit
            </button>
          </div>
        )}

        {showForm && (
          <div className="py-md">
            <PostRequestForm
              partyId={partyId}
              onSubmitted={async () => {
                await load();
                showSnack({ message: "Deposit request sent.", tone: "success" });
              }}
              onClose={() => setShowForm(false)}
            />
          </div>
        )}

        <div className="h-px bg-hairline" />

        {/* Requests section */}
        {allReqRows.length > 0 && (
          <>
            <div className="px-lg pt-lg pb-xs">
              <p className="text-[10px] font-extrabold tracking-[1.2px] text-muted uppercase">
                Your requests
              </p>
            </div>
            <div className="px-lg">
              {allReqRows.map((req) => (
                <RequestRow
                  key={req.id}
                  req={req}
                  partyId={partyId}
                  shopName="this shop"
                  onChanged={load}
                />
              ))}
            </div>
            <div className="h-px bg-hairline mt-lg" />
          </>
        )}

        {/* History */}
        <div className="px-lg pt-lg">
          <p className="text-[10px] font-extrabold tracking-[1.2px] text-muted uppercase mb-xs">
            History
          </p>
          {txns.length === 0 ? (
            <p className="py-xxl text-center text-body-md text-muted">
              No transactions yet. Approved deposits will appear here.
            </p>
          ) : (
            txns.map((txn) => <TxnRow key={txn.id} txn={txn} />)
          )}
        </div>
      </div>

      <Snackbar snack={snack} />
    </div>
  );
}

export default function CautionPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <CautionPageContent />
    </RequireAuth>
  );
}
