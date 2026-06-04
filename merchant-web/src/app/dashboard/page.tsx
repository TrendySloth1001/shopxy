"use client";

import Link from "next/link";
import { useAuth } from "@/features/auth/auth-context";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { Divider } from "@/shared/ui/divider";

export default function DashboardPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <DashboardBody />
    </RequireAuth>
  );
}

function DashboardBody() {
  const { user } = useAuth();
  if (!user) return null;

  const facts: Array<[string, string]> = [
    ["Name", user.name],
    ["Email", user.email],
    ["Shop", user.shopName ?? "—"],
    ["Role", user.shopRoleName ?? user.shopRole ?? user.role],
  ];

  return (
    <main className="mx-auto max-w-content px-lg py-xxxl">
      <p className="text-label-md uppercase tracking-wide text-brand">Dashboard</p>
      <h1 className="mt-xs text-headline-md text-ink">
        Welcome back, {user.name}
      </h1>
      <p className="mt-sm text-body-md text-muted">
        {user.shopName ? `Managing ${user.shopName}` : "Your merchant account"}
      </p>

      <Divider className="my-xxl" />

      <dl className="grid grid-cols-1 gap-lg sm:grid-cols-2">
        {facts.map(([label, value]) => (
          <div key={label} className="flex flex-col gap-xs">
            <dt className="text-label-md text-subtle">{label}</dt>
            <dd className="text-body-lg text-ink">{value}</dd>
          </div>
        ))}
      </dl>

      <Divider className="my-xxl" />

      <Link
        href="/account"
        className="text-body-md text-brand-strong underline-offset-2 hover:underline focus-visible:underline focus-visible:outline-none"
      >
        Manage your account →
      </Link>
    </main>
  );
}
