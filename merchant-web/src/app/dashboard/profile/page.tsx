"use client";

import { useState } from "react";
import { BadgeCheck, CalendarDays, Pencil, X } from "lucide-react";
import { useAuth } from "@/features/auth/auth-context";
import { Avatar } from "@/features/auth/components/avatar";
import { ProfileForm } from "@/features/auth/components/profile-form";
import { profileCompletion } from "@/features/auth/profile-completion";
import { Divider } from "@/shared/ui/divider";
import type { AuthUser } from "@/features/auth/types";
import { CardsSkeleton } from "@/shared/ui/skeleton";

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
  const [editing, setEditing] = useState(false);

  if (!user) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <CardsSkeleton count={3} />
      </div>
    );
  }

  const roleLabel = SHOP_ROLE_LABELS[user.shopRole ?? "OWNER"] ?? "Staff";
  const isOwner = (user.shopRole ?? "OWNER") === "OWNER";
  const since = memberSince(user.createdAt);
  const completion = profileCompletion(user);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <h1 className="text-headline-md text-ink">Profile</h1>
      <p className="mt-xs text-body-md text-muted">
        Your identity and shop details — these appear on your invoices.
      </p>

      {/* Hero — branded identity snapshot */}
      <div className="mt-xl flex flex-wrap items-center gap-lg rounded-lg bg-hero-panel p-lg">
        <div className="rounded-full bg-surface p-xs shadow-floating">
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
              <span className="inline-flex items-center gap-xs rounded-full bg-surface px-sm py-px text-body-sm text-muted">
                <CalendarDays size={13} /> Since {since}
              </span>
            ) : null}
          </div>
        </div>
      </div>

      {/* Completion meter */}
      {completion.percent < 100 ? (
        <CompletionBar
          percent={completion.percent}
          filled={completion.filled}
          total={completion.total}
          missing={completion.missing}
          onComplete={() => setEditing(true)}
          editing={editing}
        />
      ) : null}

      <Divider className="my-xxl" />

      {/* Details — read-only with an Edit toggle */}
      <div className="flex items-center justify-between gap-md">
        <div>
          <h2 className="text-title-md text-ink">Profile details</h2>
          <p className="mt-xs text-body-sm text-muted">
            Name, photo and shop details used across the app and on invoices.
          </p>
        </div>
        {!editing ? (
          <button
            type="button"
            onClick={() => setEditing(true)}
            className="inline-flex h-10 shrink-0 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Pencil size={16} /> Edit profile
          </button>
        ) : (
          <button
            type="button"
            onClick={() => setEditing(false)}
            className="inline-flex h-10 shrink-0 items-center gap-sm rounded-button px-md text-label-md text-muted transition-colors hover:text-ink"
          >
            <X size={16} /> Cancel
          </button>
        )}
      </div>

      <div className="mt-lg max-w-content">
        {editing ? (
          <ProfileForm onSaved={() => setEditing(false)} />
        ) : (
          <ReadOnlyDetails user={user} />
        )}
      </div>
    </div>
  );
}

function CompletionBar({
  percent,
  filled,
  total,
  missing,
  editing,
  onComplete,
}: {
  percent: number;
  filled: number;
  total: number;
  missing: string[];
  editing: boolean;
  onComplete: () => void;
}) {
  return (
    <div className="mt-lg max-w-content rounded-lg border border-hairline p-lg">
      <div className="flex items-end justify-between gap-md">
        <div>
          <p className="text-title-sm text-ink">Profile {percent}% complete</p>
          <p className="mt-xs text-body-sm text-muted">
            {filled} of {total} details added.
          </p>
        </div>
        {!editing ? (
          <button
            type="button"
            onClick={onComplete}
            className="inline-flex h-9 shrink-0 items-center rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            Complete it
          </button>
        ) : null}
      </div>
      <div
        className="mt-md h-2 w-full overflow-hidden rounded-full bg-surface-tint"
        role="progressbar"
        aria-valuenow={percent}
        aria-valuemin={0}
        aria-valuemax={100}
      >
        <div
          className="h-full rounded-full bg-brand transition-[width] duration-medium"
          style={{ width: `${percent}%` }}
        />
      </div>
      {missing.length > 0 ? (
        <div className="mt-md">
          <p className="text-label-md uppercase tracking-wide text-subtle">What’s left</p>
          <div className="mt-sm flex flex-wrap gap-sm">
            {missing.map((m) => (
              <span
                key={m}
                className="inline-flex items-center rounded-full bg-surface-tint px-sm py-px text-body-sm text-muted"
              >
                {m}
              </span>
            ))}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function ReadOnlyDetails({ user }: { user: AuthUser }) {
  const address = [user.shopAddress, user.shopCity, user.shopState, user.shopPinCode]
    .map((p) => p?.trim())
    .filter(Boolean)
    .join(", ");
  const rows: Array<[string, string | null | undefined]> = [
    ["Name", user.name],
    ["Phone", user.phoneNumber],
    ["Shop name", user.shopName],
    ["Address", address || null],
    ["State code", user.shopStateCode],
    ["GSTIN", user.shopGstin],
    ["GST registration", user.registrationType ? title(user.registrationType) : null],
    ["PAN", user.shopPan],
    ["UPI ID", user.upiVpa],
  ];
  return (
    <dl className="grid gap-x-xxl gap-y-md sm:grid-cols-2">
      {rows.map(([label, value]) => (
        <div key={label} className="flex flex-col gap-px border-b border-hairline pb-sm">
          <dt className="text-label-md text-subtle">{label}</dt>
          <dd className={value ? "text-body-md text-ink" : "text-body-md text-subtle"}>
            {value || "Not set"}
          </dd>
        </div>
      ))}
    </dl>
  );
}

function title(s: string): string {
  return s.charAt(0) + s.slice(1).toLowerCase();
}
