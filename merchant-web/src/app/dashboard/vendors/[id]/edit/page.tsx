"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { VendorEditor } from "@/features/vendors/vendor-editor";
import { getVendor } from "@/features/vendors/api";
import type { Vendor } from "@/features/vendors/schema";
import { FormSkeleton } from "@/shared/ui/skeleton";

export default function EditVendorPage() {
  const t = useTranslations("vendors");
  const params = useParams<{ id: string }>();
  const id = params.id;
  const [vendor, setVendor] = useState<Vendor | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const v = await getVendor(id);
        if (active) setVendor(v);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("detail.loadError"));
      }
    })();
    return () => {
      active = false;
    };
  }, [id, t]);

  if (error) return <p className="w-full px-lg py-xxl text-body-sm text-error md:px-xxl">{error}</p>;
  if (!vendor) return <FormSkeleton />;

  return <VendorEditor existing={vendor} />;
}
