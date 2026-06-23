"use client";

import { SettingsScreen } from "@/features/auth/components/settings-screen";
import { SecuritySection } from "@/features/auth/components/security-section";

export default function SecuritySettingsPage() {
  return (
    <SettingsScreen
      title="Login & security"
      description="Your password and active sessions."
    >
      <SecuritySection />
    </SettingsScreen>
  );
}
