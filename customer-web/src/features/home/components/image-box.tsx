"use client";

import { useEffect, useRef, useState } from "react";
import { ImageOff } from "@/shared/icons";
import { color } from "@/shared/ui/tokens";
import { resolveImageUrl } from "../format";

/**
 * Resilient image loader — port of the Flutter `NetworkImageBox`. Shows a
 * shimmer skeleton while loading (uses .shimmer utility from globals.css),
 * fades the image in on load, and shows a placeholder on error.
 *
 * Cached-image trap handled: if img.complete is already true on mount we skip
 * the onLoad listener and set loaded=true immediately so the image is never
 * hidden behind the shimmer.
 *
 * Relative backend paths are routed through the media proxy so the server-only
 * API base never reaches the client.
 */
export function ImageBox({
  url,
  alt = "",
  fit = "cover",
  placeholderColor = color.surface.heroPanel,
  className = "",
}: {
  url?: string | null;
  alt?: string;
  fit?: "cover" | "contain";
  placeholderColor?: string;
  className?: string;
}) {
  const resolved = resolveImageUrl(url);
  const [errored, setErrored] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);

  // Handle the cached-image case: if the browser already decoded the image
  // (img.complete === true) the onLoad event will never fire. Check on mount.
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
      {/* Shimmer skeleton — visible until image loads or errors */}
      {resolved && !errored && !loaded ? (
        <span className="shimmer absolute inset-0" aria-hidden />
      ) : null}

      {resolved && !errored ? (
        // eslint-disable-next-line @next/next/no-img-element -- same-origin media proxy; next/image remote config not wired
        <img
          ref={imgRef}
          src={resolved}
          alt={alt}
          loading="lazy"
          decoding="async"
          onLoad={() => setLoaded(true)}
          onError={() => {
            if (imgRef.current) imgRef.current.dataset.errored = "1";
            setErrored(true);
          }}
          className="size-full transition-opacity duration-300"
          style={{
            objectFit: fit,
            opacity: loaded ? 1 : 0,
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
