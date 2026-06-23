"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Image from "next/image";
import {
  ImageOff, Minus, Plus, ScanBarcode, Trash2, Wifi, WifiOff, Loader2, CheckCircle2,
  Banknote, CreditCard, Smartphone, Pause, ListRestart, X, IndianRupee,
  Calculator, Undo2, LockOpen, Lock, Search, Printer, Percent, Clock, UserRound, ShieldCheck,
} from "lucide-react";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { formatINR2 } from "@/shared/money";
import { usePosSale } from "./use-pos-sale";
import type { ConnStatus, OpenSaleSummary, SaleLine, TenderMode } from "./types";
import {
  fetchCurrent, openShift, addCashMovement, closeShift, fetchReturnable, processReturn,
  authorizeOverride, isOverrideRequired,
  type ShiftReport, type Returnable,
} from "@/features/cashier/api";

/**
 * Supermarket-grade cashier terminal (DMart / Zudio / Star style): full-screen,
 * keyboard-first. The scan box is always focused; the running total is huge and
 * always visible; F-keys drive Pay / Hold / Recall. Built for speed at the till.
 *
 * Shortcuts: Enter = add scan · F2 = Pay · F4 = Hold · F5 = Recall · F8 = remove
 * last line · "3*<code>" or type 3 then * = quantity multiplier.
 */
