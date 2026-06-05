/**
 * Client mirror of the backend `cta-target` DSL (banners / spotlight CTAs).
 * The wire format is `<kind>:<value>` — `category:<slug>`, `product:<id>`,
 * `collection:<slug>`, `url:https://…`. We validate the same shapes here so
 * the merchant doesn't round-trip to the server to learn a value is malformed.
 * The backend remains the validation authority on write.
 */

export type CtaKind = "none" | "category" | "product" | "collection" | "url";

export const CTA_KIND_OPTIONS: ReadonlyArray<{ value: CtaKind; label: string }> = [
  { value: "none", label: "No action" },
  { value: "category", label: "Open category" },
  { value: "product", label: "Open product" },
  { value: "collection", label: "Open collection" },
  { value: "url", label: "External URL" },
];

export function ctaHint(kind: CtaKind): string {
  switch (kind) {
    case "none":
      return "Tapping the slide does nothing.";
    case "category":
      return 'Category slug, e.g. "kurta-sets".';
    case "product":
      return "Numeric product id.";
    case "collection":
      return 'Collection slug, e.g. "festive-edit".';
    case "url":
      return "Full https:// URL.";
  }
}

/** Split a stored target back into {kind, value} for editing. */
export function parseCtaTarget(target?: string | null): { kind: CtaKind; value: string } {
  if (!target) return { kind: "none", value: "" };
  const idx = target.indexOf(":");
  if (idx <= 0) return { kind: "none", value: "" };
  const kind = target.slice(0, idx);
  const value = target.slice(idx + 1);
  if (kind === "category" || kind === "product" || kind === "collection") {
    return { kind, value };
  }
  if (kind === "url") return { kind: "url", value };
  return { kind: "none", value: "" };
}

/** Build + validate. Returns `{ target }` (null target = no CTA) or `{ error }`. */
export function buildCtaTarget(
  kind: CtaKind,
  rawValue: string,
): { target: string | null; error: null } | { target: null; error: string } {
  if (kind === "none") return { target: null, error: null };
  const value = rawValue.trim();
  if (!value) return { target: null, error: "Enter the CTA target value." };
  switch (kind) {
    case "category":
    case "collection":
      if (!/^[a-z0-9-]{1,80}$/.test(value)) {
        return { target: null, error: "Lowercase letters, digits and hyphens only." };
      }
      return { target: `${kind}:${value}`, error: null };
    case "product":
      if (!/^[0-9]{1,18}$/.test(value)) {
        return { target: null, error: "A numeric product id is required." };
      }
      return { target: `product:${value}`, error: null };
    case "url":
      try {
        const u = new URL(value);
        if (u.protocol !== "http:" && u.protocol !== "https:") {
          return { target: null, error: "Must be an http(s):// URL." };
        }
      } catch {
        return { target: null, error: "Must be a full http(s):// URL." };
      }
      return { target: `url:${value}`, error: null };
  }
}
