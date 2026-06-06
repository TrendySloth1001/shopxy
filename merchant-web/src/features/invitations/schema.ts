import { z } from "zod";

/**
 * Invitation shapes, mirroring the backend `invitations` module
 * (`/invitations`). A merchant invites a party/vendor to link their ShopXY
 * account; the recipient accepts in the customer app, which sets the
 * party/vendor `linkedUserId`.
 */

export const INVITE_STATUS_META: Record<string, { label: string; classes: string }> = {
  PENDING: { label: "Invited", classes: "bg-accent-amber-soft text-accent-amber" },
  ACCEPTED: { label: "Linked", classes: "bg-success-soft text-success" },
  DECLINED: { label: "Declined", classes: "bg-surface-tint text-muted" },
  CANCELLED: { label: "Cancelled", classes: "bg-surface-tint text-muted" },
  EXPIRED: { label: "Expired", classes: "bg-error-soft text-error" },
};

export const invitationSchema = z
  .object({
    id: z.number(),
    toEmail: z.string(),
    linkType: z.string(),
    partyId: z.number().nullish(),
    vendorId: z.number().nullish(),
    status: z.string(),
    displayName: z.string().nullish(),
    message: z.string().nullish(),
    teamRoleName: z.string().nullish(),
    fromShopName: z.string().nullish(),
    fromUser: z
      .object({
        id: z.number(),
        name: z.string(),
        email: z.string(),
        avatarUrl: z.string().nullish(),
      })
      .nullish(),
    expiresAt: z.string().nullish(),
    createdAt: z.string().optional(),
  })
  .passthrough();
export type Invitation = z.infer<typeof invitationSchema>;

export const invitationListSchema = z.object({
  data: z
    .array(invitationSchema)
    .nullish()
    .transform((v) => v ?? []),
});