export function PosTillView() {
  const pos = usePosSale();
  const [code, setCode] = useState("");
  const [pendingQty, setPendingQty] = useState<number | null>(null);
  const [tenderOpen, setTenderOpen] = useState(false);
  const [heldOpen, setHeldOpen] = useState(false);
  const [shiftModal, setShiftModal] = useState(false);
  const [returnsModal, setReturnsModal] = useState(false);
  const [shiftReport, setShiftReport] = useState<ShiftReport | null>(null);
  const [shiftLoaded, setShiftLoaded] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [discountLine, setDiscountLine] = useState<SaleLine | null>(null);
  const [overridePrompt, setOverridePrompt] = useState<{ retry: (token: string) => void } | null>(null);
  const [customer, setCustomer] = useState<{ name: string; phone: string }>({ name: "", phone: "" });
  const scanRef = useRef<HTMLInputElement>(null);

  // Shift status (also the billing gate — no scan/sell without an open shift).
  const loadShift = useCallback(async () => {
    try {
      const { report } = await fetchCurrent();
      setShiftReport(report);
    } catch {
      /* till still works without a shift */
    } finally {
      setShiftLoaded(true);
    }
  }, []);
  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const { report } = await fetchCurrent();
        if (active) setShiftReport(report);
      } catch {
        /* ignore */
      } finally {
        if (active) setShiftLoaded(true);
      }
    })();
    return () => { active = false; };
  }, []);

  const noShift = shiftLoaded && !shiftReport;
  const lines = pos.snapshot?.lines ?? [];
  const totals = pos.snapshot?.totals;
  const itemCount = totals?.itemCount ?? 0;
  const canPay = lines.length > 0 && pos.snapshot?.sale.status === "OPEN" && !noShift;

  const focusScan = useCallback(() => {
    if (!tenderOpen && !heldOpen && !shiftModal && !returnsModal && !searchOpen && !pos.unknownCode) scanRef.current?.focus();
  }, [tenderOpen, heldOpen, shiftModal, returnsModal, searchOpen, pos.unknownCode]);

  // Refocus the scan box on background clicks, but never steal focus from an
  // input/button the cashier is interacting with (e.g. a qty field).
  const onBgClick = useCallback((e: React.MouseEvent) => {
    if ((e.target as HTMLElement).closest("input,button")) return;
    focusScan();
  }, [focusScan]);

  useEffect(() => {
    focusScan();
  }, [focusScan, pos.snapshot?.sale.version]);

  // Submit a scan, honouring an inline "3*code" multiplier or a pending ×N qty.
  const submitScan = useCallback(() => {
    if (noShift) { setShiftModal(true); return; } // gate: open a shift first
    const raw = code.trim();
    if (!raw) return;
    let qty = pendingQty ?? 1;
    let barcode = raw;
    const m = raw.match(/^(\d+)\s*[*xX]\s*(.+)$/);
    if (m) {
      qty = Number(m[1]);
      barcode = m[2].trim();
    }
    void pos.scan(barcode, qty);
    setCode("");
    setPendingQty(null);
  }, [code, pendingQty, pos, noShift]);

  // "3*" on its own arms a quantity multiplier for the next scan.
  const onCodeChange = (v: string) => {
    const m = v.match(/^(\d+)\s*[*xX]$/);
    if (m) {
      setPendingQty(Number(m[1]));
      setCode("");
      return;
    }
    setCode(v);
  };

  // Global F-keys. Read live state from a ref so the listener is subscribed once
  // (no per-render re-binding, no stale closures).
  const keyStateRef = useRef({ canPay, lines, pos });
  useEffect(() => {
    keyStateRef.current = { canPay, lines, pos };
  });
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const { canPay, lines, pos } = keyStateRef.current;
      if (e.key === "F2" && canPay) { e.preventDefault(); setTenderOpen(true); }
      else if (e.key === "F3") { e.preventDefault(); setSearchOpen(true); }
      else if (e.key === "F4") { e.preventDefault(); void pos.holdAndNew(); }
      else if (e.key === "F5") { e.preventDefault(); setHeldOpen(true); }
      else if (e.key === "F8" && lines.length > 0) { e.preventDefault(); pos.removeItem(lines[lines.length - 1].productId); }
      else if (e.key === "Escape") { setTenderOpen(false); setHeldOpen(false); setSearchOpen(false); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  if (pos.checkout) return <PaidScreen title="Sale complete" sub={`Invoice ${pos.checkout.invoiceNo}`} total={Number(pos.checkout.total)} invoiceId={pos.checkout.invoiceId} />;
  if (pos.onlinePaid) return <PaidScreen title="Paid online" sub="Razorpay" total={pos.onlinePaid.amount} invoiceId={pos.onlinePaid.invoiceId ?? undefined} />;

  return (
    <div className="flex h-dvh min-h-[600px] w-full flex-col bg-canvas" onClick={onBgClick}>
      {/* Top bar */}
      <div className="flex items-center justify-between border-b border-hairline px-lg py-sm">
        <div className="flex items-center gap-sm">
          <ScanBarcode size={20} className="text-brand" />
          <span className="text-title-sm font-bold text-ink">Point of sale</span>
          <ConnBadge status={pos.status} />
          {shiftReport ? (
            <span className="ml-sm inline-flex items-center gap-xs rounded-button bg-surface-tint px-md py-xs text-label-md text-ink">
              <UserRound size={14} className="text-muted" />
              <span className="font-semibold">{shiftReport.shift.openedByName ?? "Cashier"}</span>
              {shiftReport.shift.openedByEmail ? <span className="hidden text-muted lg:inline">· {shiftReport.shift.openedByEmail}</span> : null}
              <Clock size={13} className="ml-xs text-muted" />
              <ShiftTimer since={shiftReport.shift.openedAt} />
            </span>
          ) : null}
        </div>
        <div className="flex items-center gap-sm">
          <button
            type="button"
            onClick={() => setShiftModal(true)}
            className={`inline-flex h-9 items-center gap-xs rounded-button px-md text-label-md ${shiftReport ? "bg-success-soft text-success" : "bg-warning-soft text-warning"}`}
          >
            <Calculator size={15} /> {shiftReport ? `Drawer ${formatINR2(shiftReport.cash.expected)}` : "Open shift"}
          </button>
          <button type="button" onClick={() => setReturnsModal(true)} className="inline-flex h-9 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint">
            <Undo2 size={15} /> Returns
          </button>
          <button type="button" onClick={() => void pos.holdAndNew()} className="inline-flex h-9 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint">
            <Pause size={15} /> Hold <kbd className="ml-xs text-subtle">F4</kbd>
          </button>
          <button type="button" onClick={() => setHeldOpen(true)} className="inline-flex h-9 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint">
            <ListRestart size={15} /> Recall <kbd className="ml-xs text-subtle">F5</kbd>
          </button>
        </div>
      </div>

      <div className="flex min-h-0 flex-1">
        {/* LEFT — the bill */}
        <div className="flex min-w-0 flex-1 flex-col border-r border-hairline">
          <div className="grid grid-cols-[2.5rem_1fr_7rem_6rem_4rem] gap-sm border-b border-hairline px-lg py-xs text-label-sm uppercase tracking-wide text-subtle">
            <span>#</span><span>Item</span><span className="text-center">Qty</span><span className="text-right">Amount</span><span />
          </div>
          <div className="min-h-0 flex-1 overflow-y-auto">
            {lines.length === 0 ? (
              <div className="flex h-full flex-col items-center justify-center gap-sm text-muted">
                {noShift ? (
                  <>
                    <Lock size={36} className="text-subtle" />
                    <p className="text-body-md">Open a shift to start billing</p>
                    <button type="button" onClick={() => setShiftModal(true)} className="mt-xs inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong"><LockOpen size={16} /> Open shift</button>
                  </>
                ) : (
                  <>
                    <ScanBarcode size={40} className="text-subtle" />
                    <p className="text-body-md">Scan the first item to begin</p>
                  </>
                )}
              </div>
            ) : (
              lines.map((l, i) => (
                <BillRow
                  key={l.productId}
                  index={i + 1}
                  line={l}
                  last={i === lines.length - 1}
                  onInc={() => pos.setQty(l.productId, l.quantity + 1)}
                  onDec={() => pos.setQty(l.productId, Math.max(0, l.quantity - 1))}
                  onSetQty={(q) => pos.setQty(l.productId, q)}
                  onDiscount={() => setDiscountLine(l)}
                  onRemove={() => pos.removeItem(l.productId)}
                />
              ))
            )}
          </div>
        </div>

        {/* RIGHT — total + scan + pay */}
        <div className="flex w-[380px] shrink-0 flex-col">
          <div className="flex flex-col gap-xs bg-hero-panel px-lg py-lg">
            <span className="text-label-md uppercase tracking-wide text-muted">Total payable</span>
            <span className="text-[2.75rem] font-bold leading-none text-ink">{formatINR2(totals?.total ?? 0)}</span>
            <div className="mt-xs flex items-center justify-between text-body-sm text-muted">
              <span>{itemCount} item{itemCount === 1 ? "" : "s"}</span>
              {totals && totals.discount > 0 ? <span className="text-success">Saved {formatINR2(totals.discount)}</span> : <span />}
            </div>
          </div>

          <div className="border-y border-hairline px-lg py-md">
            <div className="flex items-center gap-sm">
              {pendingQty != null ? (
                <span className="inline-flex h-11 shrink-0 items-center rounded-button bg-brand px-md text-title-sm font-bold text-white">×{pendingQty}</span>
              ) : null}
              <input
                ref={scanRef}
                value={code}
                onChange={(e) => onCodeChange(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); submitScan(); } }}
                autoFocus
                disabled={noShift}
                inputMode="text"
                placeholder={noShift ? "Open a shift to start billing" : "Scan / type barcode · 3∗code for qty"}
                className="h-11 w-full rounded-input border border-hairline bg-canvas px-md text-body-md text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-surface-tint"
              />
              <button type="button" title="Find item (F3)" disabled={noShift} onClick={() => setSearchOpen(true)} className="inline-flex size-11 shrink-0 items-center justify-center rounded-button border border-hairline text-ink hover:bg-surface-tint disabled:text-disabled"><Search size={18} /></button>
            </div>
            {pos.error ? <p className="mt-sm rounded-md bg-error-soft px-md py-xs text-body-sm text-error">{pos.error}</p> : null}
            {pos.pending > 0 ? <p className="mt-sm text-body-sm text-warning">{pos.pending} scan(s) queued offline</p> : null}

            {/* Customer (optional) + bill discount */}
            <div className="mt-sm grid grid-cols-2 gap-sm">
              <input value={customer.name} onChange={(e) => setCustomer((c) => ({ ...c, name: e.target.value }))} placeholder="Customer name" className="h-9 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
              <input value={customer.phone} onChange={(e) => setCustomer((c) => ({ ...c, phone: e.target.value }))} inputMode="tel" placeholder="Phone" className="h-9 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
            </div>
            <div className="mt-sm flex items-center gap-sm">
              <span className="text-label-md text-muted">Bill discount ₹</span>
              <BillDiscountInput
                key={pos.snapshot?.sale.headerDiscount ?? 0}
                value={pos.snapshot?.sale.headerDiscount ?? 0}
                onCommit={async (d) => {
                  const r = await pos.setHeaderDiscount(d);
                  if (r.overrideRequired) setOverridePrompt({ retry: (tok) => void pos.setHeaderDiscount(d, tok) });
                }}
                disabled={lines.length === 0}
              />
            </div>
          </div>

          <div className="flex flex-1 flex-col justify-end gap-sm p-lg">
            <button
              type="button"
              disabled={!canPay}
              onClick={() => setTenderOpen(true)}
              className="flex h-16 w-full items-center justify-center gap-sm rounded-lg bg-brand text-headline-sm font-bold text-white hover:bg-brand-strong disabled:bg-disabled"
            >
              <IndianRupee size={22} /> Pay {formatINR2(totals?.total ?? 0)} <kbd className="text-label-md opacity-80">F2</kbd>
            </button>
          </div>
        </div>
      </div>

      {pos.unknownCode ? (
        <Modal onClose={() => pos.clearUnknown()}>
          <QuickAddForm code={pos.unknownCode} onAdd={(v) => void pos.quickAdd(v)} onCancel={pos.clearUnknown} />
        </Modal>
      ) : null}

      {tenderOpen && totals ? (
        <TenderModal
          total={totals.total}
          paying={pos.paying}
          onClose={() => setTenderOpen(false)}
          onCash={() => { pos.doCheckout("CASH", undefined, customerArg(customer)); setTenderOpen(false); }}
          onTender={(mode) => { pos.doCheckout(mode, undefined, customerArg(customer)); setTenderOpen(false); }}
          onOnline={() => { setTenderOpen(false); void pos.payOnline(); }}
        />
      ) : null}

      {searchOpen ? (
        <SearchModal
          search={pos.searchProducts}
          onAdd={(id) => pos.addItem(id)}
          onClose={() => setSearchOpen(false)}
        />
      ) : null}

      {discountLine ? (
        <LineDiscountModal
          line={discountLine}
          onApply={async (amount) => {
            const productId = discountLine.productId;
            setDiscountLine(null);
            const r = await pos.setLineDiscount(productId, amount);
            if (r.overrideRequired) setOverridePrompt({ retry: (tok) => void pos.setLineDiscount(productId, amount, tok) });
          }}
          onClose={() => setDiscountLine(null)}
        />
      ) : null}

      {overridePrompt ? (
        <ManagerAuthModal
          onClose={() => setOverridePrompt(null)}
          onAuthorized={(token) => { overridePrompt.retry(token); setOverridePrompt(null); }}
        />
      ) : null}

      {heldOpen ? (
        <HeldBillsModal
          listOpen={pos.listOpen}
          onRecall={(id) => { void pos.recall(id); setHeldOpen(false); }}
          onClose={() => setHeldOpen(false)}
        />
      ) : null}

      {shiftModal ? <ShiftModal onClose={() => { setShiftModal(false); void loadShift(); }} /> : null}
      {returnsModal ? <ReturnsModal onClose={() => { setReturnsModal(false); void loadShift(); }} onNeedManager={(retry) => setOverridePrompt({ retry })} /> : null}
    </div>
  );
}

