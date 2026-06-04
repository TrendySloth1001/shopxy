import Image from "next/image";

/** Resolve a stored relative image URL (`/images/...`) to the media proxy. */
export function mediaSrc(url?: string | null): string | null {
  if (!url) return null;
  return url.startsWith("/images/") ? `/api/media${url}` : url;
}

function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean).slice(0, 2);
  const letters = parts.map((p) => p[0]?.toUpperCase() ?? "").join("");
  return letters || "?";
}

/**
 * Round avatar. Shows the profile photo when set, otherwise a brand-tinted
 * initials puck. Photos are already resized WebP, so we skip the optimizer.
 */
export function Avatar({
  url,
  name,
  size = 56,
}: {
  url?: string | null;
  name: string;
  size?: number;
}) {
  const src = mediaSrc(url);
  if (src) {
    return (
      <Image
        src={src}
        alt={name}
        width={size}
        height={size}
        unoptimized
        className="rounded-full border border-hairline object-cover"
        style={{ width: size, height: size }}
      />
    );
  }
  return (
    <span
      aria-hidden
      className="flex shrink-0 items-center justify-center rounded-full bg-brand-soft text-label-md text-brand-strong"
      style={{ width: size, height: size }}
    >
      {initialsOf(name)}
    </span>
  );
}
