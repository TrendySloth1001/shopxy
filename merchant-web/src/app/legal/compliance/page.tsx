import type { Metadata } from "next";
import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { ArrowRight } from "@/shared/icons";
import { GrievanceOfficerSection } from "@/features/legal/grievance-officer";
import { SECTIONS } from "@/features/legal/compliance-content";

export const metadata: Metadata = {
  title: "Compliance, laws & formulas · ShopXY",
};

export default async function ComplianceOverviewPage() {
  const t = await getTranslations("legal");
  return (
    <div className="flex flex-col gap-xl">
      <p className="text-body-md text-muted">{t("compliance.intro")}</p>

      <div className="flex flex-col gap-sm">
        <h2 className="text-label-lg uppercase tracking-wide text-subtle">{t("compliance.topics")}</h2>
        <ul className="flex flex-col divide-y divide-hairline">
          {SECTIONS.map((s) => (
            <li key={s.id}>
              <Link
                href={`/legal/compliance/${s.id}`}
                className="group flex items-start justify-between gap-md py-md transition-colors hover:bg-surface-tint"
              >
                <span className="flex flex-col gap-xs">
                  <span className="font-display text-title-sm text-ink">{t(`compliance.${s.key}.heading`)}</span>
                  <span className="text-body-sm text-muted">{t(`compliance.${s.key}.summary`)}</span>
                </span>
                <ArrowRight
                  size={18}
                  className="mt-xs shrink-0 text-subtle transition-colors group-hover:text-ink"
                />
              </Link>
            </li>
          ))}
        </ul>
      </div>

      <div className="border-t border-hairline pt-lg">
        <GrievanceOfficerSection />
      </div>

      <div className="border-t border-hairline pt-lg">
        <h2 className="text-title-sm text-ink">{t("compliance.scope.heading")}</h2>
        <p className="mt-sm text-body-md text-muted">
          {t.rich("compliance.scope.body", {
            terms: (chunks) => (
              <Link href="/legal/terms" className="text-ink underline hover:text-brand">
                {chunks}
              </Link>
            ),
            privacy: (chunks) => (
              <Link href="/legal/privacy" className="text-ink underline hover:text-brand">
                {chunks}
              </Link>
            ),
          })}
        </p>
      </div>
    </div>
  );
}
