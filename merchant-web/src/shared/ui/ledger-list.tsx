"use client";

import { useTranslations } from "next-intl";
import { Receipt, Wallet } from "@/shared/icons";
import { formatDateTime } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import type { LedgerEntry } from "@/shared/ledger";

/**
 * Renders an interleaved invoice/payment ledger. Invoices add to the balance
 * (debit column, error tone); payments reduce it (credit column, success tone).
 * Each row shows the running balance — shared by vendor + party detail pages.
 */
export function LedgerList({ entries }: { entries: LedgerEntry[] }) {
  const t = useTranslations("common");
  if (entries.length === 0) {
    return (
      <p className="rounded-md bg-surface-tint px-md py-lg text-center text-body-sm text-muted">
        {t("ledger.empty")}
      </p>
    );
  }
  return (
    <div>
      {entries.map((e) => {
        const isInvoice = e.kind === "invoice";
        const amount = isInvoice ? e.debit : e.credit;
        return (
          <div key={`${e.kind}-${e.id}`} className="flex items-start gap-md border-b border-hairline py-md">
            <span
              className={`mt-px flex size-9 shrink-0 items-center justify-center rounded-full ${
                isInvoice ? "bg-error-soft text-error" : "bg-success-soft text-success"
              }`}
            >
              {isInvoice ? <Receipt size={16} /> : <Wallet size={16} />}
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-body-md text-ink">{e.label}</p>
              <p className="text-body-sm text-muted">
                {formatDateTime(e.date)}
                {e.mode ? ` · ${e.mode}` : ""}
                {e.documentType && e.documentType !== "INVOICE" ? ` · ${e.documentType}` : ""}
              </p>
            </div>
            <div className="shrink-0 text-right">
              <p className={`text-body-md font-semibold ${isInvoice ? "text-error" : "text-success"}`}>
                {isInvoice ? "+" : "−"}
                {formatINR2(amount)}
              </p>
              <p className="text-body-sm text-subtle">{t("ledger.balance")} {formatINR2(e.runningBalance)}</p>
            </div>
          </div>
        );
      })}
    </div>
  );
}
