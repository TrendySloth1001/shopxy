"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { VendorEditor } from "@/features/vendors/vendor-editor";
import { getVendor } from "@/features/vendors/api";
import type { Vendor } from "@/features/vendors/schema";

export default function EditVendorPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const [vendor, setVendor] = useState<Vendor | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const v = await getVendor(id);
        if (active) setVendor(v);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the vendor.");
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  if (error) return <p className="w-full px-lg py-xxl text-body-sm text-error md:px-xxl">{error}</p>;
  if (!vendor) return <p className="w-full px-lg py-xxl text-body-sm text-subtle md:px-xxl">Loading…</p>;

  return <VendorEditor existing={vendor} />;
}
