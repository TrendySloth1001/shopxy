"use client";

import type { ReactNode } from "react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { ProfileForm } from "@/features/auth/components/profile-form";
import { SecuritySection } from "@/features/auth/components/security-section";
import { DangerZone } from "@/features/auth/components/danger-zone";
import { Divider } from "@/shared/ui/divider";

export default function AccountPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <main className="mx-auto max-w-content px-lg py-xxxl">
        <h1 className="text-headline-md text-ink">Account</h1>
        <p className="mt-sm text-body-md text-muted">
          Manage your profile, security and data.
        </p>

        <Section title="Profile" description="Your name and contact details.">
          <ProfileForm />
        </Section>

        <Section title="Security" description="Your password and active sessions.">
          <SecuritySection />
        </Section>

        <Section
          title="Data & privacy"
          description="Export a copy of your data, or delete your account."
        >
          <DangerZone />
        </Section>
      </main>
    </RequireAuth>
  );
}

/** Label rail + content, separated from the previous section by a divider. */
function Section({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <section className="py-xxl">
      <Divider className="mb-xxl" />
      <div className="grid gap-xl md:grid-cols-[200px_1fr]">
        <div>
          <h2 className="text-title-md text-ink">{title}</h2>
          <p className="mt-xs text-body-sm text-muted">{description}</p>
        </div>
        <div className="max-w-form">{children}</div>
      </div>
    </section>
  );
}
