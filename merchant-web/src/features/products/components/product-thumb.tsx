import Image from "next/image";
import { Package } from "lucide-react";

/** Resolve a stored relative image URL (`/images/...`) to the media proxy. */
export function mediaSrc(url?: string | null): string | null {
  if (!url) return null;
  return url.startsWith("/images/") ? `/api/media${url}` : url;
}

/** Square product thumbnail with a tinted package fallback. */
export function ProductThumb({
  url,
  alt,
  size = 48,
}: {
  url?: string | null;
  alt: string;
  size?: number;
}) {
  const src = mediaSrc(url);
  if (src) {
    return (
      <Image
        src={src}
        alt={alt}
        width={size}
        height={size}
        unoptimized
        className="shrink-0 rounded-md border border-hairline object-cover"
        style={{ width: size, height: size }}
      />
    );
  }
  return (
    <span
      aria-hidden
      className="flex shrink-0 items-center justify-center rounded-md border border-hairline bg-surface-tint text-subtle"
      style={{ width: size, height: size }}
    >
      <Package size={Math.round(size * 0.45)} />
    </span>
  );
}
