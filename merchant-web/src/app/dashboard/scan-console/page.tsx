import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { ScanConsoleView } from "@/features/scan-console/scan-console-view";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("scanConsole");
  return { title: t("meta.title") };
}

export default function ScanConsolePage() {
  return <ScanConsoleView />;
}
