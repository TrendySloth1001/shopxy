"use client";

import { use, useEffect, useState } from "react";
import { BannerEditor } from "@/features/banners/banner-editor";
import { getBanner } from "@/features/banners/api";
import type { Banner } from "@/features/banners/schema";
import { BackLink } from "@/shared/ui/page-header";

export default function EditBannerPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [banner, setBanner] = useState<Banner | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void getBanner(Number(id))
      .then((b) => active && setBanner(b))
      .catch((e) => active && setError(e instanceof Error ? e.message : "Could not load the banner."));
    return () => {
      active = false;
    };
  }, [id]);

  if (error) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href="/dashboard/banners" label="Banners" />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      </div>
    );
  }
  if (!banner) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href="/dashboard/banners" label="Banners" />
        <p className="mt-md text-body-md text-muted">Loading…</p>
      </div>
    );
  }
  return <BannerEditor banner={banner} />;
}
