import type { Metadata } from "next";
import { CashierConsole } from "@/features/cashier/cashier-console";

export const metadata: Metadata = { title: "Cashier · ShopXY" };

export default function CashierPage() {
  return <CashierConsole />;
}
