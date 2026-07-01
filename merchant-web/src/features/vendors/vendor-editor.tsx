"use client";

import { useTranslations } from "next-intl";
import { ContactEditor, type ContactWrite } from "@/shared/ui/contact-editor";
import { createVendor, updateVendor } from "./api";
import type { Vendor } from "./schema";

export function VendorEditor({ existing }: { existing: Vendor | null }) {
  const t = useTranslations("vendors");
  const isEdit = existing != null;
  return (
    <ContactEditor
      title={isEdit ? t("editor.editTitle") : t("editor.addTitle")}
      subtitle={t("editor.subtitle")}
      nameLabel={t("editor.nameLabel")}
      backHref="/dashboard/vendors"
      backLabel={t("list.title")}
      isEdit={isEdit}
      initial={existing ?? {}}
      onSubmit={async (values: ContactWrite) => {
        if (isEdit) await updateVendor(existing.id, values);
        else await createVendor(values);
      }}
    />
  );
}
