"use client";

import { useEffect, useRef, useState } from "react";
import { ImageOff } from "@/shared/icons";
import { color } from "@/shared/ui/tokens";
import { resolveImageUrl } from "../format";

export function ImageBox({
  url,
  alt = "",
  fit = "cover",
  placeholderColor = color.surface.heroPanel,
  className = "",
  priority = false,
}: {
  url?: string | null;
  alt?: string;
  fit?: "cover" | "contain";
  placeholderColor?: string;
  className?: string;
  priority?: boolean;
}) {
  const resolved = resolveImageUrl(url);
  const [errored, setErrored] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    const img = imgRef.current;
    if (img && img.complete && !img.dataset.errored) {
      setLoaded(true);
    }
  }, [resolved]);

  return (
    <span
      className={`relative block size-full overflow-hidden ${className}`}
      style={{ backgroundColor: placeholderColor }}
    >
      {resolved && !errored && !loaded ? (
        <span className="shimmer absolute inset-0" aria-hidden />
      ) : null}

      {resolved && !errored ? (
        // eslint-disable-next-line @next/next/no-img-element -- same-origin media proxy; next/image remote config not wired
        <img
          ref={imgRef}
          src={resolved}
          alt={alt}
          loading={priority ? "eager" : "lazy"}
          fetchPriority={priority ? "high" : undefined}
          decoding="async"
          onLoad={() => setLoaded(true)}
          onError={() => {
            if (imgRef.current) imgRef.current.dataset.errored = "1";
            setErrored(true);
          }}
          className={priority ? "size-full" : "size-full transition-opacity duration-300"}
          style={{
            objectFit: fit,
            opacity: priority || loaded ? 1 : 0,
          }}
        />
      ) : errored ? (
        <span className="flex size-full items-center justify-center">
          <ImageOff size={28} style={{ color: color.ink.disabled }} aria-hidden />
        </span>
      ) : null}
    </span>
  );
}
