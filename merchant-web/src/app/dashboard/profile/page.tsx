"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
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

const SHOP_ROLES = ["OWNER", "MANAGER", "STOCKIST", "CASHIER"] as const;

function memberSince(iso?: string): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return new Intl.DateTimeFormat("en-IN", { month: "short", year: "numeric" }).format(d);
}

export default function ProfilePage() {
  const { user } = useAuth();
  const t = useTranslations("auth");
  const [editing, setEditing] = useState(false);

  if (!user) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <CardsSkeleton count={3} />
      </div>
    );
  }

  const shopRole = user.shopRole ?? "OWNER";
  const roleLabel = (SHOP_ROLES as readonly string[]).includes(shopRole)
    ? t(`role.${shopRole}`)
    : t("role.STAFF");
  const isOwner = shopRole === "OWNER";
  const since = memberSince(user.createdAt);
  const completion = profileCompletion(user);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <h1 className="text-headline-md text-ink">{t("profilePage.title")}</h1>
      <p className="mt-xs text-body-md text-muted">
        {t("profilePage.subtitle")}
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
                  <CalendarDays size={13} /> {t("profilePage.since", { date: since })}
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
              {t("profilePage.manage")}
            </p>
            <SettingRow icon={Store} title={t("profilePage.shopTitle")} subtitle={t("profilePage.shopSubtitle")} href="/dashboard/shop" />
            <SettingRow icon={Users} title={t("profilePage.teamTitle")} subtitle={t("profilePage.teamSubtitle")} href="/dashboard/team" />
            <SettingRow icon={Wallet} title={t("profilePage.payoutsTitle")} subtitle={t("profilePage.payoutsSubtitle")} href="/dashboard/payouts" />
            <SettingRow icon={ShieldCheck} title={t("profilePage.securityTitle")} subtitle={t("profilePage.securitySubtitle")} href="/dashboard/settings" />
          </div>
        </aside>

        {/* ── Details pane — fills the remaining width ──────────────────── */}
        <section className="min-w-0 flex-1">
          <div className="flex items-center justify-between gap-md border-b border-hairline pb-md">
            <div>
              <h2 className="text-title-md text-ink">{t("profilePage.detailsTitle")}</h2>
              <p className="mt-xs text-body-sm text-muted">
                {t("profilePage.detailsSubtitle")}
              </p>
            </div>
            {!editing ? (
              <button
                type="button"
                onClick={() => setEditing(true)}
                className="inline-flex h-10 shrink-0 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                <Pencil size={16} /> {t("profilePage.editProfile")}
              </button>
            ) : (
              <button
                type="button"
                onClick={() => setEditing(false)}
                className="inline-flex h-10 shrink-0 items-center gap-sm rounded-button px-md text-label-md text-muted transition-colors hover:text-ink"
              >
                <X size={16} /> {t("common.cancel")}
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
  const t = useTranslations("auth");
  return (
    <div className="rounded-lg border border-hairline p-lg">
      <div className="flex items-end justify-between gap-md">
        <div>
          <p className="text-title-sm text-ink">{t("completion.title", { percent })}</p>
          <p className="mt-xs text-body-sm text-muted">
            {t("completion.detailsAdded", { filled, total })}
          </p>
        </div>
        {!editing ? (
          <button
            type="button"
            onClick={onComplete}
            className="inline-flex h-9 shrink-0 items-center rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            {t("completion.completeIt")}
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
          <p className="text-label-md uppercase tracking-wide text-subtle">{t("completion.whatsLeft")}</p>
          <div className="mt-sm flex flex-wrap gap-sm">
            {missing.map((m) => (
              <span
                key={m}
                className="inline-flex items-center rounded-full bg-surface-tint px-sm py-px text-body-sm text-muted"
              >
                {t(`field.${m}`)}
              </span>
            ))}
          </div>
        </div>
      ) : null}
    </div>
  );
}

type DetailRow = { key: string; label: string; value: string | null | undefined };

function ReadOnlyDetails({ user }: { user: AuthUser }) {
  const t = useTranslations("auth");
  const address = [user.shopAddress, user.shopCity, user.shopState, user.shopPinCode]
    .map((p) => p?.trim())
    .filter(Boolean)
    .join(", ");

  const regTypeValue =
    user.registrationType && (["REGULAR", "COMPOSITION", "UNREGISTERED"] as const).includes(
      user.registrationType as "REGULAR" | "COMPOSITION" | "UNREGISTERED",
    )
      ? t(`regType.${user.registrationType}`)
      : null;

  const sections: { key: string; title: string; icon: LucideIcon; rows: DetailRow[] }[] = [
    {
      key: "personal",
      title: t("details.personal"),
      icon: User,
      rows: [
        { key: "name", label: t("field.name"), value: user.name },
        { key: "phone", label: t("field.phone"), value: user.phoneNumber },
        { key: "email", label: t("field.email"), value: user.email },
      ],
    },
    {
      key: "shop",
      title: t("details.shop"),
      icon: Store,
      rows: [
        { key: "shopName", label: t("field.shopName"), value: user.shopName },
        { key: "address", label: t("field.address"), value: address || null },
        { key: "stateCode", label: t("field.stateCode"), value: user.shopStateCode },
      ],
    },
    {
      key: "tax",
      title: t("details.tax"),
      icon: ReceiptText,
      rows: [
        {
          key: "gstRegistration",
          label: t("field.gstRegistration"),
          value: regTypeValue,
        },
        { key: "gstin", label: t("field.gstin"), value: user.shopGstin },
        { key: "pan", label: t("field.pan"), value: user.shopPan },
      ],
    },
    {
      key: "payment",
      title: t("details.payment"),
      icon: CreditCard,
      rows: [{ key: "upiId", label: t("field.upiId"), value: user.upiVpa }],
    },
  ];

  return (
    <div className="space-y-xxl">
      {sections.map((section) => (
        <section key={section.key}>
          <div className="flex items-center gap-sm">
            <section.icon size={16} className="shrink-0 text-subtle" />
            <h3 className="text-label-md uppercase tracking-wide text-subtle">{section.title}</h3>
          </div>
          <dl className="mt-md grid gap-x-xxl gap-y-md sm:grid-cols-2 xl:grid-cols-3">
            {section.rows.map((row) => (
              <div key={row.key} className="flex flex-col gap-px border-b border-hairline pb-sm">
                <dt className="text-label-md text-subtle">{row.label}</dt>
                <dd className={row.value ? "text-body-md text-ink" : "text-body-md text-subtle"}>
                  {row.value || t("common.notSet")}
                </dd>
              </div>
            ))}
          </dl>
        </section>
      ))}
    </div>
  );
}
