import Link from "next/link";
import { ArrowDownLeft, ArrowLeftRight, ArrowUpRight, Timer } from "lucide-react";
import type { DashboardTransaction } from "../stats";
import { Section } from "./ui";

/** Recent stock movements feed, each row linking to its source document. */
export function RecentActivity({ transactions }: { transactions: DashboardTransaction[] }) {
  return (
    <Section id="recent" title="Recent activity">
      {transactions.length === 0 ? (
        <div className="flex items-center gap-md py-lg text-muted">
          <Timer size={20} className="text-subtle" aria-hidden="true" />
          <span className="text-body-md">No recent stock movements.</span>
        </div>
      ) : (
        <ul>
          {transactions.map((t) => (
            <ActivityRow key={t.id} tx={t} />
          ))}
        </ul>
      )}
    </Section>
  );
}

function ActivityRow({ tx }: { tx: DashboardTransaction }) {
  const isIn = tx.direction === "IN" || tx.type === "STOCK_IN";
  const isOut = tx.direction === "OUT" || tx.type === "STOCK_OUT";
  const accent = isIn ? "text-success" : isOut ? "text-error" : "text-accent-indigo";
  const accentSoft = isIn ? "bg-success-soft" : isOut ? "bg-error-soft" : "bg-accent-indigo-soft";
  const Icon = isIn ? ArrowDownLeft : isOut ? ArrowUpRight : ArrowLeftRight;
  const sign = isIn ? "+" : isOut ? "−" : "";
  const qty = Number.isInteger(tx.quantity) ? tx.quantity.toString() : tx.quantity.toFixed(2);
  const time = new Date(tx.createdAt).toLocaleString("en-IN", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });

  const sourceHref =
    tx.sourceId != null && tx.sourceType === "INVOICE"
      ? `/dashboard/invoices/${tx.sourceId}`
      : tx.sourceId != null && tx.sourceType === "CHALLAN"
        ? `/dashboard/challans/${tx.sourceId}`
        : null;

  const inner = (
    <>
      <span className={`flex size-9 shrink-0 items-center justify-center rounded-md ${accentSoft}`}>
        <Icon size={18} className={accent} aria-hidden="true" />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{tx.product?.name ?? `Product #${tx.productId}`}</p>
        <p className="text-body-sm text-muted">{time}</p>
      </div>
      <span className={`shrink-0 text-title-md tabular-nums ${accent}`}>
        {sign}
        {qty}
      </span>
    </>
  );

  return (
    <li>
      {sourceHref ? (
        <Link
          href={sourceHref}
          className="flex items-center gap-md border-t border-hairline py-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          {inner}
        </Link>
      ) : (
        <div className="flex items-center gap-md border-t border-hairline py-md">{inner}</div>
      )}
    </li>
  );
}
