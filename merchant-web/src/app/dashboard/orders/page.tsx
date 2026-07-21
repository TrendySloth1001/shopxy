"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { Search } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import { DatePicker } from "@/shared/ui/date-picker";
import { listOrders, pendingOrderCount } from "@/features/orders/api";
import type { OrderList, OrderListRow } from "@/features/orders/schema";
import { money, formatDateTime } from "@/features/orders/format";
import { OrderStatusBadge } from "@/features/orders/components/order-status-badge";

const PAGE_SIZE = 30;

const TABS: Array<{ key: string; status: string | null }> = [
  { key: "pending", status: "PENDING" },
  { key: "confirmed", status: "CONFIRMED" },
  { key: "rejected", status: "REJECTED" },
  { key: "all", status: null },
];

export default function OrdersInboxPage() {
  const t = useTranslations("orders");
  const [tab, setTab] = useState(0);
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [page, setPage] = useState(1);

  const [data, setData] = useState<OrderList | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [pending, setPending] = useState(0);

  // Debounce the search box.
  useEffect(() => {
    const handle = setTimeout(() => {
      setSearch(searchInput.trim());
      setPage(1);
    }, 300);
    return () => clearTimeout(handle);
  }, [searchInput]);

  // Pending count for the tab badge — refresh whenever the list reloads.
  useEffect(() => {
    let active = true;
    void (async () => {
      const c = await pendingOrderCount();
      if (active) setPending(c);
    })();
    return () => {
      active = false;
    };
  }, [nonce]);

  const status = TABS[tab]?.status ?? null;
  const queryKey = `${status}|${search}|${from}|${to}|${page}|${nonce}`;

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const query: Record<string, string> = {
          page: String(page),
          limit: String(PAGE_SIZE),
        };
        if (status) query.status = status;
        if (search) query.search = search;
        if (from) query.from = new Date(`${from}T00:00:00`).toISOString();
        if (to) query.to = new Date(`${to}T23:59:59`).toISOString();
        const result = await listOrders(query);
        if (!active) return;
        setData(result);
        setError(null);
      } catch (e) {
        if (!active) return;
        setError(e instanceof Error ? e.message : t("list.loadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [queryKey]);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  const total = data?.pagination.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const orders = data?.data ?? [];
  const hasFilters = search !== "" || from !== "" || to !== "";

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <div>
        <h1 className="text-headline-md text-ink">{t("list.title")}</h1>
        <p className="mt-xs text-body-md text-muted">
          {t("list.subtitle")}
        </p>
      </div>

      {/* Status tabs */}
      <div className="mt-xl flex flex-wrap gap-sm">
        {TABS.map((tabDef, i) => (
          <TabPill
            key={tabDef.key}
            label={t(`tabs.${tabDef.key}`)}
            badge={tabDef.status === "PENDING" && pending > 0 ? pending : undefined}
            active={i === tab}
            onClick={() => {
              setTab(i);
              setPage(1);
            }}
          />
        ))}
      </div>

      {/* Search + date range */}
      <div className="mt-md flex flex-wrap items-center gap-md">
        <div className="relative min-w-[220px] flex-1">
          <Search
            size={18}
            className="pointer-events-none absolute left-md top-1/2 -translate-y-1/2 text-subtle"
          />
          <input
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder={t("list.searchPlaceholder")}
            className="h-10 w-full rounded-input border border-hairline bg-field pl-massive pr-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
          />
        </div>
        <DateField
          label={t("list.fromLabel")}
          value={from}
          max={to || undefined}
          onChange={(v) => {
            setFrom(v);
            setPage(1);
          }}
        />
        <DateField
          label={t("list.toLabel")}
          value={to}
          min={from || undefined}
          onChange={(v) => {
            setTo(v);
            setPage(1);
          }}
        />
        {hasFilters ? (
          <button
            type="button"
            onClick={() => {
              setSearchInput("");
              setSearch("");
              setFrom("");
              setTo("");
              setPage(1);
            }}
            className="h-10 rounded-button px-md text-label-md text-muted transition-colors hover:text-ink"
          >
            {t("list.clear")}
          </button>
        ) : null}
      </div>

      <Divider className="mt-lg" />

      {/* List */}
      {loading && !data ? (
        <ListSkeleton />
      ) : error && !data ? (
        <div className="flex flex-col items-start gap-md py-xxxl">
          <p className="text-body-md text-muted">{error}</p>
          <button
            type="button"
            onClick={reload}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            {t("list.tryAgain")}
          </button>
        </div>
      ) : orders.length === 0 ? (
        <EmptyInbox isPending={status === "PENDING"} hasFilters={hasFilters} />
      ) : (
        <ul>
          {orders.map((o) => (
            <OrderRow key={o.id} order={o} />
          ))}
        </ul>
      )}

      {/* Pagination */}
      {total > PAGE_SIZE ? (
        <div className="mt-lg flex items-center justify-between">
          <p className="text-body-sm text-muted">
            {t("list.pageOf", { page, totalPages })}
          </p>
          <div className="flex gap-sm">
            <PagerButton disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
              {t("list.previous")}
            </PagerButton>
            <PagerButton
              disabled={page >= totalPages}
              onClick={() => setPage((p) => p + 1)}
            >
              {t("list.next")}
            </PagerButton>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function TabPill({
  label,
  badge,
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
      aria-pressed={active}
      className={`inline-flex h-9 items-center gap-sm rounded-full px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
        active
          ? "bg-inverse-surface text-on-inverse"
          : "bg-surface-tint text-muted hover:text-ink"
      }`}
    >
      {label}
      {badge != null ? (
        <span
          className={`inline-flex min-w-[18px] items-center justify-center rounded-full px-xs text-body-sm tabular-nums ${
            active ? "bg-surface text-ink" : "bg-warning text-white"
          }`}
        >
          {badge}
        </span>
      ) : null}
    </button>
  );
}

function DateField({
  label,
  value,
  min,
  max,
  onChange,
}: {
  label: string;
  value: string;
  min?: string;
  max?: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="inline-flex items-center gap-sm">
      <span className="text-label-md text-subtle">{label}</span>
      <DatePicker
        value={value}
        min={min}
        max={max}
        onChange={onChange}
        ariaLabel={label}
        className="w-full sm:w-44"
      />
    </div>
  );
}

function PagerButton({
  disabled,
  onClick,
  children,
}: {
  disabled: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled disabled:hover:bg-transparent"
    >
      {children}
    </button>
  );
}

/** "3 PCS Solder Wire · 2 PCS Tea Bag (+1 more)" from the inbox preview. */
function previewText(
  order: OrderListRow,
  more: (count: number) => string,
): string | null {
  if (order.itemsPreview.length === 0) return null;
  const parts = order.itemsPreview.map((p) => {
    const q = Number.isInteger(p.quantity) ? p.quantity : p.quantity.toFixed(2);
    return `${q} ${p.unit} ${p.productName}`;
  });
  const itemCount = order._count?.items ?? parts.length;
  const remainder = itemCount - parts.length;
  const body = parts.join(" · ");
  return remainder > 0 ? `${body} ${more(remainder)}` : body;
}

function OrderRow({ order }: { order: OrderListRow }) {
  const t = useTranslations("orders");
  const preview = previewText(order, (count) => t("list.moreItems", { count }));
  const itemCount = order._count?.items ?? order.itemsPreview.length;
  return (
    <li>
      <Link
        href={`/dashboard/orders/${order.id}`}
        className="flex items-start gap-md border-t border-hairline py-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        <div className="min-w-0 flex-1">
          <div className="flex items-baseline gap-sm">
            <span className="text-title-sm text-ink">#{order.id}</span>
            <span className="min-w-0 flex-1 truncate text-body-md text-ink">
              {order.customerName}
            </span>
          </div>
          {preview ? (
            <p className="mt-px truncate text-body-sm text-ink/80">{preview}</p>
          ) : null}
          <p className="mt-px text-body-sm text-muted">
            {formatDateTime(order.createdAt)} · {t("list.itemCount", { count: itemCount })}
          </p>
        </div>
        <div className="flex shrink-0 flex-col items-end gap-xs">
          <span className="text-title-sm tabular-nums text-ink">
            {money(order.estimatedTotal)}
          </span>
          <OrderStatusBadge status={order.status} />
        </div>
      </Link>
    </li>
  );
}

function EmptyInbox({
  isPending,
  hasFilters,
}: {
  isPending: boolean;
  hasFilters: boolean;
}) {
  const t = useTranslations("orders");
  const allCaughtUp = isPending && !hasFilters;
  return (
    <div className="flex flex-col items-center gap-sm py-massive text-center">
      <p className="text-title-md text-ink">
        {allCaughtUp
          ? t("empty.caughtUpTitle")
          : hasFilters
            ? t("empty.noMatchTitle")
            : t("empty.noneTitle")}
      </p>
      <p className="max-w-content text-body-md text-muted">
        {allCaughtUp
          ? t("empty.caughtUpBody")
          : hasFilters
            ? t("empty.noMatchBody")
            : t("empty.noneBody")}
      </p>
    </div>
  );
}

function ListSkeleton() {
  return (
    <ul className="animate-pulse">
      {Array.from({ length: 6 }).map((_, i) => (
        <li key={i} className="flex items-start gap-md border-t border-hairline py-md">
          <div className="min-w-0 flex-1">
            <div className="h-3 w-48 rounded-xs bg-hairline" />
            <div className="mt-sm h-3 w-64 rounded-xs bg-hairline" />
            <div className="mt-sm h-3 w-40 rounded-xs bg-hairline" />
          </div>
          <div className="flex flex-col items-end gap-sm">
            <div className="h-3 w-16 rounded-xs bg-hairline" />
            <div className="h-5 w-20 rounded-full bg-hairline" />
          </div>
        </li>
      ))}
    </ul>
  );
}
