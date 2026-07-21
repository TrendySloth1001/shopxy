"use client";

import { useState, useEffect } from "react";
import { Heart } from "@/shared/icons";
import { useRouter } from "next/navigation";
import { useAuth } from "@/features/auth/auth-context";
import { toggleWishlist, getWishlistIds } from "../api";

interface Props {
  productId: number;
}

export function PdpWishlistButton({ productId }: Props) {
  const { status } = useAuth();
  const router = useRouter();
  const [wishlisted, setWishlisted] = useState(false);
  const [busy, setBusy] = useState(false);

  // Load initial wishlist state when authed
  useEffect(() => {
    if (status !== "authed") return;
    void getWishlistIds().then((ids) => {
      if (ids != null) setWishlisted(ids.has(productId));
    });
  }, [status, productId]);

  const handleToggle = async () => {
    if (busy) return;
    if (status !== "authed") {
      router.push(`/login?next=/p/${productId}`);
      return;
    }
    setBusy(true);
    const nextState = !wishlisted;
    setWishlisted(nextState); // optimistic
    try {
      await toggleWishlist(productId, nextState);
    } catch {
      setWishlisted(!nextState); // revert
    } finally {
      setBusy(false);
    }
  };

  return (
    <button
      onClick={handleToggle}
      aria-label={wishlisted ? "Remove from wishlist" : "Add to wishlist"}
      disabled={busy}
      className="flex size-9 items-center justify-center rounded-full bg-white/90 shadow-floating transition-colors hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-50"
    >
      <Heart
        size={18}
        aria-hidden
        className={wishlisted ? "fill-error text-error" : "text-ink"}
      />
    </button>
  );
}
