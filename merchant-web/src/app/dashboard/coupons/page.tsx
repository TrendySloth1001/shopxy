"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { BarChart3, Plus, Power, RefreshCw, Ticket } from "@/shared/icons";
import { PageHeader } from "@/shared/ui/page-header";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { formatDateTime, formatRelativeTime } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import { deactivateCoupon, listCoupons, listCouponRedemptions } from "@/features/coupons/api";
import type { CouponRedemption } from "@/features/coupons/schema";
import {
  COUPON_STATE_CLASSES,
  couponState,
  discountLabel,
} from "@/features/coupons/format";
import type { Coupon } from "@/features/coupons/schema";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { useCanManage } from "@/features/auth/use-can";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

export default function CouponsPage() {
  const t = useTranslations("coupons");
  const [rows, setRows] = useState<Coupon[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [deactivateTarget, setDeactivateTarget] = useState<Coupon | null>(null);
  const [deactivateBusy, setDeactivateBusy] = useState(false);
  const [redeemTarget, setRedeemTarget] = useState<Coupon | null>(null);
  const canEdit = useCanManage("marketing");

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await listCoupons();
        if (!active) return;
        setRows(data);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("errors.load"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, t]);

  async function confirmDeactivate() {
    if (!deactivateTarget) return;
    setDeactivateBusy(true);
    try {
      await deactivateCoupon(deactivateTarget.id);
      setDeactivateTarget(null);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("errors.deactivate"));
    } finally {
      setDeactivateBusy(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Ticket}
        tone="brand"
        title={t("list.title")}
        subtitle={t("list.subtitle")}
      >
        <button
          type="button"
          onClick={reload}
          disabled={loading}
          aria-label={t("actions.refresh")}
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <MaybeLocked area="marketing" label={t("actions.new")}>
          <Link
            href="/dashboard/coupons/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> {t("actions.new")}
          </Link>
        </MaybeLocked>
      </PageHeader>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl">
        {loading ? (
          <ListRowsSkeleton />
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-brand-soft text-brand-strong">
              <Ticket size={22} />
            </span>
            <p className="text-body-md text-muted">{t("list.empty")}</p>
            <MaybeLocked area="marketing" label={t("actions.new")}>
              <Link
                href="/dashboard/coupons/new"
                className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
              >
                <Plus size={16} /> {t("actions.new")}
              </Link>
            </MaybeLocked>
          </div>
        ) : (
          rows.map((c) => (
            <CouponRow
              key={c.id}
              coupon={c}
              canEdit={canEdit}
              onDeactivate={() => setDeactivateTarget(c)}
              onViewRedemptions={() => setRedeemTarget(c)}
            />
          ))
        )}
      </div>

      {deactivateTarget ? (
        <Modal title={t("deactivate.title", { code: deactivateTarget.code })} onClose={() => setDeactivateTarget(null)}>
          <p className="text-body-md text-muted">
            {t("deactivate.body")}
          </p>
          <ModalActions
            busy={deactivateBusy}
            danger
            confirmLabel={t("deactivate.confirm")}
            onCancel={() => setDeactivateTarget(null)}
            onConfirm={confirmDeactivate}
          />
        </Modal>
      ) : null}

      {redeemTarget ? (
        <RedemptionsModal coupon={redeemTarget} onClose={() => setRedeemTarget(null)} />
      ) : null}
    </div>
  );
}

