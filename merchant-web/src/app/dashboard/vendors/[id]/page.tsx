"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import {
  BadgeCheck,
  BookText,
  CheckCircle2,
  Landmark,
  Mail,
  MapPin,
  PackagePlus,
  Pencil,
  Phone,
  ReceiptText,
  RotateCcw,
  ScrollText,
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
import { RecordPaymentModal } from "@/features/payments/record-payment-modal";
import { formatDateTime } from "@/shared/datetime";
import { formatINR } from "@/shared/money";
import type { Ledger } from "@/shared/ledger";
import { InviteControl } from "@/features/invitations/invite-control";
import { getVendorLedger, getVendorOverview } from "@/features/vendors/api";
import { BALANCE_TONE_TEXT, netPurchased, totalReturns, vendorBalanceView } from "@/features/vendors/format";
import type { VendorInvoiceRef, VendorOverview, VendorStockInRef } from "@/features/vendors/schema";
import { DetailSkeleton } from "@/shared/ui/skeleton";

const BACK = "/dashboard/vendors";

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

export default function VendorDetailPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [overview, setOverview] = useState<VendorOverview | null>(null);
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
          getVendorOverview(id),
          getVendorLedger(id).catch(() => null),
        ]);
        if (!active) return;
        setOverview(o);
        setLedger(l);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the vendor.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id, nonce]);

  if (loading) {
    return <DetailSkeleton />;
  }
  if (error || !overview) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={BACK} label="Vendors" />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? "Vendor not found."}
        </p>
      </div>
    );
  }

  const v = overview.vendor;
  const balanceView = vendorBalanceView(overview.balance);

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Vendors" />

      {/* Header */}
      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="flex min-w-0 items-start gap-md">
          <Monogram name={v.name} size={52} />
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-sm">
              <h1 className="text-headline-md text-ink">{v.name}</h1>
              {v.linkedUser ? (
                <span className="inline-flex items-center gap-xs rounded-full bg-success-soft px-sm py-px text-body-sm font-semibold text-success">
                  <BadgeCheck size={13} /> Linked
                </span>
              ) : null}
            </div>
            {v.contactName ? <p className="mt-xs text-body-md text-muted">{v.contactName}</p> : null}
          </div>
        </div>
        <div className="flex shrink-0 items-center gap-sm">
          <InviteControl
            linkType="VENDOR"
            entityId={id}
            name={v.name}
            email={v.email}
            linked={!!v.linkedUser}
          />
          <button
            type="button"
            onClick={() => setPayOpen(true)}
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Wallet size={16} /> Record payment
          </button>
          <Link
            href={`/dashboard/vendors/${id}/edit`}
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Pencil size={16} /> Edit
          </Link>
        </div>
      </div>

      {/* Contact rows */}
      <div className="mt-lg flex flex-col gap-sm">
        {v.phone ? <ContactRow icon={<Phone size={15} />} text={v.phone} /> : null}
        {v.email ? <ContactRow icon={<Mail size={15} />} text={v.email} /> : null}
        {v.address || v.city || v.state ? (
          <ContactRow
            icon={<MapPin size={15} />}
            text={[v.address, v.city, v.state, v.pinCode].filter(Boolean).join(", ")}
          />
        ) : null}
        {v.gstin ? <ContactRow icon={<Landmark size={15} />} text={`GSTIN ${v.gstin}`} /> : null}
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
            <p className="text-label-md uppercase tracking-wide text-subtle">Balance</p>
            <p className={`text-headline-md font-bold ${BALANCE_TONE_TEXT[balanceView.tone]}`}>
              {formatINR(Math.abs(overview.balance))}
            </p>
            <p className="text-body-sm text-muted">{balanceView.label}</p>
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="mt-lg grid grid-cols-1 gap-lg sm:grid-cols-3">
        <StatBlock
          icon={<ShoppingBag size={16} />}
          label="Net purchased"
          value={formatINR(netPurchased(overview))}
          hint={`${overview.counts.invoices} bills`}
        />
        <StatBlock
          icon={<PackagePlus size={16} />}
          label="Stock-ins"
          value={String(overview.counts.stockIns)}
          hint="ledger rows"
        />
        <StatBlock
          icon={<RotateCcw size={16} />}
          label="Returns"
          value={formatINR(totalReturns(overview))}
          hint="purchase returns"
        />
      </div>

      {/* Ledger */}
      {ledger && ledger.entries.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <SectionHeading icon={<BookText size={18} />} title="Ledger" />
          <LedgerList entries={ledger.entries} />
        </>
      ) : null}

      {/* Recent bills */}
      {overview.recentInvoices.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <SectionHeading icon={<ReceiptText size={18} />} title="Recent bills" />
          {overview.recentInvoices.map((inv) => (
            <InvoiceRow key={inv.id} invoice={inv} />
          ))}
        </>
      ) : null}

      {/* Recent stock-ins */}
      {overview.recentStockIns.length > 0 ? (
        <>
          <Divider className="my-xl" />
          <SectionHeading icon={<ScrollText size={18} />} title="Recent stock-in" />
          {overview.recentStockIns.map((s) => (
            <StockInRow key={s.id} stockIn={s} />
          ))}
        </>
      ) : null}

      {overview.recentInvoices.length === 0 &&
      overview.recentStockIns.length === 0 &&
      (!ledger || ledger.entries.length === 0) ? (
        <>
          <Divider className="my-xl" />
          <p className="py-xl text-center text-body-sm text-subtle">No activity yet.</p>
        </>
      ) : null}

      <Divider className="my-xl" />
      <ContactChangesSection kind="vendors" id={id} />

      {payOpen ? (
        <RecordPaymentModal
          kind="PAYMENT"
          vendorId={id}
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

function InvoiceRow({ invoice }: { invoice: VendorInvoiceRef }) {
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

function StockInRow({ stockIn }: { stockIn: VendorStockInRef }) {
  return (
    <div className="flex items-center gap-md border-b border-hairline py-md">
      <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-tint text-muted">
        <ScrollText size={16} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{stockIn.product?.name ?? "Product"}</p>
        <p className="text-body-sm text-muted">
          {stockIn.product?.sku ? `SKU ${stockIn.product.sku} · ` : ""}
          {formatDateTime(stockIn.createdAt)}
        </p>
      </div>
      <div className="shrink-0 text-right">
        <p className="text-body-md font-semibold text-ink">
          +{stockIn.quantity}
          {stockIn.product?.unit ? ` ${stockIn.product.unit}` : ""}
        </p>
        {stockIn.totalValue != null ? (
          <p className="text-body-sm text-subtle">{formatINR(stockIn.totalValue)}</p>
        ) : null}
      </div>
    </div>
  );
}
