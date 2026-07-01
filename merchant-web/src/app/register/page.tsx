import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { RegisterForm } from "@/features/auth/components/register-form";

export const metadata: Metadata = {
  title: "Create account · ShopXY Merchant",
};

export default async function RegisterPage() {
  const t = await getTranslations("auth");
  return (
    <AuthShell
      title={t("register.title")}
      subtitle={t("register.subtitle")}
      footerPrompt={t("register.footerPrompt")}
      footerHref="/login"
      footerCta={t("register.footerCta")}
    >
      <RegisterForm />
    </AuthShell>
  );
}
