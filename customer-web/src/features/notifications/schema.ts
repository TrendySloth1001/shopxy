import { z } from "zod";

/**
 * Per-user notifications — mirrors the backend `/notifications` module
 * (shared by both apps). `kind` is a free-form string; `readAt` null = unread.
 */
export const notificationSchema = z
  .object({
    id: z.coerce.string(),
    kind: z.string(),
    title: z.string(),
    body: z.string().nullish(),
    data: z.record(z.string(), z.unknown()).nullish(),
    readAt: z.string().nullable().optional(),
    createdAt: z.string(),
  })
  .passthrough();
export type AppNotification = z.infer<typeof notificationSchema>;

export const notificationListSchema = z.object({
  data: z
    .array(notificationSchema)
    .nullish()
    .transform((v) => v ?? []),
  pagination: z
    .object({
      page: z.coerce.number().default(1),
      limit: z.coerce.number().default(20),
      total: z.coerce.number().default(0),
      totalPages: z.coerce.number().default(1),
    })
    .partial()
    .nullish(),
  unread: z.coerce.number().default(0),
});
export type NotificationList = z.infer<typeof notificationListSchema>;

export const unreadCountSchema = z.object({ unread: z.coerce.number().default(0) });

export function isUnread(n: AppNotification): boolean {
  return n.readAt == null;
}
