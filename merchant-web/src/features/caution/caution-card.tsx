"use client";

import { useState } from "react";
import Link from "next/link";
import { Gavel, History, Inbox, Merge, PiggyBank, Plus, Undo2 } from "lucide-react";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { SelectField, TextAreaField, TextField } from "@/shared/ui/form";
import { formatINR } from "@/shared/money";
import {
  adjustCaution,
  depositCaution,
  forfeitCaution,
  refundCaution,
} from "./api";
import {
  CAUTION_MODES,
  GST_TREATMENTS,
  type CautionMode,
  type GstTreatment,
} from "./schema";

type Action = "deposit" | "refund" | "adjust" | "forfeit";

export type SetoffInvoice = { id: number; invoiceNo: string; total: number };

const MODE_LABELS: Record<CautionMode, string> = {
  CASH: "Cash",
  UPI: "UPI",
  NEFT: "NEFT",
  RTGS: "RTGS",
  CHEQUE: "Cheque",
  CARD: "Card",
  OTHER: "Other",
};

const GST_LABELS: Record<GstTreatment, string> = {
  NONE: "No GST",
  SUPPLY: "GST applies (treated as supply)",
};

/**
 * Actionable caution-deposit card for the party detail page: shows the held
 * balance and the Add / Refund / Set-off / Forfeit / Requests actions, each
 * backed by a modal. Calls `onChanged` after any successful write so the parent
 * can refresh the party balance.
 */
export function CautionCard({
  partyId,
  balance,
  invoices,
  onChanged,
}: {
  partyId: number;
  balance: number;
  invoices: SetoffInvoice[];
  onChanged: () => void;
}) {
  const [action, setAction] = useState<Action | null>(null);
  const hasBalance = balance > 0.005;

  return (
    <div className="rounded-lg border border-hairline p-lg">
      <div className="flex items-center gap-md">
        <span className="flex size-11 shrink-0 items-center justify-center rounded-lg bg-info-soft text-info">
          <PiggyBank size={22} />
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-label-md uppercase tracking-wide text-subtle">Caution deposit</p>
          <p className="text-body-sm text-muted">{hasBalance ? "Held on file" : "None on file"}</p>
        </div>
        <p className="text-headline-md font-bold text-info">{formatINR(balance)}</p>
      </div>

      <div className="mt-md grid grid-cols-2 gap-sm sm:grid-cols-3">
        <ActionButton icon={<Plus size={15} />} label="Add" onClick={() => setAction("deposit")} />
        <ActionButton
          icon={<Undo2 size={15} />}
          label="Refund"
          disabled={!hasBalance}
          onClick={() => setAction("refund")}
        />
        <ActionButton
          icon={<Merge size={15} />}
          label="Set off"
          disabled={!hasBalance}
          onClick={() => setAction("adjust")}
        />
        <ActionButton
          icon={<Gavel size={15} />}
          label="Forfeit"
          disabled={!hasBalance}
          onClick={() => setAction("forfeit")}
        />
        <Link
          href="/dashboard/caution-requests"
          className="inline-flex h-10 items-center justify-center gap-xs rounded-button border border-hairline px-sm text-label-md text-ink transition-colors hover:bg-surface-tint"
        >
          <Inbox size={15} /> Requests
        </Link>
        <Link
          href={`/dashboard/parties/${partyId}/caution`}
          className="inline-flex h-10 items-center justify-center gap-xs rounded-button border border-hairline px-sm text-label-md text-ink transition-colors hover:bg-surface-tint"
        >
          <History size={15} /> History
        </Link>
      </div>

      {action ? (
        <CautionActionModal
          action={action}
          partyId={partyId}
          balance={balance}
          invoices={invoices}
          onClose={() => setAction(null)}
          onDone={() => {
            setAction(null);
            onChanged();
          }}
        />
      ) : null}
    </div>
  );
}

function ActionButton({
  icon,
  label,
  onClick,
  disabled,
}: {
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className="inline-flex h-10 items-center justify-center gap-xs rounded-button border border-hairline px-sm text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled disabled:hover:bg-transparent"
    >
      {icon} {label}
    </button>
  );
}

const TITLES: Record<Action, string> = {
  deposit: "Add caution deposit",
  refund: "Refund caution",
  adjust: "Set off caution",
  forfeit: "Forfeit caution",
};

