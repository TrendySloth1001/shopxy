import type { ReactNode } from "react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { SectionGuard } from "@/features/auth/components/section-guard";
import { NotificationsProvider } from "@/features/notifications/notifications-context";
import { Sidebar } from "@/features/dashboard/sidebar";
import { PageTransition } from "@/features/dashboard/page-transition";
import { EnvironmentBadge } from "@/features/settings/environment-badge";

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <RequireAuth>
      <NotificationsProvider>
        <div className="flex min-h-dvh flex-col lg:flex-row">
          <Sidebar />
          <main className="min-w-0 flex-1 overflow-x-hidden">
            <PageTransition>
              <SectionGuard>{children}</SectionGuard>
            </PageTransition>
          </main>
          <EnvironmentBadge />
        </div>
      </NotificationsProvider>
    </RequireAuth>
  );
}