function RedemptionsModal({ coupon, onClose }: { coupon: Coupon; onClose: () => void }) {
  const t = useTranslations("coupons");
  const [rows, setRows] = useState<CouponRedemption[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const data = await listCouponRedemptions(coupon.id);
        if (active) setRows(data);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("errors.loadRedemptions"));
      }
    })();
    return () => {
      active = false;
    };
  }, [coupon.id, t]);

  const total = rows?.reduce((s, r) => s + r.discountAmount, 0) ?? 0;

  return (
    <Modal title={t("redemptions.title", { code: coupon.code })} onClose={onClose} wide>
      <p className="text-body-md text-muted">
        {t("redemptions.count", { count: coupon.totalRedemptions })}
        {rows && rows.length > 0
          ? ` · ${t("redemptions.given", { amount: formatINR2(total), last: rows.length })}`
          : ""}
      </p>
      {error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : rows === null ? (
        <p className="py-lg text-center text-body-sm text-subtle">{t("redemptions.loading")}</p>
      ) : rows.length === 0 ? (
        <p className="py-lg text-center text-body-sm text-subtle">{t("redemptions.empty")}</p>
      ) : (
        <ul className="border-t border-hairline">
          {rows.map((r) => (
            <li key={r.id} className="flex items-center justify-between gap-md border-b border-hairline py-sm">
              <span className="min-w-0">
                <span className="block truncate text-body-md text-ink">{r.user?.name ?? t("redemptions.customer")}</span>
                <span className="block truncate text-body-sm text-subtle">
                  {r.user?.email ?? ""}
                  {r.orderId != null ? ` · ${t("redemptions.order", { id: r.orderId })}` : ""}
                </span>
              </span>
              <span className="shrink-0 text-right">
                <span className="block text-body-md tabular-nums text-ink">{formatINR2(r.discountAmount)}</span>
                <span className="block text-body-sm text-subtle">{formatRelativeTime(r.redeemedAt)}</span>
              </span>
            </li>
          ))}
        </ul>
      )}
    </Modal>
  );
}

function CouponRow({
  coupon,
  canEdit,
  onDeactivate,
  onViewRedemptions,
}: {
  coupon: Coupon;
  canEdit: boolean;
  onDeactivate: () => void;
  onViewRedemptions: () => void;
}) {
  const t = useTranslations("coupons");
  const state = couponState(coupon);
  return (
    <div className="flex items-start gap-md border-b border-hairline py-md">
      <Link href={`/dashboard/coupons/${coupon.id}/edit`} className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-sm">
          <span className="text-body-md font-bold text-ink">
            {coupon.code} · {discountLabel(coupon)}
          </span>
          <span
            className={`inline-flex shrink-0 items-center rounded-full px-sm py-px text-body-sm font-semibold ${COUPON_STATE_CLASSES[state]}`}
          >
            {t(`state.${state}`)}
          </span>
        </div>
        <p className="mt-px text-body-md text-muted">{coupon.title}</p>
        {coupon.isPublic || coupon.firstOrderOnly ? (
          <div className="mt-xs flex flex-wrap gap-xs">
            {coupon.isPublic ? (
              <span className="inline-flex items-center rounded-full bg-info-soft px-sm py-px text-body-sm font-semibold text-info">
                {t("badges.publicAutoApplies")}
              </span>
            ) : null}
            {coupon.firstOrderOnly ? (
              <span className="inline-flex items-center rounded-full bg-accent-amber-soft px-sm py-px text-body-sm font-semibold text-accent-amber">
                {t("badges.firstOrderOnly")}
              </span>
            ) : null}
          </div>
        ) : null}
        <p className="mt-xs text-body-sm text-subtle">
          {t("row.validRange", {
            from: formatDateTime(coupon.validFrom),
            until: formatDateTime(coupon.validUntil),
          })}{" "}
          ·{" "}
          {t("row.redeemedCount", {
            used: coupon.totalRedemptions,
            cap: coupon.totalCap > 0 ? `/${coupon.totalCap}` : "",
          })}
        </p>
      </Link>
      {coupon.totalRedemptions > 0 ? (
        <button
          type="button"
          onClick={onViewRedemptions}
          aria-label={t("actions.viewRedemptions")}
          title={t("actions.viewRedemptions")}
          className="inline-flex size-9 shrink-0 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
        >
          <BarChart3 size={18} />
        </button>
      ) : null}
      {coupon.isActive ? (
        <button
          type="button"
          onClick={onDeactivate}
          disabled={!canEdit}
          aria-label={t("actions.deactivate")}
          title={canEdit ? t("actions.deactivate") : t("actions.noAccess")}
          className="inline-flex size-9 shrink-0 items-center justify-center rounded-button text-muted transition-colors hover:bg-error-soft hover:text-error disabled:text-disabled disabled:hover:bg-transparent"
        >
          <Power size={18} />
        </button>
      ) : null}
    </div>
  );
}
