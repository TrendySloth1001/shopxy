"use client";

import { useState } from "react";
import {
  BadgeCheck,
  CalendarDays,
  CreditCard,
  Pencil,
  ReceiptText,
  ShieldCheck,
  Store,
  User,
  Users,
  Wallet,
  X,
  type LucideIcon,
} from "lucide-react";
import { useAuth } from "@/features/auth/auth-context";
import { Avatar } from "@/features/auth/components/avatar";
import { ProfileForm } from "@/features/auth/components/profile-form";
import { profileCompletion } from "@/features/auth/profile-completion";
import { SettingRow } from "@/features/settings/components";
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

      <div className="mt-xl flex flex-col gap-xl lg:flex-row lg:items-start lg:gap-xxl">
        {/* ── Identity sidebar — sticks while the details scroll ───────── */}
        <aside className="shrink-0 space-y-lg lg:sticky lg:top-xxl lg:w-80 xl:w-96">
          {/* Branded identity snapshot */}
          <div className="flex flex-col items-center rounded-lg bg-hero-panel p-xl text-center">
            <div className="rounded-full bg-surface p-xs shadow-floating">
              <Avatar url={user.avatarUrl} name={user.name} size={88} />
            </div>
            <p className="mt-md w-full truncate text-title-lg text-ink">{user.name}</p>
            {user.shopName?.trim() ? (
              <p className="w-full truncate text-title-sm text-brand-strong">{user.shopName}</p>
            ) : null}
            <p className="mt-xs w-full truncate text-body-sm text-muted">{user.email}</p>
            <div className="mt-md flex flex-wrap items-center justify-center gap-sm">
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

          {/* Jump to related shop settings */}
          <div className="rounded-lg border border-hairline p-sm">
            <p className="px-sm pb-xs pt-sm text-label-md uppercase tracking-wide text-subtle">
              Manage
            </p>
            <SettingRow icon={Store} title="Shop" subtitle="Storefront & policies" href="/dashboard/shop" />
            <SettingRow icon={Users} title="Team" subtitle="Staff & permissions" href="/dashboard/team" />
            <SettingRow icon={Wallet} title="Payouts" subtitle="Bank & KYC" href="/dashboard/payouts" />
            <SettingRow icon={ShieldCheck} title="Security" subtitle="Password & sign-in" href="/dashboard/settings" />
          </div>
        </aside>

        {/* ── Details pane — fills the remaining width ──────────────────── */}
        <section className="min-w-0 flex-1">
          <div className="flex items-center justify-between gap-md border-b border-hairline pb-md">
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

          <div className="mt-lg">
            {editing ? (
              <div className="max-w-content">
                <ProfileForm onSaved={() => setEditing(false)} />
              </div>
            ) : (
              <ReadOnlyDetails user={user} />
            )}
          </div>
        </section>
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
    <div className="rounded-lg border border-hairline p-lg">
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

type DetailRow = { label: string; value: string | null | undefined };

function ReadOnlyDetails({ user }: { user: AuthUser }) {
  const address = [user.shopAddress, user.shopCity, user.shopState, user.shopPinCode]
    .map((p) => p?.trim())
    .filter(Boolean)
    .join(", ");

  const sections: { title: string; icon: LucideIcon; rows: DetailRow[] }[] = [
    {
      title: "Personal",
      icon: User,
      rows: [
        { label: "Name", value: user.name },
        { label: "Phone", value: user.phoneNumber },
        { label: "Email", value: user.email },
      ],
    },
    {
      title: "Shop",
      icon: Store,
      rows: [
        { label: "Shop name", value: user.shopName },
        { label: "Address", value: address || null },
        { label: "State code", value: user.shopStateCode },
      ],
    },
    {
      title: "Tax & registration",
      icon: ReceiptText,
      rows: [
        {
          label: "GST registration",
          value: user.registrationType ? title(user.registrationType) : null,
        },
        { label: "GSTIN", value: user.shopGstin },
        { label: "PAN", value: user.shopPan },
      ],
    },
    {
      title: "Payment",
      icon: CreditCard,
      rows: [{ label: "UPI ID", value: user.upiVpa }],
    },
  ];

  return (
    <div className="space-y-xxl">
      {sections.map((section) => (
        <section key={section.title}>
          <div className="flex items-center gap-sm">
            <section.icon size={16} className="shrink-0 text-subtle" />
            <h3 className="text-label-md uppercase tracking-wide text-subtle">{section.title}</h3>
          </div>
          <dl className="mt-md grid gap-x-xxl gap-y-md sm:grid-cols-2 xl:grid-cols-3">
            {section.rows.map((row) => (
              <div key={row.label} className="flex flex-col gap-px border-b border-hairline pb-sm">
                <dt className="text-label-md text-subtle">{row.label}</dt>
                <dd className={row.value ? "text-body-md text-ink" : "text-body-md text-subtle"}>
                  {row.value || "Not set"}
                </dd>
              </div>
            ))}
          </dl>
        </section>
      ))}
    </div>
  );
}

function title(s: string): string {
  return s.charAt(0) + s.slice(1).toLowerCase();
}
