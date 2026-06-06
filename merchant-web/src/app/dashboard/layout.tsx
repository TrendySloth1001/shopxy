import type { ReactNode } from "react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { SectionGuard } from "@/features/auth/components/section-guard";
import { NotificationsProvider } from "@/features/notifications/notifications-context";
import { Sidebar } from "@/features/dashboard/sidebar";

/**
 * Authenticated shell for the whole dashboard area. Persistent collapsible
 * sidebar + a full-width content outlet. Child routes (/dashboard,
 * /dashboard/products, …) render into `children`.
 */
export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <RequireAuth>
      <NotificationsProvider>
        <div className="flex min-h-dvh">
          <Sidebar />
          <main className="min-w-0 flex-1 overflow-x-hidden">
            <SectionGuard>{children}</SectionGuard>
          </main>
        </div>
      </NotificationsProvider>
    </RequireAuth>
  );
}
