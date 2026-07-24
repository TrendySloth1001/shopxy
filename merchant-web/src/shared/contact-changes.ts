import { z } from "zod";

/**
 * Field-level audit log for a party/vendor contact — backend `/:id/changes`
 * (shared shape for both). One row per changed field.
 */
export const contactChangeSchema = z.object({
  id: z.coerce.string(),
  field: z.string(),
  oldValue: z.string().nullable(),
  newValue: z.string().nullable(),
  changedAt: z.string(),
  changedBy: z.object({ id: z.coerce.string(), name: z.string(), email: z.string() }).nullable(),
});
export type ContactChange = z.infer<typeof contactChangeSchema>;

const listSchema = z.object({
  data: z
    .array(contactChangeSchema)
    .nullish()
    .transform((v) => v ?? []),
});

/** Message-catalog keys (under "common") for the tracked contact fields. */
export const CONTACT_FIELD_KEYS: Record<string, string> = {
  name: "contactField.name",
  contactName: "contactField.contactName",
  phone: "contactField.phone",
  email: "contactField.email",
  address: "contactField.address",
  city: "contactField.city",
  state: "contactField.state",
  stateCode: "contactField.stateCode",
  pinCode: "contactField.pinCode",
  panNumber: "contactField.panNumber",
  gstin: "contactField.gstin",
  isActive: "contactField.isActive",
};

/** Message-catalog key for a tracked field, or null for an unknown field
 *  (the caller then falls back to the raw field name). */
export function contactFieldKey(field: string): string | null {
  return CONTACT_FIELD_KEYS[field] ?? null;
}

export function listContactChanges(kind: "parties" | "vendors", id: string): Promise<ContactChange[]> {
  return fetch(`/api/${kind}/${id}/changes?limit=50`, { cache: "no-store" }).then(async (r) => {
    if (!r.ok) throw new Error("Could not load history.");
    return listSchema.parse(await r.json()).data;
  });
}
