"use client";

import { useTranslations } from "next-intl";
import { ArrowUpRight, ArrowDownLeft } from "@/shared/icons";
import { ArchivedDocumentsPage } from "@/shared/ui/archived-documents-page";
import { formatINR2 } from "@/shared/money";
import { listInvoices, setInvoiceArchived } from "@/features/invoices/api";
import {
  counterpartyName,
  isSale,
  type Invoice,
} from "@/features/invoices/schema";

/**
 * Invoices the merchant filed out of the working list.
 *
 * They are not deleted and cannot be: the serial is allocated at create time
 * and Rule 46(b) needs the run consecutive, so every archived row still holds
 * its number. This page is the way back.
 */
export default function ArchivedInvoicesPage() {
  const t = useTranslations("invoices");

  return (
    <ArchivedDocumentsPage<Invoice>
      title={t("archived.title")}
      subtitle={t("archived.subtitle")}
      backHref="/dashboard/invoices"
      backLabel={t("archived.backToList")}
      emptyTitle={t("archived.empty")}
      emptyBody={t("archived.emptyHint")}
      // Same primary axis the invoices list filters on — direction of money.
      filters={[
        { key: "", label: t("list.typeAll") },
        { key: "SALE", label: t("list.typeSales") },
        { key: "PURCHASE", label: t("list.typePurchases") },
      ]}
      load={(filter) =>
        listInvoices({ archived: true, type: filter || undefined })
      }
      restore={(invoice) => setInvoiceArchived(invoice.id, false)}
      keyOf={(invoice) => invoice.id}
      // Grouped by invoiceDate — what the server sorts on.
      dateOf={(invoice) => invoice.invoiceDate}
      rowOf={(invoice) => {
        const sale = isSale(invoice);
        return {
          href: `/dashboard/invoices/${invoice.id}`,
          number: invoice.invoiceNo,
          status: invoice.status,
          subtitle: counterpartyName(invoice),
          trailing: formatINR2(invoice.total),
          leading: (
            <span
              className={`flex size-10 shrink-0 items-center justify-center rounded-full ${
                sale
                  ? "bg-success-soft text-success"
                  : "bg-accent-indigo-soft text-accent-indigo"
              }`}
            >
              {sale ? <ArrowUpRight size={18} /> : <ArrowDownLeft size={18} />}
            </span>
          ),
        };
      }}
    />
  );
}
