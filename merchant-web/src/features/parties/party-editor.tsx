"use client";

import { ContactEditor, type ContactWrite } from "@/shared/ui/contact-editor";
import { createParty, updateParty } from "./api";
import type { Party } from "./schema";

export function PartyEditor({ existing }: { existing: Party | null }) {
  const isEdit = existing != null;
  return (
    <ContactEditor
      title={isEdit ? "Edit customer" : "Add customer"}
      subtitle="Customers you sell to — used on sale invoices, challans and the receivable ledger."
      nameLabel="Customer name"
      backHref="/dashboard/parties"
      backLabel="Customers"
      isEdit={isEdit}
      initial={existing ?? {}}
      onSubmit={async (values: ContactWrite) => {
        if (isEdit) await updateParty(existing.id, values);
        else await createParty(values);
      }}
    />
  );
}
