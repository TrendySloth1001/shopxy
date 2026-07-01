import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { CashierConsole } from "@/features/cashier/cashier-console";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("cashier");
  return { title: t("metaTitle") };
}

export default function CashierPage() {
  return <CashierConsole />;
}
