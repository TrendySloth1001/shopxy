import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { ArrowLeft } from "@/shared/icons";
import { ComplianceNav } from "@/features/legal/compliance-nav";

export default async function ComplianceLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const t = await getTranslations("legal");
  return (
    <main className="mx-auto max-w-docs px-lg py-xxxl">
      <Link
        href="/login"
        className="inline-flex items-center gap-xs text-label-md text-muted transition-colors hover:text-ink"
      >
        <ArrowLeft size={16} /> ShopXY
      </Link>
      <h1 className="mt-md font-display text-headline-md text-ink">
        {t("compliance.layout.title")}
      </h1>
      <p className="mt-xs text-body-sm text-subtle">{t("compliance.layout.updated")}</p>

      <div className="mt-xl flex flex-col gap-lg lg:grid lg:grid-cols-4 lg:gap-xxl">
        <aside className="lg:col-span-1 lg:self-start lg:sticky lg:top-xxl">
          <ComplianceNav />
        </aside>
        <div className="min-w-0 lg:col-span-3">{children}</div>
      </div>
    </main>
  );
}
