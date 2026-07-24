import {
  notificationListSchema,
  unreadCountSchema,
  type NotificationList,
} from "./schema";

async function jsonOrThrow<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export function listNotifications(opts?: {
  page?: number;
  limit?: number;
  unreadOnly?: boolean;
}): Promise<NotificationList> {
  const qs = new URLSearchParams({
    page: String(opts?.page ?? 1),
    limit: String(opts?.limit ?? 20),
  });
  if (opts?.unreadOnly) qs.set("unreadOnly", "true");
  return fetch(`/api/notifications?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => notificationListSchema.parse(raw), "Could not load notifications."),
  );
}

/** Cheap unread count for the bell badge. Soft-fails to 0 on the BFF side. */
export function getUnreadCount(): Promise<number> {
  return fetch("/api/notifications/unread-count", { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => unreadCountSchema.parse(raw).unread, "Could not load the unread count."),
  );
}

export async function markNotificationRead(id: string): Promise<void> {
  const res = await fetch(`/api/notifications/${id}/read`, { method: "POST" });
  if (!res.ok && res.status !== 204) throw new Error("Could not mark it read.");
}

export async function markAllNotificationsRead(): Promise<void> {
  const res = await fetch("/api/notifications/read-all", { method: "POST" });
  if (!res.ok && res.status !== 204) throw new Error("Could not mark all read.");
}
