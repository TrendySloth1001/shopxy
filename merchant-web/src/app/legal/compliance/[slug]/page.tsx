import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { ArrowLeft, ArrowRight } from "@/shared/icons";
import { getSection, SECTIONS } from "@/features/legal/compliance-content";
import { ComplianceSectionBody } from "@/features/legal/compliance-section";

export function generateStaticParams() {
  return SECTIONS.map((s) => ({ slug: s.id }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const section = getSection(slug);
  if (!section) return { title: "Compliance · ShopXY" };
  const t = await getTranslations("legal");
  return {
    title: `${t(`compliance.${section.key}.nav`)} · Compliance · ShopXY`,
  };
}

export default async function ComplianceTopicPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const section = getSection(slug);
  if (!section) notFound();

  const t = await getTranslations("legal");
  const idx = SECTIONS.findIndex((s) => s.id === slug);
  const prev = idx > 0 ? SECTIONS[idx - 1] : null;
  const next = idx < SECTIONS.length - 1 ? SECTIONS[idx + 1] : null;

  return (
    <article className="flex flex-col gap-xl">
      <h2 className="font-display text-headline-sm text-ink">{t(`compliance.${section.key}.heading`)}</h2>

      <ComplianceSectionBody section={section} />

      <nav
        aria-label={t("compliance.pagination.ariaLabel")}
        className="flex items-center justify-between gap-md border-t border-hairline pt-lg"
      >
        {prev ? (
          <Link
            href={`/legal/compliance/${prev.id}`}
            className="inline-flex items-center gap-xs text-label-md text-muted transition-colors hover:text-ink"
          >
            <ArrowLeft size={16} /> {t(`compliance.${prev.key}.nav`)}
          </Link>
        ) : (
          <span />
        )}
        {next ? (
          <Link
            href={`/legal/compliance/${next.id}`}
            className="inline-flex items-center gap-xs text-label-md text-muted transition-colors hover:text-ink"
          >
            {t(`compliance.${next.key}.nav`)} <ArrowRight size={16} />
          </Link>
        ) : (
          <span />
        )}
      </nav>
    </article>
  );
}
