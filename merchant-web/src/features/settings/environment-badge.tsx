"use client";

import Link from "next/link";
import { TriangleAlert } from "@/shared/icons";
import { useDeveloperEnvironments } from "./environment-picker";

/**
 * A persistent marker that this browser is pointed at a non-default backend.
 *
 * Without it the only evidence lives on the Settings screen, and the failure
 * mode is a developer staring at an empty dashboard wondering why production
 * has no orders — when in fact they are looking at a dev tunnel. Cheap to
 * show, and it costs nothing when nothing is overridden.
 *
 * Renders nothing for everyone but the developer account: the hook's endpoint
 * 404s for other sessions, so `available` stays false and no request the badge
 * makes can reveal that the feature exists.
 */
export function EnvironmentBadge() {
  const { available, state } = useDeveloperEnvironments();

  // `isDefault` means no cookie override is in force, which is the quiet case
  // worth staying quiet about.
  if (!available || !state || state.isDefault) return null;

  const label =
    state.options.find((o) => o.id === state.currentId)?.label ??
    state.currentId ??
    "Unknown";

  return (
    <Link
      href="/dashboard/settings"
      title="This browser is pointed at a non-default backend. Open Settings to change it."
      className="fixed bottom-lg right-lg z-40 inline-flex items-center gap-xs rounded-full bg-warning-soft px-md py-xs text-label-md font-semibold text-warning shadow-sm transition-opacity hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <TriangleAlert size={14} className="shrink-0" />
      {label}
    </Link>
  );
}
