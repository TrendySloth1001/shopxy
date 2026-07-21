import Link from "next/link";
import { useTranslations } from "next-intl";
import { Boxes, Receipt, Store } from "@/shared/icons";
import type { DashboardGstMtd, DashboardTill } from "../stats";
import { inr } from "./ui";

/**
 * Compact operations strip: open till (if the viewer has one), GST liability for
 * the month-to-date, and current inventory value. GST is null without
 * reports:view, in which case only the inventory (and till) tiles render.
 */
export function Operations({
  till,
  gstMtd,
  inventoryValue,
}: {
  till: DashboardTill | null;
  gstMtd: DashboardGstMtd | null;
  inventoryValue: number;
}) {
  const t = useTranslations("dashboard");
  return (
    <section aria-labelledby="ops-h">
      <h2 id="ops-h" className="text-label-md uppercase tracking-wide text-muted">
        {t("ops.title")}
      </h2>
      <div className="mt-md grid gap-md sm:grid-cols-2 lg:grid-cols-3">
        {till ? <TillTile till={till} /> : null}
        {gstMtd ? (
          <Tile
            href="/dashboard/reports"
            icon={<Receipt size={16} className="text-accent-indigo" aria-hidden="true" />}
            label={t("ops.gstThisMonth")}
            value={inr.format(gstMtd.netPayable)}
            sub={t("ops.outputTaxCollected", { value: inr.format(gstMtd.outputTax) })}
          />
        ) : null}
        <Tile
          href="/dashboard/stock-adjustments"
          icon={<Boxes size={16} className="text-brand-strong" aria-hidden="true" />}
          label={t("ops.inventoryValue")}
          value={inr.format(inventoryValue)}
          sub={t("ops.costBasis")}
        />
      </div>
    </section>
  );
}

function Tile({
  href,
  icon,
  label,
  value,
  sub,
}: {
  href: string;
  icon: React.ReactNode;
  label: string;
  value: string;
  sub: string;
}) {
  return (
    <Link
      href={href}
      className="group rounded-lg border border-hairline bg-canvas p-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <div className="flex items-center gap-sm">
        {icon}
        <span className="text-label-md text-muted">{label}</span>
      </div>
      <p className="mt-sm text-headline-sm tabular-nums text-ink">{value}</p>
      <p className="mt-xs text-body-sm text-muted">{sub}</p>
    </Link>
  );
}

function TillTile({ till }: { till: DashboardTill }) {
  const t = useTranslations("dashboard");
  const since = new Date(till.openedAt).toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" });
  const topTenders = till.tenders.slice(0, 3).map((tender) => `${tender.mode} ${inr.format(tender.amount)}`).join(" · ");
  return (
    <Link
      href="/dashboard/pos"
      className="group rounded-lg border border-hairline bg-canvas p-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <div className="flex items-center gap-sm">
        <Store size={16} className="text-success" aria-hidden="true" />
        <span className="text-label-md text-muted">{t("ops.openTillSince", { time: since })}</span>
      </div>
      <p className="mt-sm text-headline-sm tabular-nums text-ink">{inr.format(till.expectedCash)}</p>
      <p className="mt-xs truncate text-body-sm text-muted">
        {t("ops.salesCount", { count: till.salesCount })}
        {topTenders ? ` · ${topTenders}` : ""}
      </p>
    </Link>
  );
}
