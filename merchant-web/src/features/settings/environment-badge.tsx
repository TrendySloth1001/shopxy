"use client";

import Link from "next/link";
import { TriangleAlert } from "@/shared/icons";
import { useDeveloperEnvironments } from "./environment-picker";

export function EnvironmentBadge() {
  const { available, state } = useDeveloperEnvironments();

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
