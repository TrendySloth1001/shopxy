/**
 * Single source of truth for icons in customer-web.
 *
 * Every component imports icons from `@/shared/icons` — never from
 * `lucide-react` directly, and never by hand-writing an inline `<svg>`. That
 * keeps the icon set enumerable in one place: the underlying library and any
 * custom glyphs all funnel through here, so swapping the library or adding a
 * custom icon is a one-file change.
 *
 * This barrel is registered in `next.config.ts` under
 * `experimental.optimizePackageImports`, so re-exporting the whole lucide set
 * stays fully tree-shaken (only the icons a page actually names are bundled).
 *
 * - Generic UI icons: re-exported from `lucide-react` (the house icon library).
 * - Custom glyphs that lucide can't provide: local components (e.g. StarSolidIcon).
 */

// House icon library — the generic UI glyph set.
export * from "lucide-react";

// Custom glyphs (not available in lucide as-is).
export { StarSolidIcon } from "./star-solid-icon";
