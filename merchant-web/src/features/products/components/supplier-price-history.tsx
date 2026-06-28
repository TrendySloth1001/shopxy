"use client";

import { useEffect, useState } from "react";
import { Building2 } from "lucide-react";
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
  productId: number;
  unit?: string | null;
}) {
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
          setError(e instanceof Error ? e.message : "Could not load purchase history.");
        }
      }
    })();
    return () => {
      active = false;
    };
  }, [productId]);

  if (error) {
    return <p className="text-body-sm text-error">{error}</p>;
  }
  if (txns === null) {
    return <p className="text-body-sm text-muted">Loading purchase history…</p>;
  }

  const groups = groupBySupplier(txns);
  if (groups.length === 0) {
    return (
      <p className="text-body-md text-muted">
        No supplier purchase history yet. Stock-ins with a supplier will appear here.
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

function SupplierBlock({ group, unit }: { group: SupplierGroup; unit?: string | null }) {
  const { supplier, txns, isVendor } = group;
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
            <Building2 size={13} /> Vendor
          </span>
        ) : null}
      </div>

      <dl className="mt-md grid grid-cols-2 gap-x-xl gap-y-md sm:grid-cols-3 lg:grid-cols-5">
        <Metric label="Latest price" value={latest == null ? "—" : money(latest)} />
        <Metric label="Average price" value={average == null ? "—" : money(average)} />
        <Metric
          label="Total bought"
          value={`${fmtQty(totalQty)}${unitText} · ${txns.length} ${txns.length === 1 ? "buy" : "buys"}`}
        />
        <Metric label="Last stock-in" value={formatDateTime(txns[0].createdAt)} />
        <Metric label="Price policy" value={purchasePolicyLabel(txns[0].purchasePriceMode)} />
      </dl>

      <div className="mt-lg">
        <p className="text-label-md uppercase tracking-wide text-subtle">Recent buys</p>
        <ul className="mt-sm flex flex-col gap-sm">
          {txns.slice(0, 5).map((t) => (
            <li key={t.id} className="flex items-center gap-xl text-body-sm">
              <span className="w-28 shrink-0 whitespace-nowrap text-muted">
                {formatDate(t.createdAt)}
              </span>
              <span className="w-16 shrink-0 whitespace-nowrap tabular-nums text-muted">
                Qty {fmtQty(t.quantity)}
              </span>
              <span className="shrink-0 whitespace-nowrap tabular-nums font-medium text-ink">
                {t.unitPrice == null ? "—" : money(t.unitPrice)}
              </span>
            </li>
          ))}
        </ul>
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
