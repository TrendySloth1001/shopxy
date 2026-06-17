import type { Metadata } from "next";
import { ScanConsoleView } from "@/features/scan-console/scan-console-view";

export const metadata: Metadata = { title: "Scan console · ShopXY" };

export default function ScanConsolePage() {
  return <ScanConsoleView />;
}
