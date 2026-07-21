"use client";

import Image from "next/image";
import { useMemo } from "react";
import { Store, Mail, CheckCircle, XCircle, Clock } from "@/shared/icons";
import type { Invitation } from "../types";
import { formatRelativeTime } from "@/shared/datetime";

// ─── Status chip ──────────────────────────────────────────────────────────

function statusStyle(status: Invitation["status"]): { label: string; cls: string } {
  switch (status) {
    case "PENDING":
      return { label: "Pending", cls: "bg-info-soft text-info" };
    case "ACCEPTED":
      return { label: "Accepted", cls: "bg-success-soft text-success" };
    case "DECLINED":
      return { label: "Declined", cls: "bg-hero-panel text-muted" };
    case "CANCELLED":
      return { label: "Cancelled", cls: "bg-hero-panel text-muted" };
    case "EXPIRED":
      return { label: "Expired", cls: "bg-warning-soft text-warning" };
  }
}

// ─── Banner cover ─────────────────────────────────────────────────────────

function CardCover({ bannerUrl }: { bannerUrl?: string | null }) {
  if (bannerUrl) {
    return (
      <div className="relative h-20 w-full overflow-hidden">
        <Image
          src={bannerUrl.startsWith("/images/") ? `/api/media${bannerUrl}` : bannerUrl}
          alt=""
          fill
          className="object-cover"
          sizes="(max-width: 640px) 100vw, 600px"
        />
        <div className="absolute inset-0 bg-gradient-to-b from-transparent to-black/20" />
      </div>
    );
  }
  return (
    <div className="flex h-20 w-full items-center justify-end bg-gradient-to-br from-brand-soft to-hero-panel px-lg">
      <Store size={32} className="text-brand opacity-60" />
    </div>
  );
}

// ─── Shop logo ────────────────────────────────────────────────────────────

function ShopLogo({
  logoUrl,
  initial,
}: {
  logoUrl?: string | null;
  initial: string;
}) {
  const src = logoUrl
    ? logoUrl.startsWith("/images/")
      ? `/api/media${logoUrl}`
      : logoUrl
    : null;

  return (
    <div className="relative h-14 w-14 flex-shrink-0 overflow-hidden rounded-md border border-hairline bg-white shadow-floating">
      {src ? (
        <Image src={src} alt="" fill className="object-cover" sizes="56px" />
      ) : (
        <div className="flex h-full w-full items-center justify-center bg-brand-soft">
          <span className="text-title-lg font-black text-brand">{initial}</span>
        </div>
      )}
    </div>
  );
}

// ─── Main InviteCard ──────────────────────────────────────────────────────

export type InviteCardProps = {
  invite: Invitation;
  /** Show Accept/Decline buttons (Pending tab). False shows a status chip only. */
  actionable?: boolean;
  busy?: boolean;
  onAccept?: () => void;
  onDecline?: () => void;
};

