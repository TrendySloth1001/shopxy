import type { ReactNode } from "react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { Sidebar } from "@/features/dashboard/sidebar";

/**
 * Authenticated shell for the whole dashboard area. Persistent collapsible
 * sidebar + a full-width content outlet. Child routes (/dashboard,
 * /dashboard/products, …) render into `children`.
 */
export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <RequireAuth>
      <div className="flex min-h-dvh">
        <Sidebar />
        <main className="min-w-0 flex-1 overflow-x-hidden">{children}</main>
      </div>
    </RequireAuth>
  );
}
