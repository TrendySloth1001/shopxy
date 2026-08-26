"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  Bell,
  CalendarX2,
  Check,
  CheckCheck,
  CheckCircle2,
  FileText,
  IndianRupee,
  Mail,
  Package,
  ShieldCheck,
  Store,
  Undo2,
  UserCog,
  Users,
  X,
  XCircle,
  type LucideIcon,
} from "@/shared/icons";
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
import {
  acceptInvitation,
  cancelInvitation,
  declineInvitation,
  listIncomingInvitations,
  listOutgoingInvitations,
} from "@/features/invitations/api";
import { INVITE_STATUS_META, type Invitation } from "@/features/invitations/schema";

const PAGE = 20;
type TabKey = "inbox" | "invites" | "sent";

export default function NotificationsPage() {
  const { unread } = useNotifications();
  const t = useTranslations("notifications");
  const [tab, setTab] = useState<TabKey>("inbox");

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Bell}
        tone="indigo"
        title={t("title")}
        subtitle={t("subtitle")}
      />

      <div className="mt-lg flex flex-wrap items-center gap-sm">
        <Tab label={t("tabs.inbox")} badge={unread} active={tab === "inbox"} onClick={() => setTab("inbox")} />
        <Tab label={t("tabs.invites")} active={tab === "invites"} onClick={() => setTab("invites")} />
        <Tab label={t("tabs.sent")} active={tab === "sent"} onClick={() => setTab("sent")} />
      </div>

      <div className="mt-xl">
        {tab === "inbox" ? <InboxTab /> : tab === "invites" ? <InvitesTab /> : <SentTab />}
      </div>
    </div>
  );
}

function Tab({
  label,
  badge = 0,
  active,
  onClick,
}: {
  label: string;
  badge?: number;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-current={active ? "page" : undefined}
      className={`inline-flex h-9 items-center gap-sm rounded-button px-md text-label-md transition-colors ${
        active ? "bg-inverse-surface text-on-inverse" : "border border-hairline text-ink hover:bg-surface-tint"
      }`}
    >
      {label}
      {badge > 0 ? (
        <span
          className={`inline-flex h-4 min-w-4 items-center justify-center rounded-full px-xs text-label-md ${
            active ? "bg-on-inverse/20 text-on-inverse" : "bg-error text-white"
          }`}
        >
          {badge > 99 ? "99+" : badge}
        </span>
      ) : null}
    </button>
  );
}

function accentFor(kind: string): { Icon: LucideIcon; cls: string } {
  if (kind === "INVITE_RECEIVED") return { Icon: Mail, cls: "bg-brand-soft text-brand-strong" };
  if (kind === "INVITE_ACCEPTED") return { Icon: CheckCircle2, cls: "bg-success-soft text-success" };
  if (kind === "INVITE_DECLINED") return { Icon: XCircle, cls: "bg-warning-soft text-warning" };
  if (kind === "INVITE_CANCELLED") return { Icon: CalendarX2, cls: "bg-surface-tint text-muted" };
  if (kind.startsWith("ORDER")) return { Icon: Package, cls: "bg-accent-indigo-soft text-accent-indigo" };
  if (kind.startsWith("QUOTATION")) return { Icon: FileText, cls: "bg-accent-indigo-soft text-accent-indigo" };
  if (kind.startsWith("RETURN")) return { Icon: Undo2, cls: "bg-accent-amber-soft text-accent-amber" };
  if (kind.startsWith("PAYMENT") || kind.startsWith("REFUND"))
    return { Icon: IndianRupee, cls: "bg-success-soft text-success" };
  if (kind === "SECURITY") return { Icon: ShieldCheck, cls: "bg-surface-tint text-muted" };
  return { Icon: Bell, cls: "bg-accent-indigo-soft text-accent-indigo" };
}

function hrefFor(kind: string): string | null {
  if (kind.startsWith("ORDER")) return "/dashboard/orders";
  if (kind.startsWith("QUOTATION")) return "/dashboard/quotations";
  if (kind.startsWith("RETURN")) return "/dashboard/returns";
  return null;
}

