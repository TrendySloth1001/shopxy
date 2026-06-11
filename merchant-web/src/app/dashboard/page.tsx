import { DashboardHome } from "@/features/dashboard/dashboard-home";

export const metadata = { title: "Dashboard" };

// The dashboard index. The shell (sidebar + auth gate) lives in layout.tsx.
export default function DashboardPage() {
  return <DashboardHome />;
}
