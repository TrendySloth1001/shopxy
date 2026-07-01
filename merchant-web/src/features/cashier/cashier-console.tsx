"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Calculator, RefreshCw, LockOpen, Lock, ArrowDownToLine, ArrowUpFromLine, Banknote, Undo2, History, Printer, X } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { formatINR2, parseAmount } from "@/shared/money";
import { useAuth } from "@/features/auth/auth-context";
import { isShopOwner } from "@/features/auth/capabilities";
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
  const t = useTranslations("cashier");
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
      setError(e instanceof Error ? e.message : t("errors.loadTill"));
    } finally {
      setLoading(false);
    }
  }, [t]);

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
        if (active) setError(e instanceof Error ? e.message : t("errors.loadTill"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [t]);

  const run = useCallback(async (fn: () => Promise<unknown>) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("errors.generic"));
    } finally {
      setBusy(false);
    }
  }, [t]);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader icon={Calculator} tone="indigo" title={t("title")} subtitle={t("subtitle")}>
        <button
          type="button"
          onClick={() => void load()}
          className="inline-flex h-10 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint"
        >
          <RefreshCw size={15} /> {t("actions.refresh")}
        </button>
      </PageHeader>

      {error ? <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p> : null}

      {shift && shift.status === "OPEN" ? (
        <div className="mt-md flex flex-wrap items-center gap-sm rounded-lg bg-surface-tint px-md py-sm text-body-sm">
          <span className="font-semibold text-ink">{shift.openedByName ?? t("cashierRole")}</span>
          {shift.openedByEmail ? <span className="text-muted">· {shift.openedByEmail}</span> : null}
          <span className="text-muted">· {t("banner.shiftOpenFor")}</span>
          <ConsoleTimer since={shift.openedAt} />
        </div>
      ) : null}

      {loading ? (
        <p className="py-xxxl text-center text-body-md text-muted">{t("loading")}</p>
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
  const t = useTranslations("cashier");
  const { user } = useAuth();
  // Owners + managers (the override right) see every employee's Z-reports;
  // a plain cashier sees only their own. The backend enforces this scope —
  // this only adjusts the copy so each role knows what they're looking at.
  const seesAll =
    isShopOwner(user) || (user?.shopPermissions ?? []).includes("invoices:override");
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
        if (active) setErr(e instanceof Error ? e.message : t("errors.loadHistory"));
      }
    })();
    return () => { active = false; };
  }, [t]);

  const view = async (id: number) => {
    setErr(null);
    try {
      setViewing(await fetchShiftReport(id));
    } catch (e) {
      setErr(e instanceof Error ? e.message : t("errors.loadZReport"));
    }
  };

  return (
    <div className="mt-xl rounded-lg border border-hairline p-lg">
      <h2 className="flex items-center gap-sm text-title-md text-ink"><History size={18} /> {t("history.title")}</h2>
      <p className="mt-xs text-body-sm text-muted">
        {seesAll
          ? t("history.subtitleAll")
          : t("history.subtitleOwn")}
      </p>
      {err ? <p className="mt-sm rounded-md bg-error-soft px-md py-xs text-body-sm text-error">{err}</p> : null}
      {shifts == null ? (
        <p className="mt-md text-body-sm text-muted">{t("loading")}</p>
      ) : shifts.length === 0 ? (
        <p className="mt-md text-body-sm text-subtle">{t("history.empty")}</p>
      ) : (
        <div className="mt-md overflow-x-auto">
          <table className="w-full text-body-sm">
            <thead>
              <tr className="text-left text-label-sm uppercase tracking-wide text-subtle">
                <th className="py-xs pr-md font-normal">{t("history.colOpened")}</th>
                <th className="py-xs pr-md font-normal">{t("history.colCashier")}</th>
                <th className="py-xs pr-md font-normal">{t("history.colStatus")}</th>
                <th className="py-xs pr-md text-right font-normal">{t("history.colExpected")}</th>
                <th className="py-xs pr-md text-right font-normal">{t("history.colCounted")}</th>
                <th className="py-xs pr-md text-right font-normal">{t("history.colVariance")}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {shifts.map((s) => (
                <tr key={s.id} className="border-t border-hairline">
                  <td className="py-sm pr-md text-ink">{new Date(s.openedAt).toLocaleString("en-IN")}</td>
                  <td className="py-sm pr-md text-ink">
                    <span className="block">{s.openedByName ?? "—"}</span>
                    {s.openedByEmail ? <span className="block text-label-sm text-subtle">{s.openedByEmail}</span> : null}
                  </td>
                  <td className="py-sm pr-md"><span className={s.status === "OPEN" ? "text-success" : "text-muted"}>{s.status === "OPEN" ? t("status.open") : s.status === "CLOSED" ? t("status.closed") : s.status}</span></td>
                  <td className="py-sm pr-md text-right text-ink">{s.expectedCash == null ? "—" : formatINR2(s.expectedCash)}</td>
                  <td className="py-sm pr-md text-right text-ink">{s.closingCounted == null ? "—" : formatINR2(s.closingCounted)}</td>
                  <td className={`py-sm pr-md text-right ${s.variance == null ? "text-subtle" : s.variance === 0 ? "text-success" : "text-warning"}`}>{s.variance == null ? "—" : formatINR2(s.variance)}</td>
                  <td className="py-sm text-right"><button type="button" onClick={() => void view(s.id)} className="inline-flex h-8 items-center rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint">{t("history.viewZReport")}</button></td>
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
  const t = useTranslations("cashier");
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-scrim/50 px-lg" onClick={onClose}>
      <div className="max-h-[85vh] w-[460px] max-w-full overflow-y-auto rounded-lg border border-hairline bg-canvas p-lg" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h2 className="text-title-md text-ink">{t("zReport.title")}</h2>
          <div className="flex items-center gap-sm">
            <button type="button" onClick={() => printZReport(report, t)} className="inline-flex h-9 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint"><Printer size={15} /> {t("actions.print")}</button>
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
function printZReport(r: ShiftReport, t: (key: string) => string) {
  const rows: Array<[string, string]> = [
    [t("zReport.openingFloat"), formatINR2(r.cash.openingFloat)],
    [t("zReport.cashSales"), formatINR2(r.cash.cashSales)],
    [t("zReport.payIns"), formatINR2(r.cash.payIns)],
    [t("zReport.payOuts"), "-" + formatINR2(r.cash.payOuts)],
    [t("zReport.drops"), "-" + formatINR2(r.cash.drops)],
    [t("zReport.refunds"), "-" + formatINR2(r.cash.refunds)],
    [t("zReport.expectedInDrawer"), formatINR2(r.cash.expected)],
    [t("zReport.counted"), r.cash.counted == null ? "—" : formatINR2(r.cash.counted)],
    [t("zReport.variance"), r.cash.variance == null ? "—" : formatINR2(r.cash.variance)],
    [t("zReport.sales"), `${r.sales.count} · ${formatINR2(r.sales.gross)}`],
    [t("zReport.gstCgst"), formatINR2(r.gst.cgst)],
    [t("zReport.gstSgst"), formatINR2(r.gst.sgst)],
    [t("zReport.gstIgst"), formatINR2(r.gst.igst)],
  ];
  const body = rows.map(([k, v]) => `<tr><td>${k}</td><td style="text-align:right">${v}</td></tr>`).join("");
  const html = `<html><head><title>${t("zReport.title")}</title><style>body{font-family:monospace;padding:16px;max-width:320px}h3{text-align:center}table{width:100%;border-collapse:collapse}td{padding:2px 0}</style></head><body><h3>${t("zReport.printHeading")}</h3><table>${body}</table><script>window.onload=function(){window.print()}</script></body></html>`;
  const w = window.open("", "_blank", "width=380,height=600");
  if (w) { w.document.write(html); w.document.close(); }
}

function OpenShiftCard({ busy, onOpen }: { busy: boolean; onOpen: (float: number) => void }) {
  const t = useTranslations("cashier");
  const [float, setFloat] = useState("");
  return (
    <div className="mt-lg max-w-form rounded-lg border border-hairline p-xl">
      <h2 className="flex items-center gap-sm text-title-md text-ink"><LockOpen size={18} /> {t("open.title")}</h2>
      <p className="mt-xs text-body-sm text-muted">{t("open.help")}</p>
      <label className="mt-lg block text-label-md text-muted">{t("open.floatLabel")}</label>
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
        onClick={() => onOpen(parseAmount(float) ?? 0)}
        className="mt-lg inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
      >
        <LockOpen size={16} /> {t("open.submit")}
      </button>
    </div>
  );
}

function ReportPanel({ report }: { report: ShiftReport }) {
  const t = useTranslations("cashier");
  const c = report.cash;
  return (
    <div className="rounded-lg border border-hairline p-lg">
      <h2 className="text-title-md text-ink">{t("report.title")}</h2>
      <p className="mt-xs text-body-sm text-muted">
        {t("report.salesSummary", { count: report.sales.count, gross: formatINR2(report.sales.gross) })}
      </p>

      <Divider className="my-md" />
      <h3 className="text-label-md text-muted">{t("report.cashDrawer")}</h3>
      <div className="mt-sm flex flex-col gap-xs">
        <Row label={t("report.openingFloat")} value={formatINR2(c.openingFloat)} />
        <Row label={t("report.cashSales")} value={formatINR2(c.cashSales)} />
        <Row label={t("report.payIns")} value={formatINR2(c.payIns)} />
        <Row label={t("report.payOuts")} value={`− ${formatINR2(c.payOuts)}`} />
        <Row label={t("report.drops")} value={`− ${formatINR2(c.drops)}`} />
        <Row label={t("report.refunds")} value={`− ${formatINR2(c.refunds)}`} />
        <div className="flex items-center justify-between border-t border-hairline pt-xs">
          <span className="text-title-sm font-bold text-ink">{t("report.expectedInDrawer")}</span>
          <span className="text-title-sm font-bold text-ink">{formatINR2(c.expected)}</span>
        </div>
      </div>

      <Divider className="my-md" />
      <h3 className="text-label-md text-muted">{t("report.tenders")}</h3>
      <div className="mt-sm flex flex-col gap-xs">
        {report.tenders.length === 0 ? (
          <p className="text-body-sm text-subtle">{t("report.noSales")}</p>
        ) : (
          report.tenders.map((tender) => <Row key={tender.mode} label={`${tender.mode} (${tender.count})`} value={formatINR2(tender.amount)} />)
        )}
      </div>

      <Divider className="my-md" />
      <h3 className="text-label-md text-muted">{t("report.gstCollected")}</h3>
      <div className="mt-sm flex flex-col gap-xs">
        <Row label={t("report.taxable")} value={formatINR2(report.gst.taxable)} />
        {report.gst.cgst > 0 ? <Row label="CGST" value={formatINR2(report.gst.cgst)} /> : null}
        {report.gst.sgst > 0 ? <Row label="SGST" value={formatINR2(report.gst.sgst)} /> : null}
        {report.gst.igst > 0 ? <Row label="IGST" value={formatINR2(report.gst.igst)} /> : null}
        {report.gst.cess > 0 ? <Row label={t("report.cess")} value={formatINR2(report.gst.cess)} /> : null}
        {report.gstByRate.map((r) => (
          <Row key={r.rate} label={t("report.rateTaxable", { rate: r.rate })} value={t("report.rateTaxValue", { taxable: formatINR2(r.taxable), tax: formatINR2(r.tax) })} />
        ))}
      </div>

      {report.returns.count > 0 ? (
        <>
          <Divider className="my-md" />
          <Row label={t("report.returns", { count: report.returns.count })} value={`− ${formatINR2(report.returns.amount)}`} />
        </>
      ) : null}
    </div>
  );
}

function CashMovementForm({ busy, onSubmit }: { busy: boolean; onSubmit: (i: { type: "PAY_IN" | "PAY_OUT" | "DROP"; amount: number; reason?: string }) => void }) {
  const t = useTranslations("cashier");
  const [type, setType] = useState<"PAY_IN" | "PAY_OUT" | "DROP">("PAY_IN");
  const [amount, setAmount] = useState("");
  const [reason, setReason] = useState("");
  const icons = { PAY_IN: ArrowDownToLine, PAY_OUT: ArrowUpFromLine, DROP: Banknote } as const;
  const Icon = icons[type];
  return (
    <div className="rounded-lg border border-hairline p-lg">
      <h2 className="text-title-md text-ink">{t("movement.title")}</h2>
      <div className="mt-sm flex flex-wrap gap-sm">
        {(["PAY_IN", "PAY_OUT", "DROP"] as const).map((mt) => (
          <button
            key={mt}
            type="button"
            onClick={() => setType(mt)}
            className={`inline-flex h-9 items-center rounded-button px-md text-label-md ${type === mt ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"}`}
          >
            {mt === "PAY_IN" ? t("movement.payIn") : mt === "PAY_OUT" ? t("movement.payOut") : t("movement.drop")}
          </button>
        ))}
      </div>
      <input value={amount} onChange={(e) => setAmount(e.target.value)} inputMode="decimal" placeholder={t("movement.amountPlaceholder")} className="mt-sm h-10 w-full rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
      <input value={reason} onChange={(e) => setReason(e.target.value)} placeholder={t("movement.reasonPlaceholder")} className="mt-sm h-10 w-full rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
      <button
        type="button"
        disabled={busy || !((parseAmount(amount) ?? 0) > 0)}
        onClick={() => { onSubmit({ type, amount: parseAmount(amount) ?? 0, reason: reason.trim() || undefined }); setAmount(""); setReason(""); }}
        className="mt-sm inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
      >
        <Icon size={16} /> {t("movement.record")}
      </button>
    </div>
  );
}

function CloseShiftForm({ expected, busy, onClose }: { expected: number; busy: boolean; onClose: (counted: number, note?: string) => void }) {
  const t = useTranslations("cashier");
  const [counted, setCounted] = useState("");
  const [note, setNote] = useState("");
  const parsed = parseAmount(counted);
  const variance = parsed === null ? null : parsed - expected;
  return (
    <div className="rounded-lg border border-hairline p-lg">
      <h2 className="flex items-center gap-sm text-title-md text-ink"><Lock size={18} /> {t("close.title")}</h2>
      <p className="mt-xs text-body-sm text-muted">{t("close.expectedInDrawer")} <span className="font-semibold text-ink">{formatINR2(expected)}</span></p>
      <label className="mt-md block text-label-md text-muted">{t("close.countedLabel")}</label>
      <input value={counted} onChange={(e) => setCounted(e.target.value)} inputMode="decimal" placeholder="0.00" className="mt-xs h-10 w-full rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
      {variance !== null ? (
        <p className={`mt-sm text-body-sm ${variance === 0 ? "text-success" : "text-warning"}`}>
          {t("close.variance")} {variance > 0 ? "+" : ""}{formatINR2(variance)} {variance === 0 ? t("close.balanced") : variance > 0 ? t("close.over") : t("close.short")}
        </p>
      ) : null}
      <input value={note} onChange={(e) => setNote(e.target.value)} placeholder={t("close.notePlaceholder")} className="mt-sm h-10 w-full rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
      <button
        type="button"
        disabled={busy || parsed === null}
        onClick={() => onClose(parsed ?? 0, note.trim() || undefined)}
        className="mt-sm inline-flex h-10 items-center gap-sm rounded-button bg-inverse-surface px-lg text-label-md text-on-inverse hover:opacity-90 disabled:bg-disabled"
      >
        <Lock size={16} /> {t("close.submit")}
      </button>
    </div>
  );
}

function ReturnsPanel({ busy, run, onChanged }: { busy: boolean; run: (fn: () => Promise<unknown>) => Promise<void>; onChanged: () => Promise<void> }) {
  const t = useTranslations("cashier");
  const [invoiceId, setInvoiceId] = useState("");
  const [returnable, setReturnable] = useState<Returnable | null>(null);
  const [qty, setQty] = useState<Record<number, string>>({});
  const [refundMode, setRefundMode] = useState<"CASH" | "UPI" | "CARD" | "OTHER">("CASH");
  const [done, setDone] = useState<string | null>(null);

  return (
    <div className="rounded-lg border border-hairline p-lg">
      <h2 className="flex items-center gap-sm text-title-md text-ink"><Undo2 size={18} /> {t("returns.title")}</h2>
      <div className="mt-sm flex gap-sm">
        <input value={invoiceId} onChange={(e) => setInvoiceId(e.target.value)} inputMode="numeric" placeholder={t("returns.invoiceIdPlaceholder")} className="h-10 flex-1 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
        <button
          type="button"
          disabled={busy || !invoiceId}
          onClick={() => run(async () => { setDone(null); setReturnable(await fetchReturnable(Number(invoiceId))); setQty({}); })}
          className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint disabled:text-disabled"
        >
          {t("returns.lookUp")}
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
                  <p className="text-body-sm text-muted">{t("returns.lineDetail", { sold: l.soldQty, returnable: l.returnableQty, price: formatINR2(l.unitPrice) })}</p>
                </div>
                <input
                  value={qty[l.productId] ?? ""}
                  onChange={(e) => setQty((q) => ({ ...q, [l.productId]: e.target.value }))}
                  inputMode="numeric"
                  placeholder="0"
                  disabled={l.returnableQty <= 0}
                  className="h-9 w-16 rounded-input border border-hairline bg-canvas px-sm text-center text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-field-tint"
                />
              </li>
            ))}
          </ul>
          <div className="mt-sm flex flex-wrap items-center gap-sm">
            <span className="text-label-md text-muted">{t("returns.refundVia")}</span>
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
              if (lines.length === 0) throw new Error(t("returns.enterQty"));
              const res = await processReturn({ originalInvoiceId: returnable.invoiceId, refundMode, lines });
              setDone(t("returns.done", { creditNote: res.creditNoteNo, refund: formatINR2(res.refundAmount), drawer: res.cashDrawerAdjusted ? t("returns.drawerAdjusted") : "" }));
              setReturnable(null);
              setQty({});
              await onChanged();
            })}
            className="mt-sm inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
          >
            <Undo2 size={16} /> {t("returns.process")}
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
