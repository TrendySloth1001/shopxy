import type { Metadata } from "next";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { LoginForm } from "@/features/auth/components/login-form";
import { RememberedAccounts } from "@/features/auth/components/remembered-accounts";

export const metadata: Metadata = {
  title: "Sign in · ShopXY Merchant",
};

const NOTICES: Record<string, string> = {
  "password-changed": "Password changed. Please sign in again.",
  "signed-out-everywhere": "Signed out of all devices.",
  "account-deleted": "Your account has been deleted.",
  "google-soon": "Google sign-in is coming soon — please use your email for now.",
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ reason?: string }>;
}) {
  const { reason } = await searchParams;
  const notice = reason ? NOTICES[reason] : undefined;

  return (
    <AuthShell
      title="Welcome back"
      subtitle="Sign in to manage your inventory, invoices and customers."
      footerPrompt="New to ShopXY?"
      footerHref="/register"
      footerCta="Create an account"
      notice={notice}
    >
      <RememberedAccounts />
      <LoginForm />
    </AuthShell>
  );
}
