"use client";

import { useTranslations } from "next-intl";
import { ArchivedDocumentsPage } from "@/shared/ui/archived-documents-page";
import { listChallans, setChallanArchived } from "@/features/challans/api";
import {
  challanItemCount,
  CHALLAN_STATUS_LABELS,
  type Challan,
} from "@/features/challans/schema";

/**
 * Delivery challans the merchant filed out of the working list.
 *
 * Only settled ones get here — the backend refuses to archive a PENDING
 * challan, because goods are physically out against it and it has been
 * neither invoiced nor cancelled. So the tabs are the settled states, not
 * the full status set.
 */
export default function ArchivedChallansPage() {
  const t = useTranslations("challans");

  return (
    <ArchivedDocumentsPage<Challan>
      title={t("archived.title")}
      subtitle={t("archived.subtitle")}
      backHref="/dashboard/challans"
      backLabel={t("archived.backToList")}
      emptyTitle={t("archived.empty")}
      emptyBody={t("archived.emptyHint")}
      filters={[
        { key: "", label: t("tabs.all") },
        { key: "CONVERTED", label: t("status.converted") },
        { key: "CANCELLED", label: t("status.cancelled") },
      ]}
      load={(filter) =>
        listChallans({ archived: true, status: filter || undefined })
      }
      restore={(challan) => setChallanArchived(challan.id, false)}
      keyOf={(challan) => challan.id}
      // createdAt is what the server sorts challans by.
      dateOf={(challan) => challan.createdAt}
      rowOf={(challan) => {
        const count = challanItemCount(challan);
        return {
          href: `/dashboard/challans/${challan.id}`,
          number: challan.challanNo,
          status: CHALLAN_STATUS_LABELS[challan.status] ?? challan.status,
          subtitle: challan.partyName ?? "—",
          // A challan carries no money — the line count is the useful figure.
          trailing: `${count} ${count === 1 ? t("list.item") : t("list.items")}`,
        };
      }}
    />
  );
}