/** Shift + cash drawer, in the till. Open a shift, record cash in/out, see the
 *  live X-report, and close with a counted-cash reconciliation. */
function ShiftModal({ onClose }: { onClose: () => void }) {
  const [report, setReport] = useState<ShiftReport | null>(null);
  const [hasShift, setHasShift] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [float, setFloat] = useState("");
  const [mvType, setMvType] = useState<"PAY_IN" | "PAY_OUT" | "DROP">("PAY_IN");
  const [mvAmount, setMvAmount] = useState("");
  const [mvReason, setMvReason] = useState("");
  const [counted, setCounted] = useState("");

  const load = useCallback(async () => {
    try {
      const { shift, report } = await fetchCurrent();
      setHasShift(!!shift);
      setReport(report);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load the shift.");
      setHasShift(false);
    }
  }, []);
  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const { shift, report } = await fetchCurrent();
        if (!active) return;
        setHasShift(!!shift);
        setReport(report);
      } catch (e) {
        if (active) { setError(e instanceof Error ? e.message : "Could not load the shift."); setHasShift(false); }
      }
    })();
    return () => { active = false; };
  }, []);

  const run = async (fn: () => Promise<void>) => {
    setBusy(true); setError(null);
    try { await fn(); } catch (e) { setError(e instanceof Error ? e.message : "Something went wrong."); } finally { setBusy(false); }
  };

  const expected = report?.cash.expected ?? 0;
  const variance = counted === "" ? null : Number(counted) - expected;

  return (
    <Modal onClose={onClose}>
      <div className="w-[460px] max-w-full">
        <div className="flex items-center justify-between">
          <h2 className="flex items-center gap-sm text-title-md text-ink"><Calculator size={18} /> Shift &amp; cash drawer</h2>
          <button type="button" onClick={onClose} className="text-muted hover:text-ink"><X size={18} /></button>
        </div>
        {error ? <p className="mt-sm rounded-md bg-error-soft px-md py-xs text-body-sm text-error">{error}</p> : null}

        {hasShift === null ? (
          <p className="py-xl text-center text-body-md text-muted">Loading…</p>
        ) : !hasShift ? (
          <div className="mt-lg">
            <label className="block text-label-md text-muted">Opening float (₹)</label>
            <input value={float} onChange={(e) => setFloat(e.target.value)} inputMode="decimal" placeholder="0.00" autoFocus className="mt-xs h-11 w-full rounded-input border border-hairline bg-canvas px-md text-body-md text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
            <button type="button" disabled={busy} onClick={() => run(async () => { await openShift(Number(float) || 0); await load(); })} className="mt-md inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"><LockOpen size={16} /> Open shift</button>
          </div>
        ) : (
          <div className="mt-lg flex flex-col gap-md">
            {report ? (
              <div className="rounded-lg bg-hero-panel p-md">
                <Row label="Opening float" value={formatINR2(report.cash.openingFloat)} />
                <Row label="Cash sales" value={formatINR2(report.cash.cashSales)} />
                <Row label="Pay-ins" value={formatINR2(report.cash.payIns)} />
                <Row label="Pay-outs" value={`− ${formatINR2(report.cash.payOuts)}`} />
                <Row label="Drops" value={`− ${formatINR2(report.cash.drops)}`} />
                <Row label="Refunds" value={`− ${formatINR2(report.cash.refunds)}`} />
                <div className="mt-xs flex items-center justify-between border-t border-hairline pt-xs">
                  <span className="text-title-sm font-bold text-ink">Expected in drawer</span>
                  <span className="text-title-sm font-bold text-ink">{formatINR2(expected)}</span>
                </div>
              </div>
            ) : null}

            <div>
              <p className="text-label-md text-muted">Cash drawer</p>
              <div className="mt-xs flex gap-sm">
                {(["PAY_IN", "PAY_OUT", "DROP"] as const).map((t) => (
                  <button key={t} type="button" onClick={() => setMvType(t)} className={`inline-flex h-9 items-center rounded-button px-md text-label-md ${mvType === t ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"}`}>{t === "PAY_IN" ? "Pay in" : t === "PAY_OUT" ? "Pay out" : "Drop"}</button>
                ))}
              </div>
              <div className="mt-sm flex gap-sm">
                <input value={mvAmount} onChange={(e) => setMvAmount(e.target.value)} inputMode="decimal" placeholder="Amount ₹" className="h-10 w-28 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
                <input value={mvReason} onChange={(e) => setMvReason(e.target.value)} placeholder="Reason" className="h-10 flex-1 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
                <button type="button" disabled={busy || !(Number(mvAmount) > 0)} onClick={() => run(async () => { const r = await addCashMovement({ type: mvType, amount: Number(mvAmount), reason: mvReason.trim() || undefined }); setReport(r); setMvAmount(""); setMvReason(""); })} className="inline-flex h-10 items-center rounded-button bg-brand px-md text-label-md text-white hover:bg-brand-strong disabled:bg-disabled">Record</button>
              </div>
            </div>

            <div className="border-t border-hairline pt-md">
              <p className="flex items-center gap-xs text-label-md text-muted"><Lock size={14} /> Close shift</p>
              <div className="mt-xs flex gap-sm">
                <input value={counted} onChange={(e) => setCounted(e.target.value)} inputMode="decimal" placeholder="Counted cash ₹" className="h-10 flex-1 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
                <button type="button" disabled={busy || counted === ""} onClick={() => run(async () => { await closeShift({ countedCash: Number(counted) || 0 }); onClose(); })} className="inline-flex h-10 items-center rounded-button bg-ink px-md text-label-md text-white hover:opacity-90 disabled:bg-disabled">Close</button>
              </div>
              {variance !== null ? <p className={`mt-xs text-body-sm ${variance === 0 ? "text-success" : "text-warning"}`}>Variance {variance > 0 ? "+" : ""}{formatINR2(variance)} {variance === 0 ? "(balanced)" : variance > 0 ? "(over)" : "(short)"}</p> : null}
            </div>
          </div>
        )}
      </div>
    </Modal>
  );
}

