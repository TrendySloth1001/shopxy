"use client";

import { useEffect, useState, useCallback, useRef, startTransition } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { AlertCircle, Download, Package } from "lucide-react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import {
  fetchQuotationDetail,
  acceptQuotation,
  declineQuotation,
  cancelQuotation,
  quotationPdfUrl,
} from "@/features/merchant-ledger/api";
import {
  QuotationStatusBadge,
  SkeletonLine,
  SkeletonBlock,
  Snackbar,
  type SnackMsg,
} from "@/features/merchant-ledger/components/shared";
import type { Quotation } from "@/features/merchant-ledger/types";
import { formatINR } from "@/shared/format";
import { formatDateTime } from "@/shared/datetime";

// ─── Skeleton ─────────────────────────────────────────────────────────────────

function QuotationDetailSkeleton() {
  return (
    <div className="space-y-xl px-lg sm:px-0">
      <div className="space-y-sm">
        <SkeletonLine className="h-5 w-36" />
        <SkeletonLine className="h-3 w-52" />
      </div>
      <div className="h-px bg-hairline" />
      <div className="space-y-xs">
        <SkeletonLine className="h-3 w-16" />
        {[1, 2, 3].map((i) => (
          <div key={i} className="flex items-center gap-md py-md border-t border-hairline">
            <SkeletonBlock className="h-10 w-10 rounded-md shrink-0" />
            <div className="flex-1 space-y-xs">
              <SkeletonLine className="h-4 w-40" />
              <SkeletonLine className="h-3 w-56" />
            </div>
            <SkeletonLine className="h-4 w-16" />
          </div>
        ))}
      </div>
      <div className="h-px bg-hairline" />
      <div className="space-y-xs">
        {[1, 2, 3].map((i) => (
          <div key={i} className="flex justify-between py-xs">
            <SkeletonLine className="h-3 w-20" />
            <SkeletonLine className="h-3 w-20" />
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Confirm dialog ──────────────────────────────────────────────────────────

function AcceptDialog({
  quotation,
  onConfirm,
  onClose,
}: {
  quotation: Quotation;
  onConfirm: () => void;
  onClose: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-ink/30 p-lg">
      <div className="w-full max-w-sm rounded-dialog bg-white p-xl space-y-md shadow-floating">
        <h2 className="text-title-md font-extrabold text-ink">Accept quotation?</h2>
        <p className="text-body-md text-muted">
          This will create a confirmed invoice for{" "}
          <span className="font-bold text-ink">{formatINR(quotation.total)}</span>. The shop will
          be notified.
        </p>
        <div className="flex gap-md pt-sm">
          <button
            onClick={onClose}
            className="flex-1 h-10 rounded-button border border-hairline text-label-md text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className="flex-[2] h-10 rounded-button bg-brand text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          >
            Accept · {formatINR(quotation.total)}
          </button>
        </div>
      </div>
    </div>
  );
}

function DeclineDialog({
  onConfirm,
  onClose,
}: {
  onConfirm: (note: string) => void;
  onClose: () => void;
}) {
  const [note, setNote] = useState("");
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-ink/30 p-lg">
      <div className="w-full max-w-sm rounded-dialog bg-white p-xl space-y-md shadow-floating">
        <h2 className="text-title-md font-extrabold text-ink">Decline quotation?</h2>
        <div>
          <label className="block text-body-sm font-bold text-ink mb-xs" htmlFor="decline-note">
            Reason (optional)
          </label>
          <textarea
            id="decline-note"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            maxLength={500}
            rows={3}
            placeholder="Shown to the shop"
            className="w-full rounded-input border border-hairline bg-white px-md py-sm text-body-md text-ink resize-none focus:outline-none focus:ring-2 focus:ring-brand"
          />
        </div>
        <div className="flex gap-md pt-sm">
          <button
            onClick={onClose}
            className="flex-1 h-10 rounded-button border border-hairline text-label-md text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          >
            Back
          </button>
          <button
            onClick={() => onConfirm(note.trim())}
            className="flex-[2] h-10 rounded-button bg-error text-label-md font-bold text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error"
          >
            Decline
          </button>
        </div>
      </div>
    </div>
  );
}

function WithdrawDialog({
  onConfirm,
  onClose,
}: {
  onConfirm: () => void;
  onClose: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-ink/30 p-lg">
      <div className="w-full max-w-sm rounded-dialog bg-white p-xl space-y-md shadow-floating">
        <h2 className="text-title-md font-extrabold text-ink">Withdraw request?</h2>
        <p className="text-body-md text-muted">
          The shop will no longer see this quote request.
        </p>
        <div className="flex gap-md pt-sm">
          <button
            onClick={onClose}
            className="flex-1 h-10 rounded-button border border-hairline text-label-md text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          >
            Back
          </button>
          <button
            onClick={onConfirm}
            className="flex-[2] h-10 rounded-button bg-error text-label-md font-bold text-white hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error"
          >
            Withdraw
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Detail content ───────────────────────────────────────────────────────────

function QuotationDetailView({
  quotation,
  partyId,
  onUpdated,
}: {
  quotation: Quotation;
  partyId: string;
  onUpdated: (q: Quotation) => void;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const busyRef = useRef(false);
  const [dialog, setDialog] = useState<"accept" | "decline" | "withdraw" | null>(null);
  const [snack, setSnack] = useState<SnackMsg | null>(null);
  const snackTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  function showSnack(msg: SnackMsg) {
    setSnack(msg);
    if (snackTimer.current) clearTimeout(snackTimer.current);
    snackTimer.current = setTimeout(() => setSnack(null), 5000);
  }

  const isRequested = quotation.status === "REQUESTED";
  const isPending = quotation.status === "PENDING";
  const isAccepted = quotation.status === "ACCEPTED";
  const isDeclined = quotation.status === "DECLINED";

  // Status copy
  let statusDesc = "";
  if (isRequested) statusDesc = "Awaiting shop pricing";
  else if (isPending) statusDesc = "Awaiting your response";
  else if (isAccepted) statusDesc = "Accepted";
  else if (isDeclined) statusDesc = "Declined";
  else if (quotation.status === "CANCELLED") statusDesc = "Withdrawn";
  else if (quotation.status === "EXPIRED") statusDesc = "Expired";

  async function doAccept() {
    if (busyRef.current) return;
    busyRef.current = true;
    setDialog(null);
    setBusy(true);
    try {
      const updated = await acceptQuotation(partyId, quotation.id);
      onUpdated(updated);
      showSnack({ message: "Accepted — added to your invoices.", tone: "success" });
    } catch (e) {
      showSnack({
        message: e instanceof Error ? e.message : "Could not accept quotation.",
        tone: "error",
      });
    } finally {
      busyRef.current = false;
      setBusy(false);
    }
  }

  async function doDecline(note: string) {
    setDialog(null);
    setBusy(true);
    try {
      const updated = await declineQuotation(partyId, quotation.id, {
        declineNote: note || undefined,
      });
      onUpdated(updated);
      showSnack({ message: "Quotation declined.", tone: "info" });
    } catch (e) {
      showSnack({
        message: e instanceof Error ? e.message : "Could not decline quotation.",
        tone: "error",
      });
    } finally {
      setBusy(false);
    }
  }

  async function doCancel() {
    setDialog(null);
    setBusy(true);
    try {
      const updated = await cancelQuotation(partyId, quotation.id);
      onUpdated(updated);
      showSnack({ message: "Quote request withdrawn.", tone: "info" });
    } catch (e) {
      showSnack({
        message: e instanceof Error ? e.message : "Could not withdraw request.",
        tone: "error",
      });
    } finally {
      setBusy(false);
    }
  }

  const role = "party"; // quotations are always party
  const pdfUrl = quotationPdfUrl(partyId, quotation.id);

  return (
    <>
      <div className="space-y-xl">
        {/* Status header */}
        <div className="flex items-start justify-between gap-md">
          <div className="space-y-xs flex-1 min-w-0">
            <div className="flex flex-wrap items-center gap-sm">
              <span className="text-title-md font-extrabold text-ink">{quotation.quotationNo}</span>
              <QuotationStatusBadge status={quotation.status} />
            </div>
            <p className="text-body-sm text-muted">
              {isRequested ? "Requested " : "Sent "}
              {formatDateTime(quotation.createdAt)}
            </p>
            {quotation.respondedAt && (
              <p className="text-body-sm text-muted">
                Responded {formatDateTime(quotation.respondedAt)}
              </p>
            )}
            {isAccepted && quotation.invoice && (
              <Link
                href={`/merchants/${role}/${partyId}/invoices/${quotation.invoice.id}`}
                className="inline-block text-body-sm font-bold text-success hover:underline"
              >
                Invoice {quotation.invoice.invoiceNo} added to your ledger →
              </Link>
            )}
            {isDeclined && quotation.declineNote && (
              <p className="text-body-sm text-muted italic">
                Reason: {quotation.declineNote}
              </p>
            )}
          </div>
          {/* PDF download */}
          <a
            href={pdfUrl}
            download
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex h-9 shrink-0 items-center gap-xs rounded-button bg-brand-soft px-md text-label-md font-bold text-brand hover:bg-brand hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
          >
            <Download size={14} />
            PDF
          </a>
        </div>

        <div className="h-px bg-hairline" />

        {/* Items */}
        <div>
          <p className="text-[10px] font-extrabold tracking-[1.4px] text-muted uppercase mb-xs">
            Items ({quotation.items.length})
          </p>
          <div className="border-t border-hairline">
            {quotation.items.map((line, i) => {
              const qtyStr = Number.isInteger(line.quantity)
                ? line.quantity.toString()
                : line.quantity.toFixed(2);
              const imgUrl = line.imageUrl
                ? line.imageUrl.startsWith("/images/")
                  ? `/api/media${line.imageUrl}`
                  : line.imageUrl
                : null;
              return (
                <div
                  key={i}
                  className={`flex items-center gap-md py-md ${i > 0 ? "border-t border-hairline" : ""}`}
                >
                  {/* Thumbnail */}
                  {imgUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={imgUrl}
                      alt={line.name}
                      className="h-10 w-10 shrink-0 rounded-md object-cover bg-hero-panel"
                    />
                  ) : (
                    <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-brand-soft">
                      <Package size={18} className="text-brand" />
                    </span>
                  )}
                  <div className="flex-1 min-w-0">
                    <p className="text-body-md font-bold text-ink truncate">{line.name}</p>
                    <p className="text-body-sm text-muted">
                      {qtyStr} × {formatINR(line.unitPrice, { decimals: 2 })}
                      {line.taxPercent > 0 ? ` · ${line.taxPercent}% GST` : ""}
                    </p>
                  </div>
                  <p className="text-body-md font-bold text-ink tabular-nums shrink-0">
                    {formatINR(line.lineTotal, { decimals: 2 })}
                  </p>
                </div>
              );
            })}
          </div>
        </div>

        <div className="h-px bg-hairline" />

        {/* Totals */}
        <div className="space-y-xs">
          <div className="flex justify-between py-xs">
            <span className="text-body-sm text-muted">Subtotal</span>
            <span className="text-body-sm font-bold text-ink tabular-nums">
              {formatINR(quotation.subtotal, { decimals: 2 })}
            </span>
          </div>
          <div className="flex justify-between py-xs">
            <span className="text-body-sm text-muted">GST</span>
            <span className="text-body-sm font-bold text-ink tabular-nums">
              {formatINR(quotation.taxAmount, { decimals: 2 })}
            </span>
          </div>
          <div className="h-px bg-hairline my-sm" />
          <div className="flex justify-between py-xs">
            <span className="text-body-md font-extrabold text-ink">Total</span>
            <span className="text-title-sm font-extrabold text-ink tabular-nums">
              {formatINR(quotation.total, { decimals: 2 })}
            </span>
          </div>
        </div>

        {/* Note */}
        {quotation.note && (
          <>
            <div className="h-px bg-hairline" />
            <div>
              <p className="text-[10px] font-extrabold tracking-[1.4px] text-muted uppercase mb-xs">
                {isRequested ? "Your note" : "Note from shop"}
              </p>
              <p className="text-body-md text-ink leading-relaxed">{quotation.note}</p>
            </div>
          </>
        )}

        {/* Status message */}
        {statusDesc && (
          <p className="text-body-sm text-muted text-center py-md border-t border-hairline">
            {statusDesc}
          </p>
        )}

        {/* Actions bottom bar */}
        {(isRequested || isPending) && (
          <div className="sticky bottom-0 border-t border-hairline bg-white pt-md pb-xl space-y-sm">
            {isRequested && (
              <button
                disabled={busy}
                onClick={() => setDialog("withdraw")}
                className="flex w-full h-11 items-center justify-center rounded-button border border-error text-label-md font-bold text-error hover:bg-error-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error disabled:opacity-50"
              >
                {busy ? "Working…" : "Withdraw request"}
              </button>
            )}
            {isPending && (
              <div className="flex gap-md">
                <button
                  disabled={busy}
                  onClick={() => setDialog("decline")}
                  className="flex-1 h-11 rounded-button border border-error text-label-md font-bold text-error hover:bg-error-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error disabled:opacity-50"
                >
                  Decline
                </button>
                <button
                  disabled={busy}
                  onClick={() => setDialog("accept")}
                  className="flex-[2] h-11 rounded-button bg-brand text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-50"
                >
                  {busy ? (
                    <span className="flex items-center justify-center gap-sm">
                      <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                      Working…
                    </span>
                  ) : (
                    `Accept · ${formatINR(quotation.total)}`
                  )}
                </button>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Dialogs */}
      {dialog === "accept" && (
        <AcceptDialog
          quotation={quotation}
          onConfirm={doAccept}
          onClose={() => setDialog(null)}
        />
      )}
      {dialog === "decline" && (
        <DeclineDialog onConfirm={doDecline} onClose={() => setDialog(null)} />
      )}
      {dialog === "withdraw" && (
        <WithdrawDialog onConfirm={doCancel} onClose={() => setDialog(null)} />
      )}

      <Snackbar snack={snack} />

      {/* Navigate to invoices after accept */}
      {isAccepted && quotation.invoice && (
        <div className="fixed inset-x-0 bottom-0 z-40 border-t border-hairline bg-white p-lg shadow-floating sm:hidden">
          <button
            onClick={() => router.push(`/merchants/party/${partyId}/invoices/${quotation.invoice!.id}`)}
            className="flex w-full h-10 items-center justify-center rounded-button bg-success text-label-md font-bold text-white"
          >
            View Invoice {quotation.invoice.invoiceNo}
          </button>
        </div>
      )}
    </>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

function QuotationDetailPageContent() {
  const params = useParams<{ role: string; id: string; qid: string }>();
  const role = params.role;
  const id = params.id;
  const qid = params.qid;
  const router = useRouter();

  const [quotation, setQuotation] = useState<Quotation | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (role !== "party") {
      router.replace(`/merchants/${role}/${id}/invoices`);
    }
  }, [role, id, router]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchQuotationDetail(id, qid);
      setQuotation(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load quotation.");
    } finally {
      setLoading(false);
    }
  }, [id, qid]);

  useEffect(() => {
    startTransition(() => { void load(); });
  }, [load]);

  return (
    <div className="mx-auto max-w-shell px-0 sm:px-lg py-xxxl">
      <div className="mx-auto max-w-content px-lg sm:px-0 pb-huge">
        {loading && !quotation && <QuotationDetailSkeleton />}

        {!loading && error && (
          <div className="flex flex-col items-center gap-md py-huge text-center">
            <AlertCircle size={40} className="text-error" />
            <p className="text-body-md text-muted">{error}</p>
            <button
              onClick={load}
              className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong"
            >
              Retry
            </button>
          </div>
        )}

        {!loading && !error && quotation && (
          <QuotationDetailView
            quotation={quotation}
            partyId={id}
            onUpdated={setQuotation}
          />
        )}
      </div>
    </div>
  );
}

export default function QuotationDetailPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <QuotationDetailPageContent />
    </RequireAuth>
  );
}
