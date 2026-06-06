"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Bell,
  CheckCheck,
  IndianRupee,
  Mail,
  Package,
  PackageCheck,
  ShieldCheck,
  TrendingDown,
  Undo2,
  Zap,
  type LucideIcon,
} from "lucide-react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { Divider } from "@/shared/ui/divider";
import { formatRelativeTime } from "@/shared/datetime";
import { useNotifications } from "@/features/notifications/notifications-context";
import {
  listNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from "@/features/notifications/api";
import { isUnread, type AppNotification } from "@/features/notifications/schema";

const PAGE = 20;

/** Icon puck colour + glyph per customer notification kind family. */
function accentFor(kind: string): { Icon: LucideIcon; cls: string } {
  if (kind.startsWith("ORDER") || kind.startsWith("PURCHASE_REQUEST"))
    return { Icon: Package, cls: "bg-accent-indigo-soft text-accent-indigo" };
  if (kind.startsWith("PRICE_DROP") || kind.startsWith("WISHLIST"))
    return { Icon: TrendingDown, cls: "bg-success-soft text-success" };
  if (kind.startsWith("FLASH_DEAL") || kind.startsWith("DEAL"))
    return { Icon: Zap, cls: "bg-accent-amber-soft text-accent-amber" };
  if (kind.startsWith("BACK_IN_STOCK"))
    return { Icon: PackageCheck, cls: "bg-accent-rose-soft text-accent-rose" };
  if (kind.startsWith("INVITE")) return { Icon: Mail, cls: "bg-brand-soft text-brand-strong" };
  if (kind.startsWith("PAYMENT") || kind.startsWith("REFUND"))
    return { Icon: IndianRupee, cls: "bg-success-soft text-success" };
  if (kind.startsWith("RETURN")) return { Icon: Undo2, cls: "bg-accent-amber-soft text-accent-amber" };
  if (kind === "SECURITY") return { Icon: ShieldCheck, cls: "bg-surface-tint text-muted" };
  return { Icon: Bell, cls: "bg-accent-indigo-soft text-accent-indigo" };
}

/** Where tapping a notification should go, or null for informational ones. */
function hrefFor(kind: string): string | null {
  if (kind === "SECURITY") return "/account";
  if (
    kind.startsWith("ORDER") ||
    kind.startsWith("PURCHASE_REQUEST") ||
    kind.startsWith("PAYMENT") ||
    kind.startsWith("REFUND") ||
    kind.startsWith("RETURN") ||
    kind.startsWith("INVITE")
  )
    return "/dashboard";
  return null;
}

export default function NotificationsPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <NotificationsBody />
    </RequireAuth>
  );
}

function NotificationsBody() {
  const router = useRouter();
  const { setUnread, refresh } = useNotifications();

  const [items, setItems] = useState<AppNotification[]>([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [unread, setLocalUnread] = useState(0);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback((p: number) => {
    void (async () => {
      if (p === 1) setLoading(true);
      else setLoadingMore(true);
      try {
        const res = await listNotifications({ page: p, limit: PAGE });
        setItems((prev) => (p === 1 ? res.data : [...prev, ...res.data]));
        setTotalPages(res.pagination?.totalPages ?? 1);
        setLocalUnread(res.unread);
        setPage(p);
        setError(null);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Could not load notifications.");
      } finally {
        setLoading(false);
        setLoadingMore(false);
      }
    })();
  }, []);

  useEffect(() => {
    load(1);
  }, [load]);

  async function openOne(n: AppNotification) {
    if (isUnread(n)) {
      setItems((prev) => prev.map((x) => (x.id === n.id ? { ...x, readAt: new Date().toISOString() } : x)));
      setLocalUnread((u) => Math.max(0, u - 1));
      setUnread(Math.max(0, unread - 1));
      try {
        await markNotificationRead(n.id);
      } catch {
        /* best-effort */
      } finally {
        refresh();
      }
    }
    const href = hrefFor(n.kind);
    if (href) router.push(href);
  }

  async function markAll() {
    setItems((prev) => prev.map((x) => (x.readAt ? x : { ...x, readAt: new Date().toISOString() })));
    setLocalUnread(0);
    setUnread(0);
    try {
      await markAllNotificationsRead();
    } catch {
      /* best-effort */
    } finally {
      refresh();
    }
  }

  return (
    <main className="mx-auto max-w-content px-lg py-xxxl">
      <div className="flex flex-wrap items-center justify-between gap-md">
        <div>
          <p className="text-label-md uppercase tracking-wide text-brand">Inbox</p>
          <h1 className="mt-xs text-headline-md text-ink">Notifications</h1>
        </div>
        <button
          type="button"
          onClick={markAll}
          disabled={unread === 0}
          className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
        >
          <CheckCheck size={16} /> Mark all read
        </button>
      </div>

      {error ? (
        <p className="mt-lg rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <Divider className="my-xl" />

      {loading ? (
        <Skeleton />
      ) : items.length === 0 ? (
        <Empty />
      ) : (
        <ul className="border-t border-hairline">
          {items.map((n) => (
            <li key={n.id}>
              <Row n={n} onOpen={() => openOne(n)} />
            </li>
          ))}
        </ul>
      )}

      {!loading && page < totalPages ? (
        <div className="mt-lg flex justify-center">
          <button
            type="button"
            onClick={() => load(page + 1)}
            disabled={loadingMore}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            {loadingMore ? "Loading…" : "Load more"}
          </button>
        </div>
      ) : null}
    </main>
  );
}

function Row({ n, onOpen }: { n: AppNotification; onOpen: () => void }) {
  const { Icon, cls } = accentFor(n.kind);
  const unread = isUnread(n);
  return (
    <button
      type="button"
      onClick={onOpen}
      className={`flex w-full items-start gap-md border-b border-hairline px-md py-md text-left transition-colors hover:bg-surface-tint ${
        unread ? "bg-brand-soft/40" : ""
      }`}
    >
      <span className={`mt-px flex size-9 shrink-0 items-center justify-center rounded-lg ${cls}`}>
        <Icon size={18} />
      </span>
      <span className="min-w-0 flex-1">
        <span className={`block truncate text-body-md ${unread ? "font-semibold text-ink" : "text-ink"}`}>
          {n.title}
        </span>
        {n.body ? <span className="mt-px block text-body-sm text-muted">{n.body}</span> : null}
        <span className="mt-xs block text-label-md text-subtle">{formatRelativeTime(n.createdAt)}</span>
      </span>
      {unread ? <span className="mt-sm size-2 shrink-0 rounded-full bg-brand" aria-label="Unread" /> : null}
    </button>
  );
}

function Skeleton() {
  return (
    <ul className="border-t border-hairline">
      {Array.from({ length: 6 }).map((_, i) => (
        <li key={i} className="flex items-start gap-md border-b border-hairline px-md py-md">
          <span className="size-9 shrink-0 animate-pulse rounded-lg bg-hairline" />
          <span className="flex-1 space-y-sm py-xs">
            <span className="block h-3 w-1/2 animate-pulse rounded bg-hairline" />
            <span className="block h-3 w-3/4 animate-pulse rounded bg-hairline" />
          </span>
        </li>
      ))}
    </ul>
  );
}

function Empty() {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <span className="flex size-14 items-center justify-center rounded-full bg-surface-tint text-muted">
        <Bell size={26} />
      </span>
      <p className="text-title-sm text-ink">No notifications yet</p>
      <p className="max-w-content text-body-md text-muted">
        Order updates, price drops, deals and account activity will show up here.
      </p>
    </div>
  );
}
