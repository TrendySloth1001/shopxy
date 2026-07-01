import type { ReactNode } from "react";
import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";

// Server-side title for this dashboard section (the pages are client components,
// which cannot export metadata themselves).
export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("parties");
  return { title: t("list.title") };
}

export default function SectionLayout({ children }: { children: ReactNode }) {
  return children;
}
