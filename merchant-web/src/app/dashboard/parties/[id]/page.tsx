"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import {
  BadgeCheck,
  ClipboardList,
  Mail,
  MapPin,
  Pencil,
  Phone,
  PiggyBank,
  ReceiptText,
} from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { Monogram } from "@/shared/ui/monogram";
import { Divider } from "@/shared/ui/divider";
import { LedgerList } from "@/shared/ui/ledger-list";
import { formatDateTime } from "@/shared/datetime";
import { formatINR } from "@/shared/money";
import type { Ledger } from "@/shared/ledger";
import { getPartyLedger, getPartyOverview } from "@/features/parties/api";
import {
  BALANCE_TONE_TEXT,
  netBilled,
  partyBalanceView,
  totalReturns,
  totalSales,
} from "@/features/parties/format";
import type { PartyChallanRef, PartyInvoiceRef, PartyOverview } from "@/features/parties/schema";

const BACK = "/dashboard/parties";

const DOC_STATUS_CLASSES: Record<string, string> = {
  CONFIRMED: "bg-success-soft text-success",
  CANCELLED: "bg-error-soft text-error",
  DRAFT: "bg-accent-amber-soft text-accent-amber",
};

export default function PartyDetailPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [overview, setOverview] = useState<PartyOverview | null>(null);
  const [ledger, setLedger] = useState<Ledger | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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
        if (active) setError(e instanceof Error ? e.message : "Could not load the customer.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  if (loading) {
    return <p className="w-full px-lg py-xxl text-body-sm text-subtle md:px-xxl">Loading…</p>;
  }
  if (error || !overview) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={BACK} label="Customers" />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? "Customer not found."}
        </p>
      </div>
    );
  }

  const p = overview.party;
  const balanceView = partyBalanceView(overview.balance);

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Customers" />

      {/* Header */}
      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="flex min-w-0 items-start gap-md">
          <Monogram name={p.name} size={52} />
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-sm">
              <h1 className="text-headline-md text-ink">{p.name}</h1>
              {p.linkedUser ? (
                <span className="inline-flex items-center gap-xs rounded-full bg-success-soft px-sm py-px text-body-sm font-semibold text-success">
                  <BadgeCheck size={13} /> Linked
                </span>
              ) : null}
            </div>
            {p.contactName ? <p className="mt-xs text-body-md text-muted">{p.contactName}</p> : null}
          </div>
        </div>
        {!p.isSystem ? (
          <Link
            href={`/dashboard/parties/${id}/edit`}
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Pencil size={16} /> Edit
          </Link>
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
        {p.gstin ? <ContactRow icon={<BadgeCheck size={15} />} text={`GSTIN ${p.gstin}`} /> : null}
      </div>

      {/* Balance + caution */}
      <div className="mt-xl grid grid-cols-1 gap-lg sm:grid-cols-2">
        <div className="rounded-lg border border-hairline p-lg">
          <p className="text-label-md uppercase tracking-wide text-subtle">Balance</p>
          <p className={`mt-xs text-headline-md font-bold ${BALANCE_TONE_TEXT[balanceView.tone]}`}>
            {formatINR(Math.abs(overview.balance))}
          </p>
          <p className="text-body-sm text-muted">{balanceView.label}</p>
        </div>
        <div className="rounded-lg border border-hairline p-lg">
          <p className="flex items-center gap-xs text-label-md uppercase tracking-wide text-subtle">
            <PiggyBank size={14} /> Caution deposit
          </p>
          <p className="mt-xs text-headline-md font-bold text-info">{formatINR(overview.cautionBalance)}</p>
          <p className="text-body-sm text-muted">
            {overview.cautionBalance > 0 ? "Held against this customer" : "No deposit held"}
          </p>
        </div>
      </div>

      {/* Stats */}
      <div className="mt-lg grid grid-cols-1 gap-lg sm:grid-cols-3">
        <StatBlock label="Net billed" value={formatINR(netBilled(overview))} hint={`${overview.counts.invoices} bills`} />
        <StatBlock label="Sales" value={formatINR(totalSales(overview))} hint={`${overview.counts.challans} challans`} />
        <StatBlock label="Returns" value={formatINR(totalReturns(overview))} hint="sales returns" />
      </div>

      {/* Ledger */}
      {ledger && ledger.entries.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-title-md text-ink">Ledger</h2>
          <LedgerList entries={ledger.entries} />
        </>
      ) : null}

      {/* Recent invoices */}
      {overview.recentInvoices.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-title-md text-ink">Recent invoices</h2>
          {overview.recentInvoices.map((inv) => (
            <InvoiceRow key={inv.id} invoice={inv} />
          ))}
        </>
      ) : null}

      {/* Recent challans */}
      {overview.recentChallans.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-title-md text-ink">Recent challans</h2>
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
          <p className="py-xl text-center text-body-sm text-subtle">No activity yet.</p>
        </>
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

function StatBlock({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div className="rounded-lg border border-hairline p-lg">
      <p className="text-label-md text-subtle">{label}</p>
      <p className="mt-xs text-title-lg font-bold text-ink">{value}</p>
      <p className="text-body-sm text-subtle">{hint}</p>
    </div>
  );
}

function InvoiceRow({ invoice }: { invoice: PartyInvoiceRef }) {
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
          {formatDateTime(invoice.invoiceDate)} · {items} {items === 1 ? "item" : "items"}
        </p>
      </div>
      <div className="flex shrink-0 items-center gap-sm">
        <span
          className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
            DOC_STATUS_CLASSES[invoice.status] ?? "bg-surface-tint text-muted"
          }`}
        >
          {invoice.status}
        </span>
        <span className="text-body-md font-semibold text-ink">{formatINR(invoice.total)}</span>
      </div>
    </Link>
  );
}

function ChallanRow({ challan }: { challan: PartyChallanRef }) {
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
          {formatDateTime(challan.createdAt)} · {items} {items === 1 ? "item" : "items"}
        </p>
      </div>
      <span
        className={`inline-flex shrink-0 items-center rounded-full px-sm py-px text-body-sm font-semibold ${
          invoiced ? "bg-success-soft text-success" : "bg-surface-tint text-muted"
        }`}
      >
        {invoiced ? "Invoiced" : challan.status}
      </span>
    </Link>
  );
}
