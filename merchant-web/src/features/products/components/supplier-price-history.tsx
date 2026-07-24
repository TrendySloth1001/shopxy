"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Building2 } from "@/shared/icons";
import { listStockTransactions } from "@/features/stock/api";
import {
  displaySupplier,
  purchasePolicyLabel,
  type StockTxn,
} from "@/features/stock/schema";
import { money, qty as fmtQty } from "@/features/products/format";
import { unitLabel } from "@/features/products/units";

/**
 * Supplier-wise purchase-price history for a product — the web mirror of the
 * Flutter product-detail "Supplier price history" section. Reads the stock
 * ledger's STOCK_IN rows (`GET /stock?type=STOCK_IN`), groups them by supplier
 * (structured vendor name, else the free-typed supplier), and surfaces, per
 * supplier: the latest and average purchase price, total quantity bought, the
 * last stock-in, the price policy in force, and the most recent buys.
 */
export function SupplierPriceHistory({
  productId,
  unit,
}: {
  productId: string;
  unit?: string | null;
}) {
  const t = useTranslations("products");
  const [txns, setTxns] = useState<StockTxn[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const rows = await listStockTransactions({
          productId,
          type: "STOCK_IN",
          limit: 100,
        });
        if (active) setTxns(rows);
      } catch (e) {
        if (active) {
          setError(e instanceof Error ? e.message : t("supplierHistory.loadError"));
        }
      }
    })();
    return () => {
      active = false;
    };
  }, [productId, t]);

  if (error) {
    return <p className="text-body-sm text-error">{error}</p>;
  }
  if (txns === null) {
    return <p className="text-body-sm text-muted">{t("supplierHistory.loading")}</p>;
  }

  const groups = groupBySupplier(txns);
  if (groups.length === 0) {
    return (
      <p className="text-body-md text-muted">
        {t("supplierHistory.empty")}
      </p>
    );
  }

  return (
    <div className="divide-y divide-hairline">
      {groups.map((g) => (
        <SupplierBlock key={g.supplier} group={g} unit={unit} />
      ))}
    </div>
  );
}

type SupplierGroup = {
  supplier: string;
  txns: StockTxn[]; // newest-first
  isVendor: boolean;
};

function groupBySupplier(source: StockTxn[]): SupplierGroup[] {
  const map = new Map<string, StockTxn[]>();
  for (const t of source) {
    const key = displaySupplier(t)?.trim();
    if (!key) continue;
    const list = map.get(key);
    if (list) list.push(t);
    else map.set(key, [t]);
  }
  const groups: SupplierGroup[] = [...map.entries()].map(([supplier, list]) => {
    const sorted = [...list].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    return { supplier, txns: sorted, isVendor: sorted[0]?.vendorId != null };
  });
  groups.sort((a, b) => b.txns[0].createdAt.localeCompare(a.txns[0].createdAt));
  return groups;
}

const RECENT_BUYS_PREVIEW = 6;

function SupplierBlock({ group, unit }: { group: SupplierGroup; unit?: string | null }) {
  const t = useTranslations("products");
  const { supplier, txns, isVendor } = group;
  const [expanded, setExpanded] = useState(false);
  const priced = txns.filter((t) => t.unitPrice != null).map((t) => t.unitPrice as number);
  const latest = priced.length > 0 ? priced[0] : null;
  const average =
    priced.length > 0 ? priced.reduce((s, p) => s + p, 0) / priced.length : null;
  const totalQty = txns.reduce((s, t) => s + t.quantity, 0);
  const unitText = unit ? ` ${unitLabel(unit)}` : "";

  return (
    <div className="py-lg first:pt-0 last:pb-0">
      <div className="flex items-center justify-between gap-md">
        <h3 className="min-w-0 truncate text-title-sm text-ink">{supplier}</h3>
        {isVendor ? (
          <span className="inline-flex shrink-0 items-center gap-xs rounded-full bg-surface-tint px-sm py-px text-label-md text-muted">
            <Building2 size={13} /> {t("supplierHistory.vendor")}
          </span>
        ) : null}
      </div>

      <dl className="mt-md grid grid-cols-2 gap-x-xl gap-y-md sm:grid-cols-3 lg:grid-cols-5">
        <Metric label={t("supplierHistory.latestPrice")} value={latest == null ? "—" : money(latest)} />
        <Metric label={t("supplierHistory.averagePrice")} value={average == null ? "—" : money(average)} />
        <Metric
          label={t("supplierHistory.totalBought")}
          value={`${fmtQty(totalQty)}${unitText} · ${
            txns.length === 1
              ? t("supplierHistory.buysOne", { count: txns.length })
              : t("supplierHistory.buysOther", { count: txns.length })
          }`}
        />
        <Metric label={t("supplierHistory.lastStockIn")} value={formatDateTime(txns[0].createdAt)} />
        <Metric label={t("supplierHistory.pricePolicy")} value={purchasePolicyLabel(txns[0].purchasePriceMode)} />
      </dl>

      <div className="mt-lg">
        <p className="text-label-md uppercase tracking-wide text-subtle">
          {t("supplierHistory.recentBuys")}{txns.length > 1 ? ` · ${txns.length}` : ""}
        </p>
        <table className="mt-sm w-full max-w-content text-body-sm">
          <thead>
            <tr className="border-b border-hairline text-label-md uppercase tracking-wide text-subtle">
              <th className="py-xs pr-lg text-left font-normal">{t("supplierHistory.colDate")}</th>
              <th className="py-xs pr-lg text-right font-normal">{t("supplierHistory.colQty")}</th>
              <th className="py-xs pr-lg text-right font-normal">{t("supplierHistory.colUnitPrice")}</th>
              <th className="py-xs text-right font-normal">{t("supplierHistory.colAmount")}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-hairline">
            {(expanded ? txns : txns.slice(0, RECENT_BUYS_PREVIEW)).map((t) => (
              <tr key={t.id}>
                <td className="whitespace-nowrap py-sm pr-lg text-muted">
                  {formatDate(t.createdAt)}
                </td>
                <td className="py-sm pr-lg text-right tabular-nums text-muted">
                  {fmtQty(t.quantity)}
                </td>
                <td className="py-sm pr-lg text-right tabular-nums text-ink">
                  {t.unitPrice == null ? "—" : money(t.unitPrice)}
                </td>
                <td className="py-sm text-right tabular-nums font-medium text-ink">
                  {t.unitPrice == null ? "—" : money(t.unitPrice * t.quantity)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {txns.length > RECENT_BUYS_PREVIEW ? (
          <button
            type="button"
            onClick={() => setExpanded((v) => !v)}
            className="mt-sm text-label-md font-semibold text-brand-strong transition-colors hover:text-brand focus-visible:outline-none focus-visible:underline"
          >
            {expanded ? t("supplierHistory.showLess") : t("supplierHistory.showAll", { count: txns.length })}
          </button>
        ) : null}
      </div>
    </div>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-px">
      <dt className="text-label-md text-subtle">{label}</dt>
      <dd className="text-body-md tabular-nums text-ink">{value}</dd>
    </div>
  );
}

const dateFmt = new Intl.DateTimeFormat("en-IN", {
  day: "2-digit",
  month: "short",
  year: "numeric",
});
const dateTimeFmt = new Intl.DateTimeFormat("en-IN", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

function formatDate(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? "—" : dateFmt.format(d);
}
function formatDateTime(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? "—" : dateTimeFmt.format(d);
}