/** Process a return without leaving the till. */
function ReturnsModal({ onClose, onNeedManager }: { onClose: () => void; onNeedManager: (retry: (token: string) => void) => void }) {
  const [invoiceId, setInvoiceId] = useState("");
  const [returnable, setReturnable] = useState<Returnable | null>(null);
  const [qty, setQty] = useState<Record<number, string>>({});
  const [refundMode, setRefundMode] = useState<"CASH" | "UPI" | "CARD" | "OTHER">("CASH");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  const run = async (fn: () => Promise<void>) => {
    setBusy(true); setError(null);
    try { await fn(); } catch (e) { setError(e instanceof Error ? e.message : "Something went wrong."); } finally { setBusy(false); }
  };

  // Returns are privileged: on OVERRIDE_REQUIRED, ask for a manager grant + retry.
  const submitReturn = async (token?: string) => {
    if (!returnable) return;
    const lines = returnable.lines.map((l) => ({ productId: l.productId, quantity: Number(qty[l.productId]) || 0 })).filter((l) => l.quantity > 0);
    if (lines.length === 0) { setError("Enter a quantity to return."); return; }
    setBusy(true); setError(null);
    try {
      const res = await processReturn({ originalInvoiceId: returnable.invoiceId, refundMode, lines, override: token });
      setDone(`Credit note ${res.creditNoteNo} · refund ${formatINR2(res.refundAmount)}`);
      setReturnable(null); setQty({});
    } catch (e) {
      if (isOverrideRequired(e)) onNeedManager((tok) => void submitReturn(tok));
      else setError(e instanceof Error ? e.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal onClose={onClose}>
      <div className="w-[460px] max-w-full">
        <div className="flex items-center justify-between">
          <h2 className="flex items-center gap-sm text-title-md text-ink"><Undo2 size={18} /> Returns</h2>
          <button type="button" onClick={onClose} className="text-muted hover:text-ink"><X size={18} /></button>
        </div>
        {error ? <p className="mt-sm rounded-md bg-error-soft px-md py-xs text-body-sm text-error">{error}</p> : null}
        {done ? <p className="mt-sm rounded-md bg-success-soft px-md py-xs text-body-sm text-success">{done}</p> : null}

        <div className="mt-md flex gap-sm">
          <input value={invoiceId} onChange={(e) => setInvoiceId(e.target.value)} inputMode="numeric" placeholder="Original invoice id" autoFocus className="h-10 flex-1 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
          <button type="button" disabled={busy || !invoiceId} onClick={() => run(async () => { setDone(null); setReturnable(await fetchReturnable(Number(invoiceId))); setQty({}); })} className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint disabled:text-disabled">Look up</button>
        </div>

        {returnable ? (
          <div className="mt-md">
            <p className="text-body-sm text-muted">{returnable.invoiceNo} · {formatINR2(returnable.total)}</p>
            <ul className="mt-sm flex max-h-64 flex-col gap-px overflow-y-auto overflow-x-hidden rounded-md border border-hairline">
              {returnable.lines.map((l) => (
                <li key={l.productId} className="flex items-center gap-sm bg-canvas px-md py-sm">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-title-sm text-ink">{l.name}</p>
                    <p className="text-body-sm text-muted">returnable {l.returnableQty} · {formatINR2(l.unitPrice)}</p>
                  </div>
                  <input value={qty[l.productId] ?? ""} onChange={(e) => setQty((q) => ({ ...q, [l.productId]: e.target.value }))} inputMode="numeric" placeholder="0" disabled={l.returnableQty <= 0} className="h-9 w-16 rounded-input border border-hairline bg-canvas px-sm text-center text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-surface-tint" />
                </li>
              ))}
            </ul>
            <div className="mt-sm flex flex-wrap items-center gap-sm">
              <span className="text-label-md text-muted">Refund via</span>
              {(["CASH", "UPI", "CARD", "OTHER"] as const).map((m) => (
                <button key={m} type="button" onClick={() => setRefundMode(m)} className={`inline-flex h-9 items-center rounded-button px-md text-label-md ${refundMode === m ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"}`}>{m}</button>
              ))}
            </div>
            <button
              type="button"
              disabled={busy}
              onClick={() => void submitReturn()}
              className="mt-sm inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
            >
              <Undo2 size={16} /> Process return
            </button>
          </div>
        ) : null}
      </div>
    </Modal>
  );
}

function BillRow({ index, line, last, onInc, onDec, onSetQty, onDiscount, onRemove }: { index: number; line: SaleLine; last: boolean; onInc: () => void; onDec: () => void; onSetQty: (q: number) => void; onDiscount: () => void; onRemove: () => void }) {
  const src = mediaSrc(line.imageUrl);
  return (
    <div className={`grid grid-cols-[2.5rem_1fr_7rem_6rem_4rem] items-center gap-sm px-lg py-sm ${last ? "bg-brand-soft" : ""}`}>
      <span className="text-body-sm text-subtle">{index}</span>
      <div className="flex min-w-0 items-center gap-sm">
        <div className="relative size-9 shrink-0 overflow-hidden rounded-md bg-hero-panel">
          {src ? <Image src={src} alt="" fill unoptimized className="object-cover" sizes="36px" /> : <div className="flex size-full items-center justify-center text-subtle"><ImageOff size={14} /></div>}
        </div>
        <div className="min-w-0">
          <p className="truncate text-title-sm font-semibold text-ink">{line.name}</p>
          <p className="truncate text-body-sm text-muted">{formatINR2(line.unitPrice)} · {line.sku}{line.lineDiscount > 0 ? ` · −${formatINR2(line.lineDiscount)}` : ""}</p>
        </div>
      </div>
      <div className="flex items-center justify-center gap-xs">
        <button type="button" onClick={onDec} aria-label="Decrease" className="inline-flex size-7 items-center justify-center rounded-button border border-hairline text-ink hover:bg-surface-tint"><Minus size={13} /></button>
        <QtyInput key={line.quantity} value={line.quantity} onCommit={onSetQty} />
        <button type="button" onClick={onInc} aria-label="Increase" className="inline-flex size-7 items-center justify-center rounded-button border border-hairline text-ink hover:bg-surface-tint"><Plus size={13} /></button>
      </div>
      <span className="text-right text-title-sm font-bold text-ink">{formatINR2(line.total)}</span>
      <div className="flex items-center justify-end gap-xs">
        <button type="button" onClick={onDiscount} aria-label="Line discount" title="Line discount" className={`inline-flex size-7 items-center justify-center rounded-button ${line.lineDiscount > 0 ? "text-brand" : "text-muted"} hover:bg-surface-tint`}><Percent size={13} /></button>
        <button type="button" onClick={onRemove} aria-label="Remove" className="inline-flex size-7 items-center justify-center rounded-button text-muted hover:text-error"><Trash2 size={14} /></button>
      </div>
    </div>
  );
}

/** Directly type a line quantity (0 removes it). Commits on Enter/blur. Remounted
 *  via `key={quantity}` by the parent, so it always seeds from the latest value. */
function QtyInput({ value, onCommit }: { value: number; onCommit: (q: number) => void }) {
  const [text, setText] = useState(String(value));
  const commit = () => {
    const n = Number(text);
    if (!Number.isFinite(n) || n < 0) { setText(String(value)); return; }
    if (n !== value) onCommit(n);
  };
  return (
    <input
      value={text}
      onChange={(e) => setText(e.target.value.replace(/[^\d.]/g, ""))}
      onFocus={(e) => e.target.select()}
      onBlur={commit}
      onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); (e.target as HTMLInputElement).blur(); } }}
      inputMode="decimal"
      aria-label="Quantity"
      className="w-12 rounded-button border border-hairline bg-canvas py-px text-center text-title-sm font-bold text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    />
  );
}

