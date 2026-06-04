"use client";

import { useState } from "react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { Sidebar } from "@/features/dashboard/sidebar";
import { DashboardHome } from "@/features/dashboard/dashboard-home";
import { NAV_LABELS } from "@/features/dashboard/nav-items";
import { Divider } from "@/shared/ui/divider";

export default function DashboardPage() {
  return (
    <RequireAuth>
      <DashboardShell />
    </RequireAuth>
  );
}

function DashboardShell() {
  const [active, setActive] = useState("dashboard");

  return (
    <div className="flex min-h-dvh">
      <Sidebar active={active} onSelect={setActive} />
      {/* Full-width content — no centered rail (CLAUDE.md layout rule). */}
      <main className="min-w-0 flex-1 overflow-x-hidden">
        {active === "dashboard" ? (
          <DashboardHome />
        ) : (
          <Placeholder section={active} />
        )}
      </main>
    </div>
  );
}

function Placeholder({ section }: { section: string }) {
  const label = NAV_LABELS[section] ?? section;
  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <h1 className="text-headline-md text-ink">{label}</h1>
      <Divider className="my-xxl" />
      <p className="text-body-md text-muted">
        This section isn’t built yet — the {label} screen is coming soon.
      </p>
    </div>
  );
}
