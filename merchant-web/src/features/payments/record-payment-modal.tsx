"use client";

import { useState } from "react";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { DateTimeField, SelectField, TextAreaField, TextField } from "@/shared/ui/form";
import { nowIso } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import { createPayment } from "./api";
import { PAYMENT_MODES, PAYMENT_MODE_LABELS } from "./schema";

/**
 * Record a payment — a RECEIPT (money in from a party) or a PAYMENT (money out
 * to a vendor), optionally allocated to an invoice. Mirrors the Flutter
 * `RecordPaymentSheet`. When `max` is supplied (invoice "Mark as paid") the
 * amount is pre-filled and capped at the outstanding; the backend remains the
 * authority on over-allocation.
 */
export function RecordPaymentModal({
  kind,
  partyId,
  vendorId,
  invoiceId,
  max,
  title,
  onClose,
  onDone,
}: {
  kind: "RECEIPT" | "PAYMENT";
  partyId?: string;
  vendorId?: string;
  invoiceId?: string;
  max?: number;
  title?: string;
  onClose: () => void;
  onDone: () => void;
}) {
  const [amount, setAmount] = useState(max != null && max > 0 ? String(max) : "");
  const [mode, setMode] = useState<string>("CASH");
  const [modeReference, setModeReference] = useState("");
  const [paymentDate, setPaymentDate] = useState<string | null>(nowIso());
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const amountNum = Number(amount);
  const valid = Number.isFinite(amountNum) && amountNum > 0;

  async function submit() {
    setError(null);
    if (!valid) return setError("Enter an amount greater than zero.");
    setBusy(true);
    try {
      await createPayment({
        type: kind,
        amount: amountNum,
        mode,
        modeReference: mode === "CASH" ? undefined : modeReference.trim() || undefined,
        paymentDate: paymentDate ?? undefined,
        partyId,
        vendorId,
        invoiceId,
        note: note.trim() || undefined,
      });
      onDone();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not record the payment.");
    } finally {
      setBusy(false);
    }
  }

  const heading = title ?? (kind === "RECEIPT" ? "Record receipt" : "Record payment");

  return (
    <Modal title={heading} onClose={onClose}>
      <p className="text-body-md text-muted">
        {kind === "RECEIPT"
          ? "Money received from this customer."
          : "Money paid to this vendor."}
        {max != null && max > 0 ? ` Outstanding ${formatINR2(max)}.` : ""}
      </p>
      {error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}
      <TextField
        label="Amount (₹)"
        value={amount}
        onChange={setAmount}
        inputMode="decimal"
        placeholder="0.00"
      />
      <SelectField
        label="Mode"
        value={mode}
        onChange={setMode}
        options={PAYMENT_MODES.map((m) => ({ value: m, label: PAYMENT_MODE_LABELS[m] ?? m }))}
      />
      {mode !== "CASH" ? (
        <TextField
          label="Reference"
          value={modeReference}
          onChange={setModeReference}
          placeholder="UPI / cheque / txn reference"
          helper="Optional — helps you reconcile later."
        />
      ) : null}
      <DateTimeField label="Date" value={paymentDate} onChange={setPaymentDate} />
      <TextAreaField label="Note (optional)" value={note} onChange={setNote} rows={2} />
      <ModalActions
        busy={busy}
        disabled={!valid}
        confirmLabel="Record"
        onCancel={onClose}
        onConfirm={submit}
      />
    </Modal>
  );
}
