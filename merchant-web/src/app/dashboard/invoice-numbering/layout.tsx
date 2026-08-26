import type { ReactNode } from "react";
import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("numbering");
  return { title: t("title") };
}

export default function SectionLayout({ children }: { children: ReactNode }) {
  return children;
}