function TenderModal({ total, paying, onClose, onCash, onTender, onOnline }: { total: number; paying: boolean; onClose: () => void; onCash: (received: number) => void; onTender: (m: TenderMode) => void; onOnline: () => void }) {
  const [received, setReceived] = useState("");
  const recv = Number(received);
  // Round the change-due to paise so float subtraction (e.g. 100 - 33.33)
  // can't surface a ₹0.0000001 artefact. Display-only — the sale total is
  // server-authoritative.
  const change = recv > 0 ? Math.round((recv - total) * 100) / 100 : 0;
  const quick = [total, Math.ceil(total / 100) * 100, Math.ceil(total / 500) * 500].filter((v, i, a) => a.indexOf(v) === i);
  return (
    <Modal onClose={onClose}>
      <div className="w-[440px] max-w-full">
        <div className="flex items-center justify-between">
          <h2 className="text-title-md text-ink">Collect {formatINR2(total)}</h2>
          <button type="button" onClick={onClose} className="text-muted hover:text-ink"><X size={18} /></button>
        </div>

        <p className="mt-lg text-label-md text-muted">Cash</p>
        <input
          value={received}
          onChange={(e) => setReceived(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter" && recv >= total) onCash(recv); }}
          autoFocus
          inputMode="decimal"
          placeholder="Cash received ₹"
          className="mt-xs h-12 w-full rounded-input border border-hairline bg-canvas px-md text-headline-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
        <div className="mt-sm flex flex-wrap gap-sm">
          {quick.map((v) => (
            <button key={v} type="button" onClick={() => setReceived(String(v))} className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint">{formatINR2(v)}</button>
          ))}
        </div>
        {recv > 0 ? (
          <div className="mt-md flex items-center justify-between rounded-lg bg-hero-panel px-md py-sm">
            <span className="text-body-md text-muted">Change due</span>
            <span className={`text-headline-sm font-bold ${change < 0 ? "text-error" : "text-success"}`}>{formatINR2(Math.max(0, change))}</span>
          </div>
        ) : null}
        <button
          type="button"
          disabled={recv < total}
          onClick={() => onCash(recv)}
          className="mt-md flex h-12 w-full items-center justify-center gap-sm rounded-button bg-brand text-title-sm font-bold text-white hover:bg-brand-strong disabled:bg-disabled"
        >
          <Banknote size={18} /> Cash — done
        </button>

        <p className="mt-lg text-label-md text-muted">Other tenders</p>
        <div className="mt-xs grid grid-cols-3 gap-sm">
          <button type="button" onClick={() => onTender("UPI")} className="inline-flex h-11 items-center justify-center gap-xs rounded-button border border-hairline text-label-md text-ink hover:bg-surface-tint"><Smartphone size={16} /> UPI</button>
          <button type="button" onClick={() => onTender("CARD")} className="inline-flex h-11 items-center justify-center gap-xs rounded-button border border-hairline text-label-md text-ink hover:bg-surface-tint"><CreditCard size={16} /> Card</button>
          <button type="button" disabled={paying} onClick={onOnline} className="inline-flex h-11 items-center justify-center gap-xs rounded-button border border-brand text-label-md text-brand hover:bg-brand-soft disabled:opacity-50"><IndianRupee size={16} /> Online</button>
        </div>
      </div>
    </Modal>
  );
}

function HeldBillsModal({ listOpen, onRecall, onClose }: { listOpen: () => Promise<OpenSaleSummary[]>; onRecall: (id: number) => void; onClose: () => void }) {
  const [bills, setBills] = useState<OpenSaleSummary[] | null>(null);
  useEffect(() => {
    let active = true;
    void listOpen().then((b) => { if (active) setBills(b); });
    return () => { active = false; };
  }, [listOpen]);
  return (
    <Modal onClose={onClose}>
      <div className="w-[440px] max-w-full">
        <div className="flex items-center justify-between">
          <h2 className="text-title-md text-ink">Held bills</h2>
          <button type="button" onClick={onClose} className="text-muted hover:text-ink"><X size={18} /></button>
        </div>
        {bills == null ? (
          <p className="py-xl text-center text-body-md text-muted">Loading…</p>
        ) : bills.length === 0 ? (
          <p className="py-xl text-center text-body-md text-muted">No held bills.</p>
        ) : (
          <ul className="mt-md flex flex-col gap-px overflow-hidden rounded-lg border border-hairline">
            {bills.map((b) => (
              <li key={b.id}>
                <button type="button" onClick={() => onRecall(b.id)} className="flex w-full items-center justify-between bg-canvas px-md py-sm text-left hover:bg-surface-tint">
                  <span className="text-title-sm text-ink">{b.customerName ?? `Bill #${b.id}`}</span>
                  <span className="text-body-sm text-muted">{b.lineCount} item{b.lineCount === 1 ? "" : "s"}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </Modal>
  );
}

function Modal({ children, onClose }: { children: React.ReactNode; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 px-lg" onClick={onClose}>
      <div className="rounded-lg border border-hairline bg-canvas p-xl" onClick={(e) => e.stopPropagation()}>{children}</div>
    </div>
  );
}

/** A manager enters their own credentials in person to authorise a privileged
 *  till action (discount / void / price override / return) that the signed-in
 *  cashier lacks the `invoices:override` right for. On success it hands back a
 *  short-lived grant token that the caller replays with the original command. */
function ManagerAuthModal({ onClose, onAuthorized }: { onClose: () => void; onAuthorized: (token: string) => void }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    if (!email.trim() || !password || busy) return;
    setBusy(true); setError(null);
    try {
      const grant = await authorizeOverride(email.trim(), password);
      onAuthorized(grant.token);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Authorisation failed.");
      setBusy(false);
    }
  };

  return (
    <Modal onClose={onClose}>
      <div className="w-[400px] max-w-full">
        <div className="flex items-center justify-between gap-md">
          <h2 className="flex items-center gap-sm text-title-md text-ink"><ShieldCheck size={18} /> Manager authorisation</h2>
          <button type="button" onClick={onClose} className="text-muted hover:text-ink"><X size={18} /></button>
        </div>
        <p className="mt-xs text-body-sm text-muted">A manager must approve this action. Enter manager credentials below.</p>
        {error ? <p className="mt-md rounded-button bg-error/10 px-md py-sm text-body-sm text-error">{error}</p> : null}
        <label className="mt-lg block text-label-md text-muted">Manager email</label>
        <input
          type="email"
          autoFocus
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter") void submit(); }}
          className="mt-xs h-10 w-full rounded-button border border-hairline px-md text-body-md text-ink focus-visible:border-brand focus-visible:outline-none"
        />
        <label className="mt-md block text-label-md text-muted">Password</label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter") void submit(); }}
          className="mt-xs h-10 w-full rounded-button border border-hairline px-md text-body-md text-ink focus-visible:border-brand focus-visible:outline-none"
        />
        <div className="mt-lg flex items-center justify-end gap-sm">
          <button type="button" onClick={onClose} className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint">Cancel</button>
          <button
            type="button"
            disabled={busy || !email.trim() || !password}
            onClick={() => void submit()}
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
          >
            <ShieldCheck size={16} /> {busy ? "Authorising…" : "Authorise"}
          </button>
        </div>
      </div>
    </Modal>
  );
}

function QuickAddForm({ code, onAdd, onCancel }: { code: string; onAdd: (v: { code: string; name: string; sellingPrice: number; taxPercent?: number; openingStock?: number }) => void; onCancel: () => void }) {
  const [name, setName] = useState("");
  const [price, setPrice] = useState("");
  const [tax, setTax] = useState("");
  const [stock, setStock] = useState("1");
  const sellingPrice = Number(price);
  const valid = name.trim().length > 0 && sellingPrice > 0;
  return (
    <form
      className="w-[440px] max-w-full"
      onSubmit={(e) => { e.preventDefault(); if (!valid) return; onAdd({ code, name: name.trim(), sellingPrice, taxPercent: tax ? Number(tax) : undefined, openingStock: stock ? Number(stock) : undefined }); }}
    >
      <h2 className="text-title-md text-ink">New item · {code}</h2>
      <p className="mt-xs text-body-sm text-muted">Not in the catalogue — add it and ring it up.</p>
      <div className="mt-md grid grid-cols-2 gap-sm">
        <input value={name} onChange={(e) => setName(e.target.value)} autoFocus placeholder="Name" className="col-span-2 h-10 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
        <input value={price} onChange={(e) => setPrice(e.target.value)} inputMode="decimal" placeholder="Price ₹" className="h-10 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
        <input value={tax} onChange={(e) => setTax(e.target.value)} inputMode="decimal" placeholder="GST %" className="h-10 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
        <input value={stock} onChange={(e) => setStock(e.target.value)} inputMode="decimal" placeholder="On hand" className="col-span-2 h-10 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
      </div>
      <div className="mt-md flex items-center gap-sm">
        <button type="submit" disabled={!valid} className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled">Add to cart</button>
        <button type="button" onClick={onCancel} className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint">Cancel</button>
      </div>
    </form>
  );
}

/** Per-line discount (₹ or quick %). Amount caps at the line's gross. */
function LineDiscountModal({ line, onApply, onClose }: { line: SaleLine; onApply: (amount: number) => void; onClose: () => void }) {
  const gross = line.unitPrice * line.quantity;
  const [text, setText] = useState(line.lineDiscount ? String(line.lineDiscount) : "");
  const apply = () => {
    const n = Math.min(Math.max(Number(text || "0"), 0), gross);
    if (Number.isFinite(n)) onApply(n);
  };
  return (
    <Modal onClose={onClose}>
      <div className="w-[360px] max-w-full">
        <div className="flex items-center justify-between">
          <h2 className="text-title-md text-ink">Line discount</h2>
          <button type="button" onClick={onClose} className="text-muted hover:text-ink"><X size={18} /></button>
        </div>
        <p className="mt-xs truncate text-body-sm text-muted">{line.name} · {formatINR2(gross)}</p>
        <input
          value={text}
          onChange={(e) => setText(e.target.value.replace(/[^\d.]/g, ""))}
          onKeyDown={(e) => { if (e.key === "Enter") apply(); }}
          autoFocus
          inputMode="decimal"
          placeholder="Discount ₹"
          className="mt-md h-11 w-full rounded-input border border-hairline bg-canvas px-md text-body-md text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
        <div className="mt-sm flex flex-wrap gap-sm">
          {[5, 10, 20].map((pct) => (
            <button key={pct} type="button" onClick={() => setText((Math.round(gross * pct) / 100).toFixed(2))} className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint">{pct}%</button>
          ))}
          <button type="button" onClick={() => setText("")} className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-muted hover:bg-surface-tint">Clear</button>
        </div>
        <button type="button" onClick={apply} className="mt-md inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong">Apply</button>
      </div>
    </Modal>
  );
}

/** Live elapsed-since-open timer for the open shift (HH:MM:SS). */
function ShiftTimer({ since }: { since: string }) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);
  const ms = Math.max(0, now - new Date(since).getTime());
  const pad = (n: number) => String(n).padStart(2, "0");
  const h = Math.floor(ms / 3_600_000);
  const m = Math.floor((ms % 3_600_000) / 60_000);
  const s = Math.floor((ms % 60_000) / 1000);
  return <span className="tabular-nums font-semibold text-ink">{pad(h)}:{pad(m)}:{pad(s)}</span>;
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between py-px text-body-sm">
      <span className="text-muted">{label}</span>
      <span className="text-ink">{value}</span>
    </div>
  );
}

function ConnBadge({ status }: { status: ConnStatus }) {
  const map: Record<ConnStatus, { label: string; cls: string; icon: typeof Wifi; spin?: boolean }> = {
    live: { label: "Live", cls: "bg-success-soft text-success", icon: Wifi },
    connecting: { label: "Connecting", cls: "bg-surface-tint text-muted", icon: Loader2, spin: true },
    reconnecting: { label: "Reconnecting", cls: "bg-warning-soft text-warning", icon: Loader2, spin: true },
    offline: { label: "Offline", cls: "bg-error-soft text-error", icon: WifiOff },
  };
  const { label, cls, icon: Icon, spin } = map[status];
  return <span className={`inline-flex h-7 items-center gap-xs rounded-button px-sm text-label-sm ${cls}`}><Icon size={13} className={spin ? "animate-spin" : ""} /> {label}</span>;
}

function PaidScreen({ title, sub, total, invoiceId }: { title: string; sub: string; total: number; invoiceId?: number }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === "Enter") window.location.reload(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);
  return (
    <div className="flex min-h-[70vh] w-full flex-col items-center justify-center px-lg py-xxxl text-center">
      <span className="flex size-16 items-center justify-center rounded-full bg-success-soft text-success"><CheckCircle2 size={32} /></span>
      <h1 className="mt-lg text-headline-md text-ink">{title}</h1>
      <p className="mt-xs text-body-md text-muted">{sub} · {formatINR2(total)}</p>
      <div className="mt-xl flex items-center gap-sm">
        {invoiceId != null ? (
          <button type="button" onClick={() => window.open(`/api/invoices/${invoiceId}/pdf`, "_blank")} className="inline-flex h-12 items-center gap-sm rounded-button border border-hairline px-lg text-title-sm text-ink hover:bg-surface-tint"><Printer size={18} /> Print receipt</button>
        ) : null}
        <button type="button" onClick={() => window.location.reload()} className="inline-flex h-12 items-center rounded-button bg-brand px-xl text-title-sm font-bold text-white hover:bg-brand-strong">New sale <kbd className="ml-sm opacity-80">Enter</kbd></button>
      </div>
    </div>
  );
}

/** {name,phone} for checkout, or undefined when the cashier left it blank. */
function customerArg(c: { name: string; phone: string }): { name?: string; phone?: string } | undefined {
  const name = c.name.trim();
  const phone = c.phone.trim();
  if (!name && !phone) return undefined;
  return { name: name || undefined, phone: phone || undefined };
}

/** Bill-level discount (₹). Commits on Enter/blur; remounted via key on change. */
function BillDiscountInput({ value, onCommit, disabled }: { value: number; onCommit: (d: number) => void; disabled: boolean }) {
  const [text, setText] = useState(value ? String(value) : "");
  const commit = () => {
    const n = Number(text || "0");
    if (!Number.isFinite(n) || n < 0) { setText(value ? String(value) : ""); return; }
    if (n !== value) onCommit(n);
  };
  return (
    <input
      value={text}
      onChange={(e) => setText(e.target.value.replace(/[^\d.]/g, ""))}
      onBlur={commit}
      onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); (e.target as HTMLInputElement).blur(); } }}
      disabled={disabled}
      inputMode="decimal"
      placeholder="0"
      className="h-9 w-24 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-surface-tint"
    />
  );
}

