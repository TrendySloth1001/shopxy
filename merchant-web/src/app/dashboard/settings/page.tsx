"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import {
  AtSign,
  Bell,
  IndianRupee,
  Info,
  Languages,
  LogOut,
  Palette,
  UserPen,
} from "lucide-react";
import { useAuth } from "@/features/auth/auth-context";
import { SecuritySection } from "@/features/auth/components/security-section";
import { DangerZone } from "@/features/auth/components/danger-zone";
import { Divider } from "@/shared/ui/divider";
import {
  ComingSoon,
  Eyebrow,
  NotificationsToggle,
  SettingRow,
} from "@/features/settings/components";

export default function SettingsPage() {
  const { user, logout } = useAuth();
  const router = useRouter();
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

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <h1 className="text-headline-md text-ink">Settings</h1>
      <p className="mt-xs text-body-md text-muted">
        Manage your account, security, preferences and data.
      </p>

      <div className="mt-xl max-w-content">
        {/* Account */}
        <Eyebrow>Account</Eyebrow>
        <SettingRow
          icon={UserPen}
          title="Edit profile"
          subtitle={user?.name ?? "—"}
          href="/dashboard/profile"
        />
        <SettingRow icon={AtSign} title="Email" subtitle={user?.email ?? "—"} />

        <SectionGap />

        {/* Notifications */}
        <Eyebrow>Notifications</Eyebrow>
        <NotificationsToggle icon={Bell} />

        <SectionGap />

        {/* Security */}
        <Eyebrow>Security</Eyebrow>
        <div className="px-sm pt-sm">
          <div className="max-w-form">
            <SecuritySection />
          </div>
        </div>

        <SectionGap />

        {/* Preferences */}
        <Eyebrow>Preferences</Eyebrow>
        <SettingRow
          icon={IndianRupee}
          title="Currency"
          subtitle="Indian Rupee (₹)"
        />
        <SettingRow
          icon={Palette}
          title="Theme"
          subtitle="Light"
          trailing={<ComingSoon />}
        />
        <SettingRow
          icon={Languages}
          title="Language"
          subtitle="English"
          trailing={<ComingSoon />}
        />

        <SectionGap />

        {/* Data & privacy */}
        <Eyebrow>Data &amp; privacy</Eyebrow>
        <div className="px-sm pt-sm">
          <div className="max-w-form">
            <DangerZone />
          </div>
        </div>

        <SectionGap />

        {/* About */}
        <Eyebrow>About</Eyebrow>
        <SettingRow icon={Info} title="App version" subtitle="1.0.0" />

        <SectionGap />

        {/* Sign out */}
        <button
          type="button"
          onClick={onSignOut}
          disabled={signingOut}
          className="flex w-full items-center gap-md rounded-md bg-error-soft px-md py-md text-left text-body-md text-error transition-colors hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error-soft disabled:opacity-60"
        >
          <LogOut size={18} className="shrink-0" />
          {signingOut ? "Signing out…" : "Sign out"}
        </button>
      </div>
    </div>
  );
}

function SectionGap() {
  return <Divider className="my-xl" />;
}
