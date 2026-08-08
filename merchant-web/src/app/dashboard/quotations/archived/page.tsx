"use client";

import { useTranslations } from "next-intl";
import { ArchivedDocumentsPage } from "@/shared/ui/archived-documents-page";
import { formatINR2 } from "@/shared/money";
import { listQuotations, setQuotationArchived } from "@/features/quotations/api";
import {
  quotationPartyName,
  QUOTATION_STATUS_LABELS,
  type Quotation,
} from "@/features/quotations/schema";

/**
 * Quotations the merchant filed out of their working list.
 *
 * Only settled ones get here — the backend refuses to archive a REQUESTED or
 * PENDING quote, because the customer can still act on it and an accept
 * landing against a document the merchant can't see is nobody's job to chase.
 *
 * Archiving is merchant-side only: the customer keeps seeing the quote in
 * their own list. Filing your copy away is not the counterparty forgetting
 * what they were quoted.
 */
export default function ArchivedQuotationsPage() {
  const t = useTranslations("quotations");

  return (
    <ArchivedDocumentsPage<Quotation>
      title={t("archived.title")}
      subtitle={t("archived.subtitle")}
      backHref="/dashboard/quotations"
      backLabel={t("archived.backToList")}
      emptyTitle={t("archived.empty")}
      emptyBody={t("archived.emptyHint")}
      filters={[
        { key: "", label: t("tabs.all") },
        { key: "ACCEPTED", label: t("status.ACCEPTED") },
        { key: "DECLINED", label: t("status.DECLINED") },
        { key: "CANCELLED", label: t("status.CANCELLED") },
      ]}
      load={(filter) =>
        listQuotations({ archived: true, status: filter || undefined })
      }
      restore={(quotation) => setQuotationArchived(quotation.id, false)}
      keyOf={(quotation) => quotation.id}
      // createdAt is what the server sorts quotations by.
      dateOf={(quotation) => quotation.createdAt}
      rowOf={(quotation) => ({
        href: `/dashboard/quotations/${quotation.id}`,
        number: quotation.quotationNo,
        status: QUOTATION_STATUS_LABELS[quotation.status] ?? quotation.status,
        subtitle: quotationPartyName(quotation),
        trailing: formatINR2(quotation.total),
      })}
    />
  );
}
