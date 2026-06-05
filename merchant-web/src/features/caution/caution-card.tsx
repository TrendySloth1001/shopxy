"use client";

import { useState } from "react";
import Link from "next/link";
import { Gavel, History, Inbox, Info, Merge, PiggyBank, Plus, Undo2 } from "lucide-react";
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
  const [infoOpen, setInfoOpen] = useState(false);
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
        <button
          type="button"
          onClick={() => setInfoOpen(true)}
          aria-label="About caution deposits"
          className="inline-flex size-9 shrink-0 items-center justify-center rounded-button text-subtle transition-colors hover:bg-surface-tint hover:text-ink"
        >
          <Info size={16} />
        </button>
      </div>

      {/* Actions — content-sized chips, never stretched (see CLAUDE.md). */}
      <div className="mt-md flex flex-wrap items-center gap-sm">
        <ActionButton icon={<Plus size={15} />} label="Add" tone="success" onClick={() => setAction("deposit")} />
        <ActionButton
          icon={<Undo2 size={15} />}
          label="Refund"
          tone="error"
          disabled={!hasBalance}
          onClick={() => setAction("refund")}
        />
        <ActionButton
          icon={<Merge size={15} />}
          label="Set off"
          tone="indigo"
          disabled={!hasBalance}
          onClick={() => setAction("adjust")}
        />
        <ActionButton
          icon={<Gavel size={15} />}
          label="Forfeit"
          tone="error"
          disabled={!hasBalance}
          onClick={() => setAction("forfeit")}
        />
        <Link
          href="/dashboard/caution-requests"
          className="inline-flex h-10 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-accent-indigo-soft"
        >
          <Inbox size={15} className="text-accent-indigo" /> Requests
        </Link>
        <Link
          href={`/dashboard/parties/${partyId}/caution`}
          className="inline-flex h-10 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
        >
          <History size={15} className="text-muted" /> History
        </Link>
      </div>

      {infoOpen ? <CautionInfoModal onClose={() => setInfoOpen(false)} /> : null}

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

type Tone = "success" | "error" | "indigo" | "neutral";

const TONE_ICON: Record<Tone, string> = {
  success: "text-success",
  error: "text-error",
  indigo: "text-accent-indigo",
  neutral: "text-muted",
};
const TONE_HOVER: Record<Tone, string> = {
  success: "hover:bg-success-soft",
  error: "hover:bg-error-soft",
  indigo: "hover:bg-accent-indigo-soft",
  neutral: "hover:bg-surface-tint",
};

function ActionButton({
  icon,
  label,
  tone,
  onClick,
  disabled,
}: {
  icon: React.ReactNode;
  label: string;
  tone: Tone;
  onClick: () => void;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={`inline-flex h-10 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink transition-colors disabled:text-disabled disabled:hover:bg-transparent ${TONE_HOVER[tone]}`}
    >
      <span className={disabled ? "text-disabled" : TONE_ICON[tone]}>{icon}</span>
      {label}
    </button>
  );
}

function CautionInfoModal({ onClose }: { onClose: () => void }) {
  return (
    <Modal title="Caution deposits" onClose={onClose}>
      <p className="text-body-md text-muted">
        A caution deposit is security money a customer places with you. The card shows the running balance you
        hold for them and every movement on it.
      </p>
      <div className="flex flex-col gap-md">
        <InfoRow icon={<Plus size={16} />} tone="success" title="Deposit" body="Money taken in — increases the balance you hold." />
        <InfoRow icon={<Undo2 size={16} />} tone="error" title="Refund" body="Money returned to the customer — reduces the held balance." />
        <InfoRow icon={<Merge size={16} />} tone="indigo" title="Set off" body="Part of the deposit applied against one of their invoices." />
        <InfoRow icon={<Gavel size={16} />} tone="error" title="Forfeit" body="Amount you keep, e.g. on breach of terms. GST may apply on forfeiture." />
      </div>
    </Modal>
  );
}

function InfoRow({
  icon,
  tone,
  title,
  body,
}: {
  icon: React.ReactNode;
  tone: Tone;
  title: string;
  body: string;
}) {
  const puck: Record<Tone, string> = {
    success: "bg-success-soft text-success",
    error: "bg-error-soft text-error",
    indigo: "bg-accent-indigo-soft text-accent-indigo",
    neutral: "bg-surface-tint text-muted",
  };
  return (
    <div className="flex items-start gap-md">
      <span className={`flex size-8 shrink-0 items-center justify-center rounded-full ${puck[tone]}`}>{icon}</span>
      <div className="min-w-0">
        <p className="text-body-md text-ink">{title}</p>
        <p className="text-body-sm text-muted">{body}</p>
      </div>
    </div>
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
