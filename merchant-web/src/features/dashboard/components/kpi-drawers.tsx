"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { ChevronDown, ChevronRight, ExternalLink, FileText, Search } from "@/shared/icons";
import { SideSheet } from "@/shared/ui/side-sheet";
import { getPnlReport, getSoldProducts, type Range } from "@/features/reports/api";
import type { PnlReport, SoldProduct } from "@/features/reports/schema";
import {
  getPayables,
  getReceivables,
  settled,
  type Breakdown,
  type Counterparty,
} from "../drilldown";
import { inr } from "./ui";

export type KpiDrawerKind = "sales" | "profit" | "receivables" | "payables";

const TITLE_KEY: Record<KpiDrawerKind, string> = {
  sales: "kpi.sales",
  profit: "kpi.netProfit",
  receivables: "kpi.receivables",
  payables: "kpi.payables",
};

/** Router for the four KPI drawers — one slide-over shell, kind-specific body. */
export function KpiDrawer({
  kind,
  range,
  onClose,
}: {
  kind: KpiDrawerKind;
  range: Range;
  onClose: () => void;
}) {
  const t = useTranslations("dashboard");
  return (
    <SideSheet title={t(TITLE_KEY[kind])} onClose={onClose} side="right" width="w-[760px]">
      {kind === "sales" ? <SalesBody range={range} /> : null}
      {kind === "profit" ? <ProfitBody range={range} /> : null}
      {kind === "receivables" ? <ReceivablesBody /> : null}
      {kind === "payables" ? <PayablesBody /> : null}
    </SideSheet>
  );
}

// ── shared status blocks ───────────────────────────────────────────────

function Loading() {
  return (
    <div className="space-y-sm" aria-busy="true">
      {[0, 1, 2, 3, 4].map((i) => (
        <div key={i} className="h-12 animate-pulse rounded-md bg-surface-tint" />
      ))}
    </div>
  );
}

function ErrorBlock({ message, onRetry }: { message: string; onRetry: () => void }) {
  const t = useTranslations("dashboard");
  return (
    <div className="flex flex-col items-start gap-sm rounded-md border border-hairline p-md">
      <p className="text-body-md text-muted">{message}</p>
      <button
        type="button"
        onClick={onRetry}
        className="rounded-button border border-hairline px-md py-xs text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        {t("drawer.retry")}
      </button>
    </div>
  );
}

function Empty({ children }: { children: React.ReactNode }) {
  return <p className="py-lg text-center text-body-md text-muted">{children}</p>;
}

/** "View full …" footer link out to the relevant full-page screen. */
function MoreLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="mt-auto inline-flex items-center gap-xs pt-sm text-label-md text-brand-strong underline-offset-2 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      {children}
      <ExternalLink size={13} aria-hidden="true" />
    </Link>
  );
}

const dateFmt = new Intl.DateTimeFormat("en-IN", {
  day: "numeric",
  month: "short",
  year: "numeric",
});
function fmtDate(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? "—" : dateFmt.format(d);
}

// ── Sales: products sold + a name/SKU filter ───────────────────────────

