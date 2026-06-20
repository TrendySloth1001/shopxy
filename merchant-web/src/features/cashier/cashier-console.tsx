"use client";

import { useCallback, useEffect, useState } from "react";
import { Calculator, RefreshCw, LockOpen, Lock, ArrowDownToLine, ArrowUpFromLine, Banknote, Undo2, History, Printer, X } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { formatINR2 } from "@/shared/money";
import {
  fetchCurrent,
  openShift,
  addCashMovement,
  closeShift,
  fetchReturnable,
  processReturn,
  listShifts,
  fetchShiftReport,
  type Shift,
  type ShiftReport,
  type ShiftSummary,
  type Returnable,
} from "./api";

export function CashierConsole() {
  const [shift, setShift] = useState<Shift | null>(null);
  const [report, setReport] = useState<ShiftReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    try {
      const { shift, report } = await fetchCurrent();
      setShift(shift);
      setReport(report);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load the till.");
    } finally {
      setLoading(false);
    }
  }, []);

  // Initial load via an inline IIFE (state is only set after the await, so the
  // effect never sets state synchronously). `load` stays for buttons/mutations.
  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const { shift, report } = await fetchCurrent();
        if (!active) return;
        setShift(shift);
        setReport(report);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the till.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  const run = useCallback(async (fn: () => Promise<unknown>) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  }, []);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader icon={Calculator} tone="indigo" title="Cashier" subtitle="Open a till shift, manage the cash drawer, reconcile, and handle returns.">
        <button
          type="button"
          onClick={() => void load()}
          className="inline-flex h-10 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint"
        >
          <RefreshCw size={15} /> Refresh
        </button>
      </PageHeader>

      {error ? <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p> : null}

      {shift && shift.status === "OPEN" ? (
        <div className="mt-md flex flex-wrap items-center gap-sm rounded-lg bg-surface-tint px-md py-sm text-body-sm">
          <span className="font-semibold text-ink">{shift.openedByName ?? "Cashier"}</span>
          {shift.openedByEmail ? <span className="text-muted">· {shift.openedByEmail}</span> : null}
          <span className="text-muted">· shift open for</span>
          <ConsoleTimer since={shift.openedAt} />
        </div>
      ) : null}

      {loading ? (
        <p className="py-xxxl text-center text-body-md text-muted">Loading…</p>
      ) : !shift || shift.status !== "OPEN" ? (
        <OpenShiftCard
          busy={busy}
          onOpen={(float) => run(async () => {
            const s = await openShift(float);
            setShift(s);
            await load();
          })}
        />
      ) : (
        <div className="mt-lg grid grid-cols-1 gap-xl lg:grid-cols-[1fr_360px]">
          <div className="flex flex-col gap-xl">
            {report ? <ReportPanel report={report} /> : null}
            <ReturnsPanel busy={busy} run={run} onChanged={load} />
          </div>
          <div className="flex flex-col gap-xl">
            <CashMovementForm
              busy={busy}
              onSubmit={(input) => run(async () => setReport(await addCashMovement(input)))}
            />
            <CloseShiftForm
              expected={report?.cash.expected ?? 0}
              busy={busy}
              onClose={(countedCash, note) => run(async () => {
                await closeShift({ countedCash, note });
                await load();
              })}
            />
          </div>
        </div>
      )}

      <ShiftHistory />
    </div>
  );
}

/** Live elapsed-since-open timer (HH:MM:SS). */
function ConsoleTimer({ since }: { since: string }) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);
  const ms = Math.max(0, now - new Date(since).getTime());
  const pad = (n: number) => String(n).padStart(2, "0");
  return (
    <span className="tabular-nums font-semibold text-ink">
      {pad(Math.floor(ms / 3_600_000))}:{pad(Math.floor((ms % 3_600_000) / 60_000))}:{pad(Math.floor((ms % 60_000) / 1000))}
    </span>
  );
}

