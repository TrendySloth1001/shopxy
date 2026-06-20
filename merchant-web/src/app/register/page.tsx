import type { Metadata } from "next";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { RegisterForm } from "@/features/auth/components/register-form";

export const metadata: Metadata = {
  title: "Create account · ShopXY Merchant",
};

export default function RegisterPage() {
  return (
    <AuthShell
      title="Create your account"
      subtitle="Set up your merchant account. You'll name your shop in the next step — or skip it if you've been invited to join a team."
      footerPrompt="Already have an account?"
      footerHref="/login"
      footerCta="Sign in"
    >
      <RegisterForm />
    </AuthShell>
  );
}
