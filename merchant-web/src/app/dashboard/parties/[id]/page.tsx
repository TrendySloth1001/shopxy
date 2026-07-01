"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  BadgeCheck,
  BookText,
  CheckCircle2,
  ClipboardList,
  Landmark,
  Mail,
  MapPin,
  Pencil,
  Phone,
  ReceiptText,
  RotateCcw,
  ShoppingBag,
  TrendingDown,
  TrendingUp,
  Wallet,
} from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { Monogram } from "@/shared/ui/monogram";
import { Divider } from "@/shared/ui/divider";
import { LedgerList } from "@/shared/ui/ledger-list";
import { ContactChangesSection } from "@/shared/ui/contact-changes-section";
import { formatDateTime } from "@/shared/datetime";
import { formatINR } from "@/shared/money";
import type { Ledger } from "@/shared/ledger";
import { RecordPaymentModal } from "@/features/payments/record-payment-modal";
import { InviteControl } from "@/features/invitations/invite-control";
import { getPartyLedger, getPartyOverview } from "@/features/parties/api";
import {
  BALANCE_TONE_TEXT,
  netBilled,
  partyBalanceView,
  totalReturns,
  totalSales,
} from "@/features/parties/format";
import type { PartyChallanRef, PartyInvoiceRef, PartyOverview } from "@/features/parties/schema";
import { DetailSkeleton } from "@/shared/ui/skeleton";

const BACK = "/dashboard/parties";

const DOC_STATUS_CLASSES: Record<string, string> = {
  CONFIRMED: "bg-success-soft text-success",
  CANCELLED: "bg-error-soft text-error",
  DRAFT: "bg-accent-amber-soft text-accent-amber",
};

const BALANCE_PUCK: Record<"owe" | "settled" | "advance", string> = {
  owe: "bg-error-soft text-error",
  settled: "bg-surface-tint text-muted",
  advance: "bg-success-soft text-success",
};

export default function PartyDetailPage() {
  const t = useTranslations("parties");
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [overview, setOverview] = useState<PartyOverview | null>(null);
  const [ledger, setLedger] = useState<Ledger | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [payOpen, setPayOpen] = useState(false);
  const reload = () => setNonce((n) => n + 1);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const [o, l] = await Promise.all([
          getPartyOverview(id),
          getPartyLedger(id).catch(() => null),
        ]);
        if (!active) return;
        setOverview(o);
        setLedger(l);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("errors.load"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id, nonce, t]);

  if (loading) {
    return <DetailSkeleton />;
  }
  if (error || !overview) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={BACK} label={t("detail.back")} />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? t("detail.notFound")}
        </p>
      </div>
    );
  }

  const p = overview.party;
  const balanceView = partyBalanceView(overview.balance);

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label={t("detail.back")} />

      {/* Header */}
      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="flex min-w-0 items-start gap-md">
          <Monogram name={p.name} size={52} />
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-sm">
              <h1 className="text-headline-md text-ink">{p.name}</h1>
              {p.linkedUser ? (
                <span className="inline-flex items-center gap-xs rounded-full bg-success-soft px-sm py-px text-body-sm font-semibold text-success">
                  <BadgeCheck size={13} /> {t("badges.linked")}
                </span>
              ) : null}
            </div>
            {p.contactName ? <p className="mt-xs text-body-md text-muted">{p.contactName}</p> : null}
          </div>
        </div>
        {!p.isSystem ? (
          <div className="flex shrink-0 items-center gap-sm">
            <InviteControl
              linkType="PARTY"
              entityId={id}
              name={p.name}
              email={p.email}
              linked={!!p.linkedUser}
            />
            <button
              type="button"
              onClick={() => setPayOpen(true)}
              className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              <Wallet size={16} /> {t("detail.recordPayment")}
            </button>
            <Link
              href={`/dashboard/parties/${id}/edit`}
              className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
            >
              <Pencil size={16} /> {t("actions.edit")}
            </Link>
          </div>
        ) : null}
      </div>

      {/* Contact rows */}
      <div className="mt-lg flex flex-col gap-sm">
        {p.phone ? <ContactRow icon={<Phone size={15} />} text={p.phone} /> : null}
        {p.email ? <ContactRow icon={<Mail size={15} />} text={p.email} /> : null}
        {p.address || p.city || p.state ? (
          <ContactRow
            icon={<MapPin size={15} />}
            text={[p.address, p.city, p.state, p.pinCode].filter(Boolean).join(", ")}
          />
        ) : null}
        {p.gstin ? <ContactRow icon={<Landmark size={15} />} text={`GSTIN ${p.gstin}`} /> : null}
      </div>

      {/* Balance */}
      <div className="mt-xl rounded-lg border border-hairline p-lg">
        <div className="flex items-center gap-md">
          <span className={`flex size-11 shrink-0 items-center justify-center rounded-lg ${BALANCE_PUCK[balanceView.tone]}`}>
            {balanceView.tone === "owe" ? (
              <TrendingUp size={22} />
            ) : balanceView.tone === "advance" ? (
              <TrendingDown size={22} />
            ) : (
              <CheckCircle2 size={22} />
            )}
          </span>
          <div>
            <p className="text-label-md uppercase tracking-wide text-subtle">{t("detail.balance")}</p>
            <p className={`text-headline-md font-bold ${BALANCE_TONE_TEXT[balanceView.tone]}`}>
              {formatINR(Math.abs(overview.balance))}
            </p>
            <p className="text-body-sm text-muted">{t(`detail.balanceTone.${balanceView.tone}`)}</p>
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="mt-lg grid grid-cols-1 gap-lg sm:grid-cols-3">
        <StatBlock
          icon={<ReceiptText size={16} />}
          label={t("stats.netBilled")}
          value={formatINR(netBilled(overview))}
          hint={t("stats.billsCount", { count: overview.counts.invoices })}
        />
        <StatBlock
          icon={<ShoppingBag size={16} />}
          label={t("stats.sales")}
          value={formatINR(totalSales(overview))}
          hint={t("stats.challansCount", { count: overview.counts.challans })}
        />
        <StatBlock
          icon={<RotateCcw size={16} />}
          label={t("stats.returns")}
          value={formatINR(totalReturns(overview))}
          hint={t("stats.salesReturns")}
        />
      </div>

      {/* Ledger */}
      {ledger && ledger.entries.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <SectionHeading icon={<BookText size={18} />} title={t("detail.ledger")} />
          <LedgerList entries={ledger.entries} />
        </>
      ) : null}

      {/* Recent invoices */}
      {overview.recentInvoices.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <SectionHeading icon={<ReceiptText size={18} />} title={t("detail.recentInvoices")} />
          {overview.recentInvoices.map((inv) => (
            <InvoiceRow key={inv.id} invoice={inv} />
          ))}
        </>
      ) : null}

      {/* Recent challans */}
      {overview.recentChallans.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <SectionHeading icon={<ClipboardList size={18} />} title={t("detail.recentChallans")} />
          {overview.recentChallans.map((c) => (
            <ChallanRow key={c.id} challan={c} />
          ))}
        </>
      ) : null}

      {overview.recentInvoices.length === 0 &&
      overview.recentChallans.length === 0 &&
      (!ledger || ledger.entries.length === 0) ? (
        <>
          <Divider className="my-xl" />
          <p className="py-xl text-center text-body-sm text-subtle">{t("detail.noActivity")}</p>
        </>
      ) : null}

      <Divider className="my-xl" />
      <ContactChangesSection kind="parties" id={id} />

      {payOpen ? (
        <RecordPaymentModal
          kind="RECEIPT"
          partyId={id}
          onClose={() => setPayOpen(false)}
          onDone={() => {
            setPayOpen(false);
            reload();
          }}
        />
      ) : null}
    </div>
  );
}

