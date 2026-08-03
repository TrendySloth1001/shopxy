import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { LoginForm } from "@/features/auth/components/login-form";
import { RememberedAccounts } from "@/features/auth/components/remembered-accounts";

export const metadata: Metadata = {
  title: "Sign in · ShopXY Merchant",
};

const NOTICE_KEYS: Record<string, string> = {
  "password-changed": "notice.passwordChanged",
  "signed-out-everywhere": "notice.signedOutEverywhere",
  "account-deleted": "notice.accountDeleted",
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ reason?: string }>;
}) {
  const t = await getTranslations("auth");
  const { reason } = await searchParams;
  const noticeKey = reason ? NOTICE_KEYS[reason] : undefined;
  const notice = noticeKey ? t(noticeKey) : undefined;

  return (
    <AuthShell
      title={t("login.title")}
      subtitle={t("login.subtitle")}
      footerPrompt={t("login.footerPrompt")}
      footerHref="/register"
      footerCta={t("login.footerCta")}
      notice={notice}
    >
      <RememberedAccounts />
      <LoginForm />
    </AuthShell>
  );
}
