import type { Metadata } from "next";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { RegisterForm } from "@/features/auth/components/register-form";

export const metadata: Metadata = {
  title: "Create account · ShopXY",
};

export default function RegisterPage() {
  return (
    <AuthShell
      title="Create your account"
      subtitle="Join ShopXY to track your orders and shop ledgers in one place."
      footerPrompt="Already have an account?"
      footerHref="/login"
      footerCta="Sign in"
    >
      <RegisterForm />
    </AuthShell>
  );
}