function InboxTab() {
  const router = useRouter();
  const t = useTranslations("notifications");
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
        setError(e instanceof Error ? e.message : t("errors.loadNotifications"));
      } finally {
        setLoading(false);
        setLoadingMore(false);
      }
    })();
  }, [t]);

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
    } finally {
      refresh();
    }
  }

  if (loading) return <ListRowsSkeleton rows={6} />;
  if (error) return <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>;
  if (items.length === 0)
    return (
      <EmptyState
        title={t("inbox.emptyTitle")}
        body={t("inbox.emptyBody")}
      />
    );

  return (
    <>
      <div className="flex justify-end">
        <button
          type="button"
          onClick={markAll}
          disabled={unread === 0}
          className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
        >
          <CheckCheck size={16} /> {t("inbox.markAllRead")}
        </button>
      </div>
      <ul className="mt-sm border-t border-hairline">
        {items.map((n) => (
          <li key={n.id}>
            <InboxRow n={n} onOpen={() => openOne(n)} />
          </li>
        ))}
      </ul>
      {page < totalPages ? (
        <div className="mt-lg flex justify-center">
          <button
            type="button"
            onClick={() => load(page + 1)}
            disabled={loadingMore}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            {loadingMore ? t("inbox.loading") : t("inbox.loadMore")}
          </button>
        </div>
      ) : null}
    </>
  );
}

function InboxRow({ n, onOpen }: { n: AppNotification; onOpen: () => void }) {
  const t = useTranslations("notifications");
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
      {unread ? <span className="mt-sm size-2 shrink-0 rounded-full bg-brand" aria-label={t("inbox.unread")} /> : null}
    </button>
  );
}

function linkAccent(linkType: string): { Icon: LucideIcon; cls: string } {
  if (linkType === "VENDOR") return { Icon: Store, cls: "bg-accent-indigo-soft text-accent-indigo" };
  if (linkType === "TEAM") return { Icon: UserCog, cls: "bg-brand-soft text-brand-strong" };
  return { Icon: Users, cls: "bg-accent-rose-soft text-accent-rose" };
}

function roleLabel(inv: Invitation, t: ReturnType<typeof useTranslations>): string {
  if (inv.linkType === "VENDOR") return t("roles.supplier");
  if (inv.linkType === "TEAM") return inv.teamRoleName || t("roles.teamMember");
  return t("roles.customer");
}

function StatusPill({ status }: { status: string }) {
  const t = useTranslations("notifications");
  const meta = INVITE_STATUS_META[status];
  const label = meta ? t(`status.${meta.labelKey}`) : status;
  const classes = meta?.classes ?? "bg-surface-tint text-muted";
  return (
    <span className={`inline-flex shrink-0 items-center rounded-full px-sm py-px text-label-md ${classes}`}>
      {label}
    </span>
  );
}

