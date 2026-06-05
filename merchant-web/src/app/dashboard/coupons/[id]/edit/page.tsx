"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { CouponEditor } from "@/features/coupons/coupon-editor";
import { getCoupon } from "@/features/coupons/api";
import type { Coupon } from "@/features/coupons/schema";

export default function EditCouponPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const [coupon, setCoupon] = useState<Coupon | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const c = await getCoupon(id);
        if (active) setCoupon(c);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the coupon.");
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  if (error) return <p className="w-full px-lg py-xxl text-body-sm text-error md:px-xxl">{error}</p>;
  if (!coupon) return <p className="w-full px-lg py-xxl text-body-sm text-subtle md:px-xxl">Loading…</p>;

  return <CouponEditor existing={coupon} />;
}
