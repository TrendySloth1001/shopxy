import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { VerifyEmailForm } from "@/features/auth/components/verify-email-form";

export const metadata: Metadata = {
  title: "Verify your email · ShopXY Merchant",
};

export default async function VerifyEmailPage({
  searchParams,
}: {
  searchParams: Promise<{ email?: string }>;
}) {
  const t = await getTranslations("auth");
  const { email } = await searchParams;
  return (
    <AuthShell
      title={t("verify.title")}
      subtitle={email ? t("verify.subtitle", { email }) : t("verify.title")}
      footerPrompt={t("verify.footerPrompt")}
      footerHref="/register"
      footerCta={t("verify.footerCta")}
    >
      <VerifyEmailForm email={email ?? ""} />
    </AuthShell>
  );
}
