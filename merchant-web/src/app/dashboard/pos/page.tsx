import type { Metadata } from "next";
import { PosTillView } from "@/features/pos/pos-till-view";

export const metadata: Metadata = { title: "Point of sale · ShopXY" };

export default function PosPage() {
  return <PosTillView />;
}
