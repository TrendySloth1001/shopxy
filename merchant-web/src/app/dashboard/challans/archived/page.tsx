"use client";

import { useTranslations } from "next-intl";
import { ArchivedDocumentsPage } from "@/shared/ui/archived-documents-page";
import { listChallans, setChallanArchived } from "@/features/challans/api";
import {
  challanItemCount,
  CHALLAN_STATUS_LABELS,
  type Challan,
} from "@/features/challans/schema";

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
      dateOf={(challan) => challan.createdAt}
      rowOf={(challan) => {
        const count = challanItemCount(challan);
        return {
          href: `/dashboard/challans/${challan.id}`,
          number: challan.challanNo,
          status: CHALLAN_STATUS_LABELS[challan.status] ?? challan.status,
          subtitle: challan.partyName ?? "—",
          trailing: `${count} ${count === 1 ? t("list.item") : t("list.items")}`,
        };
      }}
    />
  );
}
