"use client";

import { useTranslations } from "next-intl";
import { ContactEditor, type ContactWrite } from "@/shared/ui/contact-editor";
import { createParty, updateParty } from "./api";
import type { Party } from "./schema";

export function PartyEditor({ existing }: { existing: Party | null }) {
  const t = useTranslations("parties");
  const isEdit = existing != null;
  return (
    <ContactEditor
      title={isEdit ? t("editor.editTitle") : t("editor.addTitle")}
      subtitle={t("editor.subtitle")}
      nameLabel={t("editor.nameLabel")}
      backHref="/dashboard/parties"
      backLabel={t("detail.back")}
      isEdit={isEdit}
      initial={existing ?? {}}
      onSubmit={async (values: ContactWrite) => {
        if (isEdit) await updateParty(existing.id, values);
        else await createParty(values);
      }}
    />
  );
}
