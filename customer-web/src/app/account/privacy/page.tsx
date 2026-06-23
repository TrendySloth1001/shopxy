"use client";

import { SettingsScreen } from "@/features/auth/components/settings-screen";
import { DangerZone } from "@/features/auth/components/danger-zone";

export default function PrivacySettingsPage() {
  return (
    <SettingsScreen
      title="Data & privacy"
      description="Export a copy of your data, or delete your account."
    >
      <DangerZone />
    </SettingsScreen>
  );
}