export function InviteCard({
  invite,
  actionable = false,
  busy = false,
  onAccept,
  onDecline,
}: InviteCardProps) {
  const shopName =
    invite.shop?.name ?? invite.fromShopName ?? invite.displayName ?? null;
  const senderName = invite.fromUser?.name ?? null;
  const initial = shopName
    ? shopName.trim()[0]?.toUpperCase() ?? "?"
    : senderName
      ? senderName.trim()[0]?.toUpperCase() ?? "?"
      : "?";

  const title =
    senderName && shopName
      ? `${senderName} invited you to ${shopName}`
      : senderName
        ? `${senderName} invited you`
        : shopName
          ? `${shopName} invited you`
          : "You have a new invitation";

  const subtitle =
    invite.linkType === "VENDOR"
      ? "Join as a supplier to this shop"
      : "Join as a customer of this shop";

  const hasMessage = invite.message && invite.message.trim().length > 0;
  const { label: statusLabel, cls: statusCls } = statusStyle(invite.status);

  const expiryText = useMemo(() => {
    if (!invite.expiresAt) return null;
    const expiry = new Date(invite.expiresAt).getTime();
    const now = new Date().getTime();
    const diff = expiry - now;
    if (diff <= 0) return "Expired";
    const days = Math.floor(diff / 86_400_000);
    const hours = Math.floor(diff / 3_600_000);
    if (days >= 2) return `Expires in ${days} days`;
    if (hours >= 2) return `Expires in ${hours} hours`;
    return "Expires soon";
  }, [invite.expiresAt]);

  return (
    <div className="overflow-hidden rounded-lg border border-hairline bg-white">
      {/* Banner */}
      <CardCover bannerUrl={invite.shop?.bannerUrl} />

      {/* Body */}
      <div className="px-md pb-md">
        {/* Logo + text row — logo overlaps banner via negative margin */}
        <div className="-mt-7 flex items-start gap-md">
          <ShopLogo logoUrl={invite.shop?.logoUrl} initial={initial} />
          <div className="min-w-0 flex-1 pt-md">
            {/* Status chip */}
            {!actionable && (
              <span
                className={`mb-xs inline-block rounded-full px-sm py-[2px] text-label-md font-extrabold ${statusCls}`}
              >
                {statusLabel}
              </span>
            )}
            <p className="text-title-sm font-extrabold leading-snug text-ink line-clamp-2">
              {title}
            </p>
            <p className="mt-[2px] text-body-sm text-muted">{subtitle}</p>
          </div>
        </div>

        {/* Optional message */}
        {hasMessage && (
          <div className="mt-sm rounded-sm bg-hero-panel px-md py-sm">
            <div className="flex items-start gap-xs">
              <Mail size={14} className="mt-[1px] flex-shrink-0 text-muted" />
              <p className="text-body-sm leading-relaxed text-ink">{invite.message}</p>
            </div>
          </div>
        )}

        {/* Expiry */}
        {actionable && expiryText && (
          <p className="mt-xs text-label-md text-muted">
            <Clock size={11} className="mr-[3px] inline-block align-middle" />
            {expiryText}
          </p>
        )}

        {/* History: time + responded */}
        {!actionable && invite.respondedAt && (
          <p className="mt-xs text-label-md text-muted">
            {statusLabel} {formatRelativeTime(invite.respondedAt)}
          </p>
        )}

        {!actionable && !invite.respondedAt && invite.createdAt && (
          <p className="mt-xs text-label-md text-muted">
            Received {formatRelativeTime(invite.createdAt)}
          </p>
        )}

        {/* Action buttons */}
        {actionable && (
          <div className="mt-md flex items-center gap-sm">
            {/* Decline */}
            <button
              type="button"
              disabled={busy}
              onClick={onDecline}
              className="inline-flex h-10 flex-1 items-center justify-center gap-xs rounded-button border border-hairline bg-white text-label-lg font-bold text-muted transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:cursor-not-allowed disabled:opacity-40"
            >
              <XCircle size={15} />
              Decline
            </button>

            {/* Accept */}
            <button
              type="button"
              disabled={busy}
              onClick={onAccept}
              className="inline-flex h-10 flex-[2] items-center justify-center gap-xs rounded-button bg-brand px-lg text-label-lg font-extrabold text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:cursor-not-allowed disabled:opacity-50"
            >
              {busy ? (
                <span
                  className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white"
                  aria-hidden
                />
              ) : (
                <>
                  <CheckCircle size={15} />
                  Accept
                </>
              )}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Skeleton ─────────────────────────────────────────────────────────────

export function InviteCardSkeleton() {
  return (
    <div className="overflow-hidden rounded-lg border border-hairline bg-white">
      {/* Banner shimmer */}
      <div className="h-20 w-full animate-pulse bg-hero-panel" />
      {/* Body */}
      <div className="px-md pb-md">
        <div className="-mt-7 flex items-start gap-md">
          {/* Logo */}
          <div className="h-14 w-14 flex-shrink-0 animate-pulse rounded-md bg-hero-panel" />
          <div className="flex-1 pt-md">
            <div className="h-3 w-1/3 animate-pulse rounded-full bg-hero-panel" />
            <div className="mt-sm h-4 w-4/5 animate-pulse rounded-full bg-hero-panel" />
            <div className="mt-xs h-3 w-1/2 animate-pulse rounded-full bg-hero-panel" />
          </div>
        </div>
        <div className="mt-md h-11 animate-pulse rounded-sm bg-hero-panel" />
        <div className="mt-md flex gap-sm">
          <div className="h-10 flex-1 animate-pulse rounded-button bg-hero-panel" />
          <div className="h-10 flex-[2] animate-pulse rounded-button bg-hero-panel" />
        </div>
      </div>
    </div>
  );
}