function SalesBody({ range }: { range: Range }) {
  const t = useTranslations("dashboard");
  const [search, setSearch] = useState("");
  const [debounced, setDebounced] = useState("");
  const [data, setData] = useState<{ rows: SoldProduct[]; total: number; grand: number } | null>(
    null,
  );
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    const t = setTimeout(() => setDebounced(search.trim()), 250);
    return () => clearTimeout(t);
  }, [search]);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      setError(null);
      try {
        const page = await getSoldProducts(range, 1, 50, debounced);
        if (!active) return;
        setData({
          rows: page.data,
          total: page.pagination.total,
          grand: page.totals.totalAmount,
        });
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("drawer.salesLoadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [range, debounced, nonce, t]);

  return (
    <>
      <div className="flex items-center gap-sm rounded-input border border-hairline bg-field px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
        <Search size={16} className="shrink-0 text-subtle" aria-hidden="true" />
        <input
          type="search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder={t("drawer.filterPlaceholder")}
          aria-label={t("drawer.filterAria")}
          className="h-10 w-full bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
        />
      </div>

      {loading ? (
        <Loading />
      ) : error ? (
        <ErrorBlock message={error} onRetry={() => setNonce((n) => n + 1)} />
      ) : !data || data.rows.length === 0 ? (
        <Empty>
          {debounced
            ? t("drawer.noMatch")
            : t("drawer.noSales")}
        </Empty>
      ) : (
        <div className="flex flex-col">
          <div className="flex items-center justify-between border-b border-hairline pb-sm text-label-md uppercase tracking-wide text-muted">
            <span>{t("drawer.productCount", { count: data.total })}</span>
            <span>{t("drawer.revenue", { value: inr.format(data.grand) })}</span>
          </div>
          <ul>
            {data.rows.map((p) => (
              <li
                key={p.productId}
                className="flex items-center justify-between gap-md border-b border-hairline py-sm"
              >
                <div className="min-w-0">
                  <p className="truncate text-body-md text-ink">{p.productName ?? t("drawer.unnamed")}</p>
                  <p className="text-label-md text-muted">
                    {t("drawer.qtySold", { qty: formatQty(p.totalQuantity), unit: p.unit ?? t("drawer.units") })}
                    {p.productSku ? ` · ${p.productSku}` : ""}
                  </p>
                </div>
                <span className="shrink-0 tabular-nums text-body-md text-ink">
                  {inr.format(p.totalAmount)}
                </span>
              </li>
            ))}
          </ul>
          {data.total > data.rows.length ? (
            <p className="pt-sm text-label-md text-muted">
              {t("drawer.showingTop", { count: data.rows.length })}
            </p>
          ) : null}
        </div>
      )}

      <MoreLink href="/dashboard/reports">{t("drawer.viewSalesReport")}</MoreLink>
    </>
  );
}

function formatQty(q: number): string {
  return Number.isInteger(q) ? String(q) : q.toFixed(2).replace(/\.?0+$/, "");
}

// ── Net profit: the calculation, traced ────────────────────────────────

function ProfitBody({ range }: { range: Range }) {
  const t = useTranslations("dashboard");
  const [report, setReport] = useState<PnlReport | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      setError(null);
      try {
        const r = await getPnlReport(range);
        if (active) setReport(r);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("drawer.pnlLoadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [range, nonce, t]);

  if (loading) return <Loading />;
  if (error) return <ErrorBlock message={error} onRetry={() => setNonce((n) => n + 1)} />;
  if (!report) return <Empty>{t("drawer.noData")}</Empty>;

  const r = report;
  const refunds = r.refunds ?? 0;
  const returnedCogs = r.returnedCogs ?? 0;
  const grossSales = r.revenue + refunds;
  const grossCogs = r.cogs + returnedCogs;

  // No sales, costs or write-offs in the window (e.g. the default "Today" before
  // the first sale) — show a clear empty state instead of a wall of ₹0 rows.
  const hasActivity =
    r.revenue !== 0 || r.cogs !== 0 || r.writeoffs !== 0 || refunds !== 0 || returnedCogs !== 0;
  if (!hasActivity) {
    return (
      <>
        <Empty>{t("drawer.noProfitActivity")}</Empty>
        <MoreLink href="/dashboard/reports">{t("drawer.viewPnlReport")}</MoreLink>
      </>
    );
  }

  return (
    <>
      <div>
        <p className="text-label-md uppercase tracking-wide text-muted">{t("kpi.netProfit")}</p>
        <p
          className={`mt-xs text-headline-lg tabular-nums ${r.netProfit >= 0 ? "text-success" : "text-error"}`}
        >
          {inr.format(r.netProfit)}
        </p>
        <p className="mt-xs text-body-md text-muted">
          {t("drawer.grossMargin", { pct: (r.grossMargin * 100).toFixed(1) })}
        </p>
      </div>

      <dl className="mt-sm">
        <StmtRow label={t("pnl.confirmedSales")} basis={t("pnl.confirmedSalesBasis")} value={inr.format(grossSales)} />
        <StmtRow label={t("pnl.salesReturns")} basis={t("pnl.salesReturnsBasis")} value={`− ${inr.format(refunds)}`} />
        <StmtRow label={t("pnl.revenueA")} value={inr.format(r.revenue)} kind="subtotal" />
        <StmtRow label={t("pnl.goodsSold")} basis={t("pnl.goodsSoldBasis")} value={inr.format(grossCogs)} />
        <StmtRow label={t("pnl.returnedRestocked")} basis={t("pnl.returnedRestockedBasis")} value={`− ${inr.format(returnedCogs)}`} />
        <StmtRow label={t("pnl.cogsB")} value={inr.format(r.cogs)} kind="subtotal" />
        <StmtRow label={t("pnl.grossProfit")} value={inr.format(r.grossProfit)} kind="subtotal" />
        <StmtRow label={t("pnl.writeOffs")} basis={t("pnl.writeOffsBasis")} value={`− ${inr.format(r.writeoffs)}`} />
        <StmtRow label={t("pnl.netProfit")} value={inr.format(r.netProfit)} kind="total" />
      </dl>

      <p className="text-label-md text-muted">
        {t("pnl.footnote")}
      </p>

      <MoreLink href="/dashboard/reports">{t("drawer.viewPnlReport")}</MoreLink>
    </>
  );
}

function StmtRow({
  label,
  value,
  basis,
  kind = "line",
}: {
  label: string;
  value: string;
  basis?: string;
  kind?: "line" | "subtotal" | "total";
}) {
  const ruled = kind === "subtotal" || kind === "total";
  const total = kind === "total";
  return (
    <div
      className={`flex items-start justify-between gap-md py-sm ${ruled ? "border-t border-hairline" : ""}`}
    >
      <dt className="min-w-0">
        <span
          className={
            total
              ? "text-title-md text-ink"
              : kind === "subtotal"
                ? "text-body-md font-semibold text-ink"
                : "text-body-md text-muted"
          }
        >
          {label}
        </span>
        {basis ? <p className="text-label-md text-muted">{basis}</p> : null}
      </dt>
      <dd
        className={`shrink-0 tabular-nums ${total ? "text-title-md font-bold text-ink" : kind === "subtotal" ? "text-body-md font-semibold text-ink" : "text-body-md text-ink"}`}
      >
        {value}
      </dd>
    </div>
  );
}

// ── Receivables / Payables: debtors/creditors, each expandable ──────────

function ReceivablesBody() {
  const t = useTranslations("dashboard");
  return (
    <BreakdownBody
      load={getReceivables}
      settledLabel="received"
      emptyText={t("drawer.noReceivables")}
      moreHref="/dashboard/parties"
      moreLabel={t("drawer.viewAllCustomers")}
    />
  );
}

function PayablesBody() {
  const t = useTranslations("dashboard");
  return (
    <BreakdownBody
      load={getPayables}
      settledLabel="paid"
      emptyText={t("drawer.noPayables")}
      moreHref="/dashboard/vendors"
      moreLabel={t("drawer.viewAllVendors")}
    />
  );
}

function BreakdownBody({
  load,
  settledLabel,
  emptyText,
  moreHref,
  moreLabel,
}: {
  load: () => Promise<Breakdown>;
  settledLabel: "received" | "paid";
  emptyText: string;
  moreHref: string;
  moreLabel: string;
}) {
  const t = useTranslations("dashboard");
  const [data, setData] = useState<Breakdown | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      setError(null);
      try {
        const d = await load();
        if (active) setData(d);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("drawer.genericLoadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [load, nonce, t]);

  if (loading) return <Loading />;
  if (error) return <ErrorBlock message={error} onRetry={() => setNonce((n) => n + 1)} />;
  if (!data || data.parties.length === 0) return <Empty>{emptyText}</Empty>;

  return (
    <>
      <div className="flex items-baseline justify-between border-b border-hairline pb-sm">
        <span className="text-label-md uppercase tracking-wide text-muted">
          {t("drawer.accountCount", { count: data.count })}
        </span>
        <span className="tabular-nums text-title-md text-ink">{inr.format(data.outstanding)}</span>
      </div>
      <ul className="flex flex-col">
        {data.parties.map((c) => (
          <CounterpartyRow key={c.id} c={c} settledLabel={settledLabel} />
        ))}
      </ul>
      <MoreLink href={moreHref}>{moreLabel}</MoreLink>
    </>
  );
}

function CounterpartyRow({
  c,
  settledLabel,
}: {
  c: Counterparty;
  settledLabel: "received" | "paid";
}) {
  const t = useTranslations("dashboard");
  const [open, setOpen] = useState(false);
  const paid = useMemo(() => settled(c), [c]);
  return (
    <li className="border-b border-hairline">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="flex w-full items-center gap-sm py-sm text-left transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        {open ? (
          <ChevronDown size={16} className="shrink-0 text-muted" aria-hidden="true" />
        ) : (
          <ChevronRight size={16} className="shrink-0 text-muted" aria-hidden="true" />
        )}
        <span className="min-w-0 flex-1">
          <span className="block truncate text-body-md text-ink">{c.name}</span>
          <span className="block text-label-md text-muted">
            {t("drawer.billedSettled", {
              billed: inr.format(c.billed),
              paid: inr.format(paid),
              settled: settledLabel === "received" ? t("drawer.settledReceived") : t("drawer.settledPaid"),
            })}
          </span>
        </span>
        <span className="shrink-0 tabular-nums text-body-md font-semibold text-ink">
          {inr.format(c.outstanding)}
        </span>
      </button>
      {open ? (
        <div className="pb-sm pl-xl">
          {c.invoices.length === 0 ? (
            <p className="py-xs text-label-md text-muted">{t("drawer.noOpenDocs")}</p>
          ) : (
            <ul className="flex flex-col gap-xxs">
              {c.invoices.map((inv) => {
                const isCredit = inv.documentType === "CREDIT_NOTE";
                return (
                  <li key={inv.id}>
                    <Link
                      href={`/dashboard/invoices/${inv.id}`}
                      className="flex items-center gap-sm rounded-md px-xs py-xs transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
                    >
                      <FileText size={13} className="shrink-0 text-muted" aria-hidden="true" />
                      <span className="min-w-0 flex-1">
                        <span className="flex items-center gap-xs">
                          <span className="truncate text-body-md text-ink">{inv.invoiceNo}</span>
                          {isCredit ? (
                            <span className="shrink-0 rounded-full bg-surface-tint px-sm text-label-md uppercase tracking-wide text-muted">
                              {t("drawer.creditNote")}
                            </span>
                          ) : null}
                        </span>
                        <span className="block text-label-md text-muted">
                          {fmtDate(inv.invoiceDate)}
                        </span>
                      </span>
                      <span className="shrink-0 tabular-nums text-body-md text-ink">
                        {isCredit ? "− " : ""}
                        {inr.format(inv.total)}
                      </span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      ) : null}
    </li>
  );
}
