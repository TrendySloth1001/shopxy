"use client";

import type { ReactNode } from "react";
import { RequireAuth } from "./require-auth";
import { AppHeader } from "./app-header";
import { BackButton } from "@/shared/ui/back-button";

/**
 * Shared chrome for a single account-settings screen (Profile, Security,
 * Data & privacy …). Each lives on its own route under `/account/*` so the
 * `/account` landing stays a pure menu rather than a long edit page.
 */
export function SettingsScreen({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <RequireAuth>
      <AppHeader />
      <main className="mx-auto max-w-content px-lg py-xxxl">
        <BackButton fallback="/account" className="mb-md" />
        <h1 className="text-headline-md text-ink">{title}</h1>
        <p className="mt-xs text-body-md text-muted">{description}</p>
        <div className="mt-xxl max-w-form">{children}</div>
      </main>
    </RequireAuth>
  );
}
