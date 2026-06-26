import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, ArrowRight } from "lucide-react";
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
  return {
    title: section ? `${section.nav} · Compliance · ShopXY` : "Compliance · ShopXY",
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

  const idx = SECTIONS.findIndex((s) => s.id === slug);
  const prev = idx > 0 ? SECTIONS[idx - 1] : null;
  const next = idx < SECTIONS.length - 1 ? SECTIONS[idx + 1] : null;

  return (
    <article className="flex flex-col gap-xl">
      <h2 className="font-display text-headline-sm text-ink">{section.heading}</h2>

      <ComplianceSectionBody section={section} />

      <nav
        aria-label="Topic pagination"
        className="flex items-center justify-between gap-md border-t border-hairline pt-lg"
      >
        {prev ? (
          <Link
            href={`/legal/compliance/${prev.id}`}
            className="inline-flex items-center gap-xs text-label-md text-muted transition-colors hover:text-ink"
          >
            <ArrowLeft size={16} /> {prev.nav}
          </Link>
        ) : (
          <span />
        )}
        {next ? (
          <Link
            href={`/legal/compliance/${next.id}`}
            className="inline-flex items-center gap-xs text-label-md text-muted transition-colors hover:text-ink"
          >
            {next.nav} <ArrowRight size={16} />
          </Link>
        ) : (
          <span />
        )}
      </nav>
    </article>
  );
}
