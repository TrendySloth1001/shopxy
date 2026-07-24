"use client";

import { use, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { getProduct } from "@/features/products/api";
import type { Product } from "@/features/products/schema";
import { ProductForm } from "@/features/products/components/product-form";
import { FormSkeleton } from "@/shared/ui/skeleton";

export default function EditProductPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const t = useTranslations("products");
  const [product, setProduct] = useState<Product | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const p = await getProduct(id);
        if (active) setProduct(p);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("detail.loadError"));
      }
    })();
    return () => {
      active = false;
    };
  }, [id, t]);

  if (error) {
    return <div className="px-lg py-xxl md:px-xxl"><p className="text-body-md text-muted">{error}</p></div>;
  }
  if (!product) {
    return <FormSkeleton />;
  }
  return <ProductForm product={product} />;
}
