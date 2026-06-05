"use client";

import { ContactEditor, type ContactWrite } from "@/shared/ui/contact-editor";
import { createVendor, updateVendor } from "./api";
import type { Vendor } from "./schema";

export function VendorEditor({ existing }: { existing: Vendor | null }) {
  const isEdit = existing != null;
  return (
    <ContactEditor
      title={isEdit ? "Edit vendor" : "Add vendor"}
      subtitle="Suppliers you buy stock from — used on purchase bills and stock-in entries."
      nameLabel="Vendor name"
      backHref="/dashboard/vendors"
      backLabel="Vendors"
      isEdit={isEdit}
      initial={existing ?? {}}
      onSubmit={async (values: ContactWrite) => {
        if (isEdit) await updateVendor(existing.id, values);
        else await createVendor(values);
      }}
    />
  );
}
