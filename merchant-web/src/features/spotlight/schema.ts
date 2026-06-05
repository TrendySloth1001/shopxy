import { z } from "zod";

/**
 * Brand-spotlight shapes, mirroring the backend `brand-spotlight` module's
 * `merchantSelect`. A merchant submits a PENDING request; a platform admin
 * approves/rejects. Only APPROVED + in-window rows show on the customer home.
 */

export const SPOTLIGHT_STATUSES = ["PENDING", "APPROVED", "REJECTED"] as const;
export type SpotlightStatus = (typeof SPOTLIGHT_STATUSES)[number];

export const SPOTLIGHT_STATUS_LABELS: Record<SpotlightStatus, string> = {
  PENDING: "Pending review",
  APPROVED: "Approved",
  REJECTED: "Rejected",
};

export const spotlightSchema = z
  .object({
    id: z.number(),
    shopId: z.number(),
    dealLabel: z.string(),
    subtitle: z.string().nullish(),
    heroImageUrl: z.string(),
    bgColor: z.string(),
    accentColor: z.string().nullish(),
    ctaTarget: z.string().nullish(),
    startAt: z.string(),
    endAt: z.string(),
    status: z.enum(SPOTLIGHT_STATUSES),
    rejectionReason: z.string().nullish(),
    reviewedAt: z.string().nullish(),
    createdAt: z.string().optional(),
    updatedAt: z.string().optional(),
  })
  .passthrough();
export type Spotlight = z.infer<typeof spotlightSchema>;

export const spotlightListSchema = z.object({
  data: z.array(spotlightSchema).nullish().transform((v) => v ?? []),
});
