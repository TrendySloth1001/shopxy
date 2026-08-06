import type { ReactNode } from "react";
import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";

// Server-side title for this dashboard section (the page is a client
// component, which cannot export metadata itself).
export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("numbering");
  return { title: t("title") };
}

export default function SectionLayout({ children }: { children: ReactNode }) {
  return children;
}
