import type { Metadata } from "next";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { RecoveryPinLoginForm } from "@/features/auth/components/recovery-pin-login-form";

export const metadata: Metadata = {
  title: "Sign in with recovery PIN · ShopXY Merchant",
};

export default function RecoveryPinLoginPage() {
  return (
    <AuthShell
      title="Sign in with your recovery PIN"
      subtitle="For accounts that signed in with Google, when Google itself isn't reachable."
      footerPrompt="Google working again?"
      footerHref="/login"
      footerCta="Sign in the usual way"
    >
      <RecoveryPinLoginForm />
    </AuthShell>
  );
}
