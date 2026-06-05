"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { PromotionEditor } from "@/features/promotions/promotion-editor";
import { getPromotion } from "@/features/promotions/api";
import type { Promotion } from "@/features/promotions/schema";

export default function EditPromotionPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const [promo, setPromo] = useState<Promotion | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const p = await getPromotion(id);
        if (active) setPromo(p);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the promotion.");
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  if (error) return <p className="w-full px-lg py-xxl text-body-sm text-error md:px-xxl">{error}</p>;
  if (!promo) return <p className="w-full px-lg py-xxl text-body-sm text-subtle md:px-xxl">Loading…</p>;

  return <PromotionEditor existing={promo} />;
}
