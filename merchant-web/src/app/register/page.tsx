import type { Metadata } from "next";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { RegisterForm } from "@/features/auth/components/register-form";

export const metadata: Metadata = {
  title: "Create account · ShopXY Merchant",
};

export default function RegisterPage() {
  return (
    <AuthShell
      title="Set up your shop"
      subtitle="Create your merchant account — we'll create your shop at the same time."
      footerPrompt="Already have an account?"
      footerHref="/login"
      footerCta="Sign in"
    >
      <RegisterForm />
    </AuthShell>
  );
}
