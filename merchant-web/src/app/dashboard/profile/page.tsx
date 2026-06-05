"use client";

import { BadgeCheck, CalendarDays, Store } from "lucide-react";
import { useAuth } from "@/features/auth/auth-context";
import { Avatar } from "@/features/auth/components/avatar";
import { ProfileForm } from "@/features/auth/components/profile-form";
import { Divider } from "@/shared/ui/divider";

const SHOP_ROLE_LABELS: Record<string, string> = {
  OWNER: "Owner",
  MANAGER: "Manager",
  STOCKIST: "Stockist",
  CASHIER: "Cashier",
};

function memberSince(iso?: string): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return new Intl.DateTimeFormat("en-IN", { month: "short", year: "numeric" }).format(d);
}

export default function ProfilePage() {
  const { user } = useAuth();
  if (!user) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <p className="text-body-md text-subtle">Loading…</p>
      </div>
    );
  }

  const roleLabel = SHOP_ROLE_LABELS[user.shopRole ?? "OWNER"] ?? "Staff";
  const isOwner = (user.shopRole ?? "OWNER") === "OWNER";
  const since = memberSince(user.createdAt);
  const shopIncomplete =
    !user.shopName?.trim() || !user.shopStateCode?.trim() || !user.shopGstin?.trim();

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <h1 className="text-headline-md text-ink">Profile</h1>
      <p className="mt-xs text-body-md text-muted">
        Your identity and shop details — these appear on your invoices.
      </p>

      {/* Hero — branded identity snapshot */}
      <div className="mt-xl flex flex-wrap items-center gap-lg rounded-lg bg-hero-panel p-lg">
        <div className="rounded-full bg-white p-xs shadow-floating">
          <Avatar url={user.avatarUrl} name={user.name} size={76} />
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate text-title-lg text-ink">{user.name}</p>
          {user.shopName?.trim() ? (
            <p className="truncate text-title-sm text-brand-strong">{user.shopName}</p>
          ) : null}
          <p className="mt-xs truncate text-body-sm text-muted">{user.email}</p>
          <div className="mt-sm flex flex-wrap items-center gap-sm">
            <span
              className={`inline-flex items-center gap-xs rounded-full px-sm py-px text-body-sm font-semibold ${
                isOwner
                  ? "bg-brand-soft text-brand-strong"
                  : "bg-accent-indigo-soft text-accent-indigo"
              }`}
            >
              <BadgeCheck size={13} /> {roleLabel}
            </span>
            {since ? (
              <span className="inline-flex items-center gap-xs rounded-full bg-white px-sm py-px text-body-sm text-muted">
                <CalendarDays size={13} /> Since {since}
              </span>
            ) : null}
          </div>
        </div>
      </div>

      {/* Shop-completeness nudge */}
      {isOwner && shopIncomplete ? (
        <div className="mt-md flex items-start gap-sm rounded-md bg-accent-amber-soft px-md py-md">
          <Store size={18} className="mt-px shrink-0 text-accent-amber" />
          <div>
            <p className="text-body-md font-semibold text-ink">
              Finish setting up your shop
            </p>
            <p className="mt-px text-body-sm text-muted">
              Add your shop name, GSTIN and state code below so invoices print
              correctly.
            </p>
          </div>
        </div>
      ) : null}

      <Divider className="my-xxl" />

      {/* Editor */}
      <div className="grid gap-xl md:grid-cols-[220px_1fr]">
        <div>
          <h2 className="text-title-md text-ink">Edit profile</h2>
          <p className="mt-xs text-body-sm text-muted">
            Your name, photo and shop details used across the app and on invoices.
          </p>
        </div>
        <div className="max-w-content">
          <ProfileForm />
        </div>
      </div>
    </div>
  );
}