/** Add an item without a barcode: type → pick from catalogue search. */
function SearchModal({ search, onAdd, onClose }: { search: (term: string) => Promise<import("./types").ProductSearchResult[]>; onAdd: (productId: number) => void; onClose: () => void }) {
  const [term, setTerm] = useState("");
  const [results, setResults] = useState<import("./types").ProductSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const seqRef = useRef(0);
  useEffect(() => () => { if (timerRef.current) clearTimeout(timerRef.current); }, []);

  // Debounce in the change handler (event handlers may setState; effects can't
  // synchronously) so the lint rule stays happy and the UX stays snappy.
  const onTermChange = (v: string) => {
    setTerm(v);
    if (timerRef.current) clearTimeout(timerRef.current);
    const t = v.trim();
    if (!t) { setResults([]); setSearching(false); return; }
    setSearching(true);
    const seq = ++seqRef.current;
    timerRef.current = setTimeout(async () => {
      const r = await search(t);
      if (seq === seqRef.current) { setResults(r); setSearching(false); }
    }, 200);
  };
  return (
    <Modal onClose={onClose}>
      <div className="w-[460px] max-w-full">
        <div className="flex items-center justify-between">
          <h2 className="flex items-center gap-sm text-title-md text-ink"><Search size={18} /> Find item</h2>
          <button type="button" onClick={onClose} className="text-muted hover:text-ink"><X size={18} /></button>
        </div>
        <input value={term} onChange={(e) => onTermChange(e.target.value)} autoFocus placeholder="Type a product name or SKU" className="mt-md h-11 w-full rounded-input border border-hairline bg-canvas px-md text-body-md text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
        <ul className="mt-sm flex max-h-72 flex-col gap-px overflow-y-auto overflow-x-hidden rounded-md border border-hairline">
          {searching && results.length === 0 ? (
            <li className="px-md py-sm text-body-sm text-muted">Searching…</li>
          ) : results.length === 0 ? (
            <li className="px-md py-sm text-body-sm text-subtle">{term.trim() ? "No matches." : "Start typing to search."}</li>
          ) : (
            results.map((p) => (
              <li key={p.id}>
                <button type="button" onClick={() => onAdd(p.id)} className="flex w-full items-center justify-between bg-canvas px-md py-sm text-left hover:bg-surface-tint">
                  <span className="min-w-0">
                    <span className="block truncate text-title-sm text-ink">{p.name}</span>
                    <span className="block truncate text-body-sm text-muted">{p.sku} · stock {p.stock}</span>
                  </span>
                  <span className="ml-sm shrink-0 text-title-sm font-bold text-ink">{formatINR2(p.sellingPrice)}</span>
                </button>
              </li>
            ))
          )}
        </ul>
        <p className="mt-sm text-body-sm text-subtle">Tap an item to add it to the bill.</p>
      </div>
    </Modal>
  );
}
