"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { FlashDealEditor } from "@/features/flash-deals/flash-deal-editor";
import { getFlashDeal } from "@/features/flash-deals/api";
import type { FlashSale } from "@/features/flash-deals/schema";
import { FormSkeleton } from "@/shared/ui/skeleton";

export default function EditFlashDealPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const [deal, setDeal] = useState<FlashSale | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const d = await getFlashDeal(id);
        if (active) setDeal(d);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the flash deal.");
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  if (error) return <p className="w-full px-lg py-xxl text-body-sm text-error md:px-xxl">{error}</p>;
  if (!deal) return <FormSkeleton />;

  return <FlashDealEditor existing={deal} />;
}
