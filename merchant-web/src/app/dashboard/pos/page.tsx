import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { PosTillView } from "@/features/pos/pos-till-view";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("pos");
  return { title: t("metaTitle") };
}

export default function PosPage() {
  return <PosTillView />;
}