function CautionActionModal({
  action,
  partyId,
  balance,
  invoices,
  onClose,
  onDone,
}: {
  action: Action;
  partyId: number;
  balance: number;
  invoices: SetoffInvoice[];
  onClose: () => void;
  onDone: () => void;
}) {
  const [amount, setAmount] = useState(action === "forfeit" ? String(balance) : "");
  const [mode, setMode] = useState<CautionMode>("CASH");
  const [modeReference, setModeReference] = useState("");
  const [note, setNote] = useState("");
  const [gstTreatment, setGstTreatment] = useState<GstTreatment>("NONE");
  const [invoiceId, setInvoiceId] = useState<string>(invoices[0] ? String(invoices[0].id) : "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const amt = Number(amount);
  const capped = action === "refund" || action === "adjust" || action === "forfeit";
  const overBalance = capped && amt - balance > 0.005;
  const amountError =
    amount !== "" && (!Number.isFinite(amt) || amt <= 0)
      ? "Enter an amount above 0."
      : overBalance
        ? `Cannot exceed the held balance (${formatINR(balance)}).`
        : null;

  async function submit() {
    setError(null);
    if (!Number.isFinite(amt) || amt <= 0) return setError("Enter an amount above 0.");
    if (overBalance) return setError(`Cannot exceed the held balance (${formatINR(balance)}).`);
    if (action === "adjust" && !invoiceId) return setError("Pick an invoice to set off against.");

    setBusy(true);
    try {
      if (action === "deposit") {
        await depositCaution(partyId, { amount: amt, mode, modeReference: modeReference || null, note: note || null });
      } else if (action === "refund") {
        await refundCaution(partyId, { amount: amt, mode, modeReference: modeReference || null, note: note || null });
      } else if (action === "adjust") {
        await adjustCaution(partyId, { invoiceId: Number(invoiceId), amount: amt, note: note || null });
      } else {
        await forfeitCaution(partyId, { amount: amt, gstTreatment, note: note || null });
      }
      onDone();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save.");
      setBusy(false);
    }
  }

  const showMode = action === "deposit" || action === "refund";

  return (
    <Modal title={TITLES[action]} onClose={onClose} wide>
      {action === "refund" || action === "forfeit" ? (
        <p className="text-body-sm text-muted">Held on file: {formatINR(balance)}</p>
      ) : null}

      {error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="flex flex-col gap-md">
        {action === "adjust" ? (
          invoices.length === 0 ? (
            <p className="rounded-md bg-surface-tint px-md py-sm text-body-sm text-muted">
              No open sale invoices to set off against.
            </p>
          ) : (
            <SelectField
              label="Apply against invoice"
              value={invoiceId}
              onChange={setInvoiceId}
              options={invoices.map((i) => ({
                value: String(i.id),
                label: `${i.invoiceNo} · ${formatINR(i.total)}`,
              }))}
            />
          )
        ) : null}

        <TextField
          label="Amount (₹)"
          value={amount}
          onChange={setAmount}
          inputMode="decimal"
          error={amountError}
          helper={capped && !amountError ? `Up to ${formatINR(balance)}` : undefined}
        />

        {showMode ? (
          <>
            <SelectField<CautionMode>
              label="Mode"
              value={mode}
              onChange={setMode}
              options={CAUTION_MODES.map((m) => ({ value: m, label: MODE_LABELS[m] }))}
            />
            {mode !== "CASH" ? (
              <TextField
                label="Reference (txn / cheque no.)"
                value={modeReference}
                onChange={setModeReference}
              />
            ) : null}
          </>
        ) : null}

        {action === "forfeit" ? (
          <SelectField<GstTreatment>
            label="GST treatment"
            value={gstTreatment}
            onChange={setGstTreatment}
            options={GST_TREATMENTS.map((g) => ({ value: g, label: GST_LABELS[g] }))}
            helper="Forfeiture can attract GST as a deemed supply."
          />
        ) : null}

        <TextAreaField label="Note (optional)" value={note} onChange={setNote} rows={2} />
      </div>

      <ModalActions
        busy={busy}
        disabled={action === "adjust" && invoices.length === 0}
        danger={action === "forfeit"}
        confirmLabel={
          action === "deposit"
            ? "Add deposit"
            : action === "refund"
              ? "Refund"
              : action === "adjust"
                ? "Set off"
                : "Forfeit"
        }
        onCancel={onClose}
        onConfirm={submit}
      />
    </Modal>
  );
}