/** Past shifts = the Z-receipt archive. Tap one to view/print its Z-report. */
function ShiftHistory() {
  const [shifts, setShifts] = useState<ShiftSummary[] | null>(null);
  const [viewing, setViewing] = useState<ShiftReport | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const s = await listShifts();
        if (active) setShifts(s);
      } catch (e) {
        if (active) setErr(e instanceof Error ? e.message : "Could not load shift history.");
      }
    })();
    return () => { active = false; };
  }, []);

  const view = async (id: number) => {
    setErr(null);
    try {
      setViewing(await fetchShiftReport(id));
    } catch (e) {
      setErr(e instanceof Error ? e.message : "Could not load the Z-report.");
    }
  };

  return (
    <div className="mt-xl rounded-lg border border-hairline p-lg">
      <h2 className="flex items-center gap-sm text-title-md text-ink"><History size={18} /> Past shifts · Z-receipts</h2>
      {err ? <p className="mt-sm rounded-md bg-error-soft px-md py-xs text-body-sm text-error">{err}</p> : null}
      {shifts == null ? (
        <p className="mt-md text-body-sm text-muted">Loading…</p>
      ) : shifts.length === 0 ? (
        <p className="mt-md text-body-sm text-subtle">No shifts yet.</p>
      ) : (
        <div className="mt-md overflow-x-auto">
          <table className="w-full text-body-sm">
            <thead>
              <tr className="text-left text-label-sm uppercase tracking-wide text-subtle">
                <th className="py-xs pr-md font-normal">Opened</th>
                <th className="py-xs pr-md font-normal">Cashier</th>
                <th className="py-xs pr-md font-normal">Status</th>
                <th className="py-xs pr-md text-right font-normal">Expected</th>
                <th className="py-xs pr-md text-right font-normal">Counted</th>
                <th className="py-xs pr-md text-right font-normal">Variance</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {shifts.map((s) => (
                <tr key={s.id} className="border-t border-hairline">
                  <td className="py-sm pr-md text-ink">{new Date(s.openedAt).toLocaleString("en-IN")}</td>
                  <td className="py-sm pr-md text-ink">{s.openedByName ?? "—"}</td>
                  <td className="py-sm pr-md"><span className={s.status === "OPEN" ? "text-success" : "text-muted"}>{s.status}</span></td>
                  <td className="py-sm pr-md text-right text-ink">{s.expectedCash == null ? "—" : formatINR2(s.expectedCash)}</td>
                  <td className="py-sm pr-md text-right text-ink">{s.closingCounted == null ? "—" : formatINR2(s.closingCounted)}</td>
                  <td className={`py-sm pr-md text-right ${s.variance == null ? "text-subtle" : s.variance === 0 ? "text-success" : "text-warning"}`}>{s.variance == null ? "—" : formatINR2(s.variance)}</td>
                  <td className="py-sm text-right"><button type="button" onClick={() => void view(s.id)} className="inline-flex h-8 items-center rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint">View Z-report</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {viewing ? <ZReportModal report={viewing} onClose={() => setViewing(null)} /> : null}
    </div>
  );
}

function ZReportModal({ report, onClose }: { report: ShiftReport; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 px-lg" onClick={onClose}>
      <div className="max-h-[85vh] w-[460px] max-w-full overflow-y-auto rounded-lg border border-hairline bg-canvas p-lg" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h2 className="text-title-md text-ink">Z-report</h2>
          <div className="flex items-center gap-sm">
            <button type="button" onClick={() => printZReport(report)} className="inline-flex h-9 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint"><Printer size={15} /> Print</button>
            <button type="button" onClick={onClose} className="text-muted hover:text-ink"><X size={18} /></button>
          </div>
        </div>
        <div className="mt-md">
          <ReportPanel report={report} />
        </div>
      </div>
    </div>
  );
}

/** Open a print-friendly Z-receipt in a new window and trigger print. */
function printZReport(r: ShiftReport) {
  const rows: Array<[string, string]> = [
    ["Opening float", formatINR2(r.cash.openingFloat)],
    ["Cash sales", formatINR2(r.cash.cashSales)],
    ["Pay-ins", formatINR2(r.cash.payIns)],
    ["Pay-outs", "-" + formatINR2(r.cash.payOuts)],
    ["Drops", "-" + formatINR2(r.cash.drops)],
    ["Refunds", "-" + formatINR2(r.cash.refunds)],
    ["Expected in drawer", formatINR2(r.cash.expected)],
    ["Counted", r.cash.counted == null ? "—" : formatINR2(r.cash.counted)],
    ["Variance", r.cash.variance == null ? "—" : formatINR2(r.cash.variance)],
    ["Sales", `${r.sales.count} · ${formatINR2(r.sales.gross)}`],
    ["GST CGST", formatINR2(r.gst.cgst)],
    ["GST SGST", formatINR2(r.gst.sgst)],
    ["GST IGST", formatINR2(r.gst.igst)],
  ];
  const body = rows.map(([k, v]) => `<tr><td>${k}</td><td style="text-align:right">${v}</td></tr>`).join("");
  const html = `<html><head><title>Z-report</title><style>body{font-family:monospace;padding:16px;max-width:320px}h3{text-align:center}table{width:100%;border-collapse:collapse}td{padding:2px 0}</style></head><body><h3>Z-REPORT</h3><table>${body}</table><script>window.onload=function(){window.print()}</script></body></html>`;
  const w = window.open("", "_blank", "width=380,height=600");
  if (w) { w.document.write(html); w.document.close(); }
}

function OpenShiftCard({ busy, onOpen }: { busy: boolean; onOpen: (float: number) => void }) {
  const [float, setFloat] = useState("");
  return (
    <div className="mt-lg max-w-form rounded-lg border border-hairline p-xl">
      <h2 className="flex items-center gap-sm text-title-md text-ink"><LockOpen size={18} /> Open a shift</h2>
      <p className="mt-xs text-body-sm text-muted">Count the cash in the drawer and enter it as the opening float.</p>
      <label className="mt-lg block text-label-md text-muted">Opening float (₹)</label>
      <input
        value={float}
        onChange={(e) => setFloat(e.target.value)}
        inputMode="decimal"
        placeholder="0.00"
        className="mt-xs h-11 w-full rounded-input border border-hairline bg-canvas px-md text-body-md text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      />
      <button
        type="button"
        disabled={busy}
        onClick={() => onOpen(Number(float) || 0)}
        className="mt-lg inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
      >
        <LockOpen size={16} /> Open shift
      </button>
    </div>
  );
}

function ReportPanel({ report }: { report: ShiftReport }) {
  const c = report.cash;
  return (
    <div className="rounded-lg border border-hairline p-lg">
      <h2 className="text-title-md text-ink">Shift report (X)</h2>
      <p className="mt-xs text-body-sm text-muted">
        {report.sales.count} sale{report.sales.count === 1 ? "" : "s"} · {formatINR2(report.sales.gross)} gross
      </p>

      <Divider className="my-md" />
      <h3 className="text-label-md text-muted">Cash drawer</h3>
      <div className="mt-sm flex flex-col gap-xs">
        <Row label="Opening float" value={formatINR2(c.openingFloat)} />
        <Row label="Cash sales" value={formatINR2(c.cashSales)} />
        <Row label="Pay-ins" value={formatINR2(c.payIns)} />
        <Row label="Pay-outs" value={`− ${formatINR2(c.payOuts)}`} />
        <Row label="Drops" value={`− ${formatINR2(c.drops)}`} />
        <Row label="Refunds" value={`− ${formatINR2(c.refunds)}`} />
        <div className="flex items-center justify-between border-t border-hairline pt-xs">
          <span className="text-title-sm font-bold text-ink">Expected in drawer</span>
          <span className="text-title-sm font-bold text-ink">{formatINR2(c.expected)}</span>
        </div>
      </div>

      <Divider className="my-md" />
      <h3 className="text-label-md text-muted">Tenders</h3>
      <div className="mt-sm flex flex-col gap-xs">
        {report.tenders.length === 0 ? (
          <p className="text-body-sm text-subtle">No sales yet.</p>
        ) : (
          report.tenders.map((t) => <Row key={t.mode} label={`${t.mode} (${t.count})`} value={formatINR2(t.amount)} />)
        )}
      </div>

      <Divider className="my-md" />
      <h3 className="text-label-md text-muted">GST collected</h3>
      <div className="mt-sm flex flex-col gap-xs">
        <Row label="Taxable" value={formatINR2(report.gst.taxable)} />
        {report.gst.cgst > 0 ? <Row label="CGST" value={formatINR2(report.gst.cgst)} /> : null}
        {report.gst.sgst > 0 ? <Row label="SGST" value={formatINR2(report.gst.sgst)} /> : null}
        {report.gst.igst > 0 ? <Row label="IGST" value={formatINR2(report.gst.igst)} /> : null}
        {report.gst.cess > 0 ? <Row label="Cess" value={formatINR2(report.gst.cess)} /> : null}
        {report.gstByRate.map((r) => (
          <Row key={r.rate} label={`@ ${r.rate}% — taxable`} value={`${formatINR2(r.taxable)} · tax ${formatINR2(r.tax)}`} />
        ))}
      </div>

      {report.returns.count > 0 ? (
        <>
          <Divider className="my-md" />
          <Row label={`Returns (${report.returns.count})`} value={`− ${formatINR2(report.returns.amount)}`} />
        </>
      ) : null}
    </div>
  );
}

function CashMovementForm({ busy, onSubmit }: { busy: boolean; onSubmit: (i: { type: "PAY_IN" | "PAY_OUT" | "DROP"; amount: number; reason?: string }) => void }) {
  const [type, setType] = useState<"PAY_IN" | "PAY_OUT" | "DROP">("PAY_IN");
  const [amount, setAmount] = useState("");
  const [reason, setReason] = useState("");
  const icons = { PAY_IN: ArrowDownToLine, PAY_OUT: ArrowUpFromLine, DROP: Banknote } as const;
  const Icon = icons[type];
  return (
    <div className="rounded-lg border border-hairline p-lg">
      <h2 className="text-title-md text-ink">Cash drawer</h2>
      <div className="mt-sm flex flex-wrap gap-sm">
        {(["PAY_IN", "PAY_OUT", "DROP"] as const).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setType(t)}
            className={`inline-flex h-9 items-center rounded-button px-md text-label-md ${type === t ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"}`}
          >
            {t === "PAY_IN" ? "Pay in" : t === "PAY_OUT" ? "Pay out" : "Drop"}
          </button>
        ))}
      </div>
      <input value={amount} onChange={(e) => setAmount(e.target.value)} inputMode="decimal" placeholder="Amount ₹" className="mt-sm h-10 w-full rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
      <input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Reason (optional)" className="mt-sm h-10 w-full rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
      <button
        type="button"
        disabled={busy || !(Number(amount) > 0)}
        onClick={() => { onSubmit({ type, amount: Number(amount), reason: reason.trim() || undefined }); setAmount(""); setReason(""); }}
        className="mt-sm inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
      >
        <Icon size={16} /> Record
      </button>
    </div>
  );
}

function CloseShiftForm({ expected, busy, onClose }: { expected: number; busy: boolean; onClose: (counted: number, note?: string) => void }) {
  const [counted, setCounted] = useState("");
  const [note, setNote] = useState("");
  const variance = counted === "" ? null : Number(counted) - expected;
  return (
    <div className="rounded-lg border border-hairline p-lg">
      <h2 className="flex items-center gap-sm text-title-md text-ink"><Lock size={18} /> Close shift</h2>
      <p className="mt-xs text-body-sm text-muted">Expected in drawer: <span className="font-semibold text-ink">{formatINR2(expected)}</span></p>
      <label className="mt-md block text-label-md text-muted">Counted cash (₹)</label>
      <input value={counted} onChange={(e) => setCounted(e.target.value)} inputMode="decimal" placeholder="0.00" className="mt-xs h-10 w-full rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
      {variance !== null ? (
        <p className={`mt-sm text-body-sm ${variance === 0 ? "text-success" : "text-warning"}`}>
          Variance: {variance > 0 ? "+" : ""}{formatINR2(variance)} {variance === 0 ? "(balanced)" : variance > 0 ? "(over)" : "(short)"}
        </p>
      ) : null}
      <input value={note} onChange={(e) => setNote(e.target.value)} placeholder="Note (optional)" className="mt-sm h-10 w-full rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
      <button
        type="button"
        disabled={busy || counted === ""}
        onClick={() => onClose(Number(counted) || 0, note.trim() || undefined)}
        className="mt-sm inline-flex h-10 items-center gap-sm rounded-button bg-ink px-lg text-label-md text-white hover:opacity-90 disabled:bg-disabled"
      >
        <Lock size={16} /> Close &amp; print Z-report
      </button>
    </div>
  );
}

function ReturnsPanel({ busy, run, onChanged }: { busy: boolean; run: (fn: () => Promise<unknown>) => Promise<void>; onChanged: () => Promise<void> }) {
  const [invoiceId, setInvoiceId] = useState("");
  const [returnable, setReturnable] = useState<Returnable | null>(null);
  const [qty, setQty] = useState<Record<number, string>>({});
  const [refundMode, setRefundMode] = useState<"CASH" | "UPI" | "CARD" | "OTHER">("CASH");
  const [done, setDone] = useState<string | null>(null);

  return (
    <div className="rounded-lg border border-hairline p-lg">
      <h2 className="flex items-center gap-sm text-title-md text-ink"><Undo2 size={18} /> Returns</h2>
      <div className="mt-sm flex gap-sm">
        <input value={invoiceId} onChange={(e) => setInvoiceId(e.target.value)} inputMode="numeric" placeholder="Original invoice id" className="h-10 flex-1 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
        <button
          type="button"
          disabled={busy || !invoiceId}
          onClick={() => run(async () => { setDone(null); setReturnable(await fetchReturnable(Number(invoiceId))); setQty({}); })}
          className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint disabled:text-disabled"
        >
          Look up
        </button>
      </div>

      {done ? <p className="mt-sm rounded-md bg-success-soft px-md py-sm text-body-sm text-success">{done}</p> : null}

      {returnable ? (
        <div className="mt-md">
          <p className="text-body-sm text-muted">{returnable.invoiceNo} · {formatINR2(returnable.total)}{returnable.customerName ? ` · ${returnable.customerName}` : ""}</p>
          <ul className="mt-sm flex flex-col gap-px overflow-hidden rounded-md border border-hairline">
            {returnable.lines.map((l) => (
              <li key={l.productId} className="flex items-center gap-sm bg-canvas px-md py-sm">
                <div className="min-w-0 flex-1">
                  <p className="truncate text-title-sm text-ink">{l.name}</p>
                  <p className="text-body-sm text-muted">sold {l.soldQty} · returnable {l.returnableQty} · {formatINR2(l.unitPrice)}</p>
                </div>
                <input
                  value={qty[l.productId] ?? ""}
                  onChange={(e) => setQty((q) => ({ ...q, [l.productId]: e.target.value }))}
                  inputMode="numeric"
                  placeholder="0"
                  disabled={l.returnableQty <= 0}
                  className="h-9 w-16 rounded-input border border-hairline bg-canvas px-sm text-center text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-surface-tint"
                />
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
            onClick={() => run(async () => {
              const lines = returnable.lines
                .map((l) => ({ productId: l.productId, quantity: Number(qty[l.productId]) || 0 }))
                .filter((l) => l.quantity > 0);
              if (lines.length === 0) throw new Error("Enter a quantity to return.");
              const res = await processReturn({ originalInvoiceId: returnable.invoiceId, refundMode, lines });
              setDone(`Credit note ${res.creditNoteNo} · refund ${formatINR2(res.refundAmount)}${res.cashDrawerAdjusted ? " (drawer adjusted)" : ""}`);
              setReturnable(null);
              setQty({});
              await onChanged();
            })}
            className="mt-sm inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
          >
            <Undo2 size={16} /> Process return
          </button>
        </div>
      ) : null}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between text-body-sm">
      <span className="text-muted">{label}</span>
      <span className="text-ink">{value}</span>
    </div>
  );
}