function ContactRow({ icon, text }: { icon: React.ReactNode; text: string }) {
  return (
    <p className="flex items-center gap-sm text-body-md text-muted">
      <span className="text-subtle">{icon}</span>
      {text}
    </p>
  );
}

function SectionHeading({ icon, title }: { icon: React.ReactNode; title: string }) {
  return (
    <h2 className="mb-sm flex items-center gap-sm text-title-md text-ink">
      <span className="text-subtle">{icon}</span>
      {title}
    </h2>
  );
}

function StatBlock({
  icon,
  label,
  value,
  hint,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  hint: string;
}) {
  return (
    <div className="rounded-lg border border-hairline p-lg">
      <p className="flex items-center gap-xs text-label-md text-subtle">
        <span className="text-subtle">{icon}</span>
        {label}
      </p>
      <p className="mt-xs text-title-lg font-bold text-ink">{value}</p>
      <p className="text-body-sm text-subtle">{hint}</p>
    </div>
  );
}

function InvoiceRow({ invoice }: { invoice: PartyInvoiceRef }) {
  const t = useTranslations("parties");
  const items = invoice._count?.items ?? 0;
  return (
    <Link
      href={`/dashboard/invoices/${invoice.id}`}
      className="flex items-center gap-md border-b border-hairline py-md transition-colors hover:bg-surface-tint"
    >
      <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-tint text-muted">
        <ReceiptText size={16} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{invoice.invoiceNo}</p>
        <p className="text-body-sm text-muted">
          {formatDateTime(invoice.invoiceDate)} · {t("row.itemCount", { count: items })}
        </p>
      </div>
      <div className="flex shrink-0 items-center gap-sm">
        <span
          className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
            DOC_STATUS_CLASSES[invoice.status] ?? "bg-surface-tint text-muted"
          }`}
        >
          {t.has(`docStatus.${invoice.status}`) ? t(`docStatus.${invoice.status}`) : invoice.status}
        </span>
        <span className="text-body-md font-semibold text-ink">{formatINR(invoice.total)}</span>
      </div>
    </Link>
  );
}

function ChallanRow({ challan }: { challan: PartyChallanRef }) {
  const t = useTranslations("parties");
  const items = challan._count?.items ?? 0;
  const invoiced = challan.invoiceId != null;
  return (
    <Link
      href={`/dashboard/challans/${challan.id}`}
      className="flex items-center gap-md border-b border-hairline py-md transition-colors hover:bg-surface-tint"
    >
      <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-tint text-muted">
        <ClipboardList size={16} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{challan.challanNo}</p>
        <p className="text-body-sm text-muted">
          {formatDateTime(challan.createdAt)} · {t("row.itemCount", { count: items })}
        </p>
      </div>
      <span
        className={`inline-flex shrink-0 items-center rounded-full px-sm py-px text-body-sm font-semibold ${
          invoiced ? "bg-success-soft text-success" : "bg-surface-tint text-muted"
        }`}
      >
        {invoiced
          ? t("challanStatus.invoiced")
          : t.has(`docStatus.${challan.status}`)
            ? t(`docStatus.${challan.status}`)
            : challan.status}
      </span>
    </Link>
  );
}
