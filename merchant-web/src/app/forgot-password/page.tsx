import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { ForgotPasswordForm } from "@/features/auth/components/forgot-password-form";

export const metadata: Metadata = {
  title: "Reset password · ShopXY Merchant",
};

export default async function ForgotPasswordPage() {
  const t = await getTranslations("auth");
  return (
    <AuthShell
      title={t("forgot.title")}
      subtitle={t("forgot.subtitle")}
      footerPrompt={t("forgot.footerPrompt")}
      footerHref="/login"
      footerCta={t("forgot.footerCta")}
    >
      <ForgotPasswordForm />
    </AuthShell>
  );
}
