"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Bell,
  CalendarX2,
  CheckCheck,
  CheckCircle2,
  FileText,
  IndianRupee,
  Mail,
  Package,
  PiggyBank,
  ShieldCheck,
  Undo2,
  XCircle,
  type LucideIcon,
} from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";
import { formatRelativeTime } from "@/shared/datetime";
import { useNotifications } from "@/features/notifications/notifications-context";
import {
  listNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from "@/features/notifications/api";
import { isUnread, type AppNotification } from "@/features/notifications/schema";

const PAGE = 20;

/** Icon puck colour + glyph per notification kind family. */
function accentFor(kind: string): { Icon: LucideIcon; cls: string } {
  if (kind === "INVITE_RECEIVED") return { Icon: Mail, cls: "bg-brand-soft text-brand-strong" };
  if (kind === "INVITE_ACCEPTED") return { Icon: CheckCircle2, cls: "bg-success-soft text-success" };
  if (kind === "INVITE_DECLINED") return { Icon: XCircle, cls: "bg-warning-soft text-warning" };
  if (kind === "INVITE_CANCELLED") return { Icon: CalendarX2, cls: "bg-surface-tint text-muted" };
  if (kind.startsWith("CAUTION_REQUEST")) return { Icon: PiggyBank, cls: "bg-brand-soft text-brand-strong" };
  if (kind.startsWith("ORDER")) return { Icon: Package, cls: "bg-accent-indigo-soft text-accent-indigo" };
  if (kind.startsWith("QUOTATION")) return { Icon: FileText, cls: "bg-accent-indigo-soft text-accent-indigo" };
  if (kind.startsWith("RETURN")) return { Icon: Undo2, cls: "bg-accent-amber-soft text-accent-amber" };
  if (kind.startsWith("PAYMENT") || kind.startsWith("REFUND"))
    return { Icon: IndianRupee, cls: "bg-success-soft text-success" };
  if (kind === "SECURITY") return { Icon: ShieldCheck, cls: "bg-surface-tint text-muted" };
  return { Icon: Bell, cls: "bg-accent-indigo-soft text-accent-indigo" };
}

/** Where tapping a notification should go, or null for informational ones. */
function hrefFor(kind: string): string | null {
  if (kind.startsWith("ORDER")) return "/dashboard/orders";
  if (kind.startsWith("QUOTATION")) return "/dashboard/quotations";
  if (kind.startsWith("RETURN")) return "/dashboard/returns";
  if (kind.startsWith("CAUTION_REQUEST")) return "/dashboard/caution-requests";
  return null;
}

export default function NotificationsPage() {
  const router = useRouter();
  const { setUnread, refresh } = useNotifications();

  const [items, setItems] = useState<AppNotification[]>([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [unread, setLocalUnread] = useState(0);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Body wrapped in an async IIFE so the effect can call load(1) without a
  // synchronous setState in the effect body (react-hooks/set-state-in-effect).
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
      // Optimistic: flip read + drop the count, then sync.
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
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Bell}
        tone="indigo"
        title="Notifications"
        subtitle="Invitations, orders, quotations, returns and account activity."
      >
        <button
          type="button"
          onClick={markAll}
          disabled={unread === 0}
          className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
        >
          <CheckCheck size={16} /> Mark all read
        </button>
      </PageHeader>

      {error ? (
        <p className="mt-lg rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl">
        {loading ? (
          <ListRowsSkeleton rows={6} />
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
      </div>

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
    </div>
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

function Empty() {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <span className="flex size-14 items-center justify-center rounded-full bg-surface-tint text-muted">
        <Bell size={26} />
      </span>
      <p className="text-title-sm text-ink">No notifications yet</p>
      <p className="max-w-content text-body-md text-muted">
        When something happens — an invitation reply, a new order, a quotation update — you’ll see it here.
      </p>
    </div>
  );
}