function InvitesTab() {
  const t = useTranslations("notifications");
  const [items, setItems] = useState<Invitation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(() => {
    void (async () => {
      setLoading(true);
      try {
        setItems(await listIncomingInvitations());
        setError(null);
      } catch (e) {
        setError(e instanceof Error ? e.message : t("errors.loadInvitations"));
      } finally {
        setLoading(false);
      }
    })();
  }, [t]);

  useEffect(() => {
    load();
  }, [load]);

  async function respond(inv: Invitation, action: "accept" | "decline") {
    setBusyId(inv.id);
    try {
      await (action === "accept" ? acceptInvitation(inv.id) : declineInvitation(inv.id));
      setItems((prev) =>
        prev.map((x) => (x.id === inv.id ? { ...x, status: action === "accept" ? "ACCEPTED" : "DECLINED" } : x)),
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : t("errors.updateInvitation"));
    } finally {
      setBusyId(null);
    }
  }

  if (loading) return <ListRowsSkeleton rows={4} />;
  if (error) return <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>;
  if (items.length === 0)
    return <EmptyState title={t("invites.emptyTitle")} body={t("invites.emptyBody")} />;

  return (
    <ul className="border-t border-hairline">
      {items.map((inv) => {
        const { Icon, cls } = linkAccent(inv.linkType);
        const who = inv.fromShopName || inv.fromUser?.name || t("invites.aShop");
        const pending = inv.status === "PENDING";
        return (
          <li key={inv.id} className="border-b border-hairline px-md py-md">
            <div className="flex items-start gap-md">
              <span className={`mt-px flex size-9 shrink-0 items-center justify-center rounded-lg ${cls}`}>
                <Icon size={18} />
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-body-md font-semibold text-ink">{who}</p>
                <p className="text-body-sm text-muted">
                  {t("invites.wantsToAdd", { role: roleLabel(inv, t) })}
                  {inv.displayName ? ` — “${inv.displayName}”` : ""}
                </p>
                {inv.createdAt ? (
                  <p className="mt-xs text-label-md text-subtle">{formatRelativeTime(inv.createdAt)}</p>
                ) : null}
              </div>
              <StatusPill status={inv.status} />
            </div>

            {inv.message ? (
              <p className="mt-sm rounded-md bg-surface-tint px-md py-sm text-body-sm text-ink">{inv.message}</p>
            ) : null}

            {pending ? (
              <div className="mt-md flex flex-wrap items-center gap-sm">
                <button
                  type="button"
                  onClick={() => respond(inv, "accept")}
                  disabled={busyId === inv.id}
                  className="inline-flex h-9 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
                >
                  <Check size={16} /> {t("invites.accept")}
                </button>
                <button
                  type="button"
                  onClick={() => respond(inv, "decline")}
                  disabled={busyId === inv.id}
                  className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
                >
                  <X size={16} /> {t("invites.decline")}
                </button>
              </div>
            ) : null}
          </li>
        );
      })}
    </ul>
  );
}

function SentTab() {
  const t = useTranslations("notifications");
  const [items, setItems] = useState<Invitation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(() => {
    void (async () => {
      setLoading(true);
      try {
        setItems(await listOutgoingInvitations());
        setError(null);
      } catch (e) {
        setError(e instanceof Error ? e.message : t("errors.loadInvitations"));
      } finally {
        setLoading(false);
      }
    })();
  }, [t]);

  useEffect(() => {
    load();
  }, [load]);

  async function cancel(inv: Invitation) {
    setBusyId(inv.id);
    try {
      await cancelInvitation(inv.id);
      setItems((prev) => prev.map((x) => (x.id === inv.id ? { ...x, status: "CANCELLED" } : x)));
    } catch (e) {
      setError(e instanceof Error ? e.message : t("errors.cancelInvitation"));
    } finally {
      setBusyId(null);
    }
  }

  if (loading) return <ListRowsSkeleton rows={4} />;
  if (error) return <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>;
  if (items.length === 0)
    return <EmptyState title={t("sent.emptyTitle")} body={t("sent.emptyBody")} />;

  return (
    <ul className="border-t border-hairline">
      {items.map((inv) => {
        const { Icon, cls } = linkAccent(inv.linkType);
        const pending = inv.status === "PENDING";
        return (
          <li key={inv.id} className="flex items-start gap-md border-b border-hairline px-md py-md">
            <span className={`mt-px flex size-9 shrink-0 items-center justify-center rounded-lg ${cls}`}>
              <Icon size={18} />
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-body-md text-ink">{inv.toEmail}</p>
              <p className="text-body-sm text-muted">
                {inv.displayName || roleLabel(inv, t)}
                {inv.createdAt ? ` · ${formatRelativeTime(inv.createdAt)}` : ""}
              </p>
            </div>
            <StatusPill status={inv.status} />
            {pending ? (
              <button
                type="button"
                onClick={() => cancel(inv)}
                disabled={busyId === inv.id}
                aria-label={t("sent.cancelInvitation")}
                title={t("sent.cancelInvitation")}
                className="inline-flex size-9 shrink-0 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink disabled:text-disabled"
              >
                <X size={16} />
              </button>
            ) : null}
          </li>
        );
      })}
    </ul>
  );
}

function EmptyState({ title, body }: { title: string; body: string }) {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <span className="flex size-14 items-center justify-center rounded-full bg-surface-tint text-muted">
        <Bell size={26} />
      </span>
      <p className="text-title-sm text-ink">{title}</p>
      <p className="max-w-content text-body-md text-muted">{body}</p>
    </div>
  );
}
