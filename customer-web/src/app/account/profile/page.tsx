"use client";

import { SettingsScreen } from "@/features/auth/components/settings-screen";
import { ProfileForm } from "@/features/auth/components/profile-form";

export default function ProfileSettingsPage() {
  return (
    <SettingsScreen
      title="Profile"
      description="Your photo, name and contact details."
    >
      <ProfileForm />
    </SettingsScreen>
  );
}
