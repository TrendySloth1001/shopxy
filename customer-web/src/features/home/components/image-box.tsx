"use client";

import { useState } from "react";
import { ImageOff } from "lucide-react";
import { color } from "@/shared/ui/tokens";
import { resolveImageUrl } from "../format";

/**
 * Resilient image loader — port of the Flutter `NetworkImageBox`. Shows a solid
 * placeholder colour while loading / when the URL is empty, and an icon on
 * error. Relative backend paths are routed through the media proxy so the
 * server-only API base never reaches the client.
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

  return (
    <span
      className={`relative block size-full overflow-hidden ${className}`}
      style={{ backgroundColor: placeholderColor }}
    >
      {resolved && !errored ? (
        // eslint-disable-next-line @next/next/no-img-element -- same-origin media proxy; next/image remote config not wired
        <img
          src={resolved}
          alt={alt}
          loading="lazy"
          decoding="async"
          onError={() => setErrored(true)}
          className="size-full"
          style={{ objectFit: fit }}
        />
      ) : errored ? (
        <span className="flex size-full items-center justify-center">
          <ImageOff size={28} style={{ color: color.ink.disabled }} aria-hidden />
        </span>
      ) : null}
    </span>
  );
}
