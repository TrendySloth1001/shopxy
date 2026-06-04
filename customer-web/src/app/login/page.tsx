import type { Metadata } from "next";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { LoginForm } from "@/features/auth/components/login-form";

export const metadata: Metadata = {
  title: "Sign in · ShopXY",
};

const NOTICES: Record<string, string> = {
  "password-changed": "Password changed. Please sign in again.",
  "signed-out-everywhere": "Signed out of all devices.",
  "account-deleted": "Your account has been deleted.",
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
      subtitle="Sign in to see your shops, invitations and invoice ledgers."
      footerPrompt="New to ShopXY?"
      footerHref="/register"
      footerCta="Create an account"
      notice={notice}
    >
      <LoginForm />
    </AuthShell>
  );
}
