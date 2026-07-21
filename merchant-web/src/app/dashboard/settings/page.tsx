"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  AtSign,
  Bell,
  FileText,
  IndianRupee,
  Info,
  LogOut,
  Palette,
  ShieldAlert,
  ShieldCheck,
  SlidersHorizontal,
  Store,
  type LucideIcon,
  UserPen,
  Users,
  Wallet,
} from "@/shared/icons";
import { useAuth } from "@/features/auth/auth-context";
import { SecuritySection } from "@/features/auth/components/security-section";
import { DangerZone } from "@/features/auth/components/danger-zone";
import {
  ComingSoon,
  NotificationsToggle,
  SettingRow,
} from "@/features/settings/components";
import { ThemePicker } from "@/features/theme/theme-picker";
import { LanguagePicker } from "@/features/i18n/language-picker";

type SectionKey =
  | "account"
  | "shop"
  | "inventory"
  | "notifications"
  | "security"
  | "preferences"
  | "privacy"
  | "about";

// Labels + blurbs come from the message catalog (settings.sections.<key>); the
// array carries only the stable key + icon.
const SECTIONS: { key: SectionKey; icon: LucideIcon }[] = [
  { key: "account", icon: UserPen },
  { key: "shop", icon: Store },
  { key: "inventory", icon: SlidersHorizontal },
  { key: "notifications", icon: Bell },
  { key: "security", icon: ShieldCheck },
  { key: "preferences", icon: Palette },
  { key: "privacy", icon: ShieldAlert },
  { key: "about", icon: Info },
];

/** Responsive tile grid — fills the pane, gaining columns as width grows. */
function TileGrid({ children }: { children: React.ReactNode }) {
  return <div className="grid grid-cols-1 gap-md sm:grid-cols-2 xl:grid-cols-3">{children}</div>;
}

export default function SettingsPage() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const t = useTranslations("settings");
  const [active, setActive] = useState<SectionKey>("account");
  const [signingOut, setSigningOut] = useState(false);

  async function onSignOut() {
    setSigningOut(true);
    try {
      await logout();
      router.replace("/login");
    } catch {
      setSigningOut(false);
    }
  }

  const current = SECTIONS.find((s) => s.key === active) ?? SECTIONS[0];

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <h1 className="text-headline-md text-ink">{t("title")}</h1>
      <p className="mt-xs text-body-md text-muted">{t("subtitle")}</p>

      <div className="mt-xl flex flex-col gap-xl md:flex-row md:gap-xxl">
        {/* Category rail */}
        <nav className="flex shrink-0 gap-xs overflow-x-auto md:w-60 md:flex-col md:overflow-visible">
          {SECTIONS.map((s) => {
            const on = s.key === active;
            const Icon = s.icon;
            return (
              <button
                key={s.key}
                type="button"
                onClick={() => setActive(s.key)}
                className={`inline-flex shrink-0 items-center gap-sm rounded-md px-md py-sm text-left text-label-md transition-colors ${
                  on ? "bg-brand-soft text-brand-strong" : "text-muted hover:bg-surface-tint hover:text-ink"
                }`}
              >
                <Icon size={18} className="shrink-0" />
                {t(`sections.${s.key}.label`)}
              </button>
            );
          })}

          <div className="mt-auto hidden pt-lg md:block">
            <button
              type="button"
              onClick={onSignOut}
              disabled={signingOut}
              className="inline-flex w-full items-center gap-sm rounded-md px-md py-sm text-left text-label-md text-error transition-colors hover:bg-error-soft disabled:opacity-60"
            >
              <LogOut size={18} className="shrink-0" />
              {signingOut ? t("signingOut") : t("signOut")}
            </button>
          </div>
        </nav>

        {/* Content pane — fills the remaining width */}
        <section className="min-w-0 flex-1">
          <div className="flex items-center gap-md border-b border-hairline pb-md">
            <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-brand-soft text-brand-strong">
              <current.icon size={20} />
            </span>
            <div>
              <h2 className="text-title-md text-ink">{t(`sections.${current.key}.label`)}</h2>
              <p className="text-body-sm text-muted">{t(`sections.${current.key}.blurb`)}</p>
            </div>
          </div>

          <div className="mt-lg">
            {active === "account" ? (
              <TileGrid>
                <SettingRow tile icon={UserPen} title={t("rows.editProfile")} subtitle={user?.name ?? "—"} href="/dashboard/profile" />
                <SettingRow tile icon={AtSign} title={t("rows.email")} subtitle={user?.email ?? "—"} />
              </TileGrid>
            ) : null}

            {active === "shop" ? (
              <TileGrid>
                <SettingRow tile icon={Store} title={t("rows.shop")} subtitle={t("rows.shopSub")} href="/dashboard/shop" />
                <SettingRow tile icon={Users} title={t("rows.team")} subtitle={t("rows.teamSub")} href="/dashboard/team" />
                <SettingRow tile icon={Wallet} title={t("rows.payouts")} subtitle={t("rows.payoutsSub")} href="/dashboard/payouts" />
              </TileGrid>
            ) : null}

            {active === "inventory" ? (
              <TileGrid>
                <SettingRow tile icon={SlidersHorizontal} title={t("rows.customFields")} subtitle={t("rows.customFieldsSub")} href="/dashboard/custom-fields" />
              </TileGrid>
            ) : null}

            {active === "notifications" ? (
              <div className="max-w-content rounded-lg border border-hairline p-sm">
                <NotificationsToggle icon={Bell} />
              </div>
            ) : null}

            {active === "security" ? (
              <div className="max-w-form">
                <SecuritySection />
              </div>
            ) : null}

            {active === "preferences" ? (
              <div className="space-y-xxl">
                <div>
                  <h3 className="text-title-sm text-ink">{t("theme")}</h3>
                  <p className="mb-md mt-xs text-body-sm text-muted">
                    {t("themeSubtitle")}
                  </p>
                  <ThemePicker />
                </div>
                <div>
                  <h3 className="text-title-sm text-ink">{t("language")}</h3>
                  <p className="mb-md mt-xs text-body-sm text-muted">
                    {t("languageSubtitle")}
                  </p>
                  <LanguagePicker />
                </div>
                <TileGrid>
                  <SettingRow tile icon={IndianRupee} title={t("currency")} subtitle={t("currencySubtitle")} trailing={<ComingSoon />} />
                </TileGrid>
              </div>
            ) : null}

            {active === "privacy" ? (
              <div className="max-w-form">
                <DangerZone />
              </div>
            ) : null}

            {active === "about" ? (
              <TileGrid>
                <SettingRow tile icon={Info} title={t("rows.appVersion")} subtitle={process.env.NEXT_PUBLIC_APP_VERSION ?? "—"} />
                <SettingRow tile icon={ShieldAlert} title={t("rows.privacyPolicy")} subtitle={t("rows.privacyPolicySub")} href="/legal/privacy" />
                <SettingRow tile icon={FileText} title={t("rows.terms")} subtitle={t("rows.termsSub")} href="/legal/terms" />
              </TileGrid>
            ) : null}
          </div>

          {/* Sign out — inline on mobile where the rail footer is hidden */}
          <button
            type="button"
            onClick={onSignOut}
            disabled={signingOut}
            className="mt-xxl flex w-full items-center justify-center gap-sm rounded-md bg-error-soft px-md py-md text-body-md text-error transition-colors hover:opacity-90 disabled:opacity-60 md:hidden"
          >
            <LogOut size={18} className="shrink-0" />
            {signingOut ? "Signing out…" : "Sign out"}
          </button>
        </section>
      </div>
    </div>
  );
}
