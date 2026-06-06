import { z } from "zod";

/**
 * Field-level audit log for a party/vendor contact — backend `/:id/changes`
 * (shared shape for both). One row per changed field.
 */
export const contactChangeSchema = z.object({
  id: z.number(),
  field: z.string(),
  oldValue: z.string().nullable(),
  newValue: z.string().nullable(),
  changedAt: z.string(),
  changedBy: z.object({ id: z.number(), name: z.string(), email: z.string() }).nullable(),
});
export type ContactChange = z.infer<typeof contactChangeSchema>;

const listSchema = z.object({
  data: z
    .array(contactChangeSchema)
    .nullish()
    .transform((v) => v ?? []),
});

/** Friendly labels for the tracked contact fields. */
export const CONTACT_FIELD_LABELS: Record<string, string> = {
  name: "Name",
  contactName: "Contact person",
  phone: "Phone",
  email: "Email",
  address: "Address",
  city: "City",
  state: "State",
  stateCode: "State code",
  pinCode: "PIN code",
  panNumber: "PAN",
  gstin: "GSTIN",
  isActive: "Active",
};

export function fieldLabel(field: string): string {
  return CONTACT_FIELD_LABELS[field] ?? field;
}

export function listContactChanges(kind: "parties" | "vendors", id: number): Promise<ContactChange[]> {
  return fetch(`/api/${kind}/${id}/changes?limit=50`, { cache: "no-store" }).then(async (r) => {
    if (!r.ok) throw new Error("Could not load history.");
    return listSchema.parse(await r.json()).data;
  });
}
