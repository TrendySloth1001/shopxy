/**
 * Single source of truth for icons in merchant-web.
 *
 * Every component imports icons from `@/shared/icons` — never from
 * `lucide-react` directly, and never by hand-writing an inline `<svg>`. That
 * keeps the icon set enumerable in one place: the underlying library, the
 * custom brand marks, and domain icon registries all funnel through here, so
 * swapping the library or adding a custom glyph is a one-file change.
 *
 * This barrel is registered in `next.config.ts` under
 * `experimental.optimizePackageImports`, so re-exporting the whole lucide set
 * stays fully tree-shaken (only the icons a page actually names are bundled).
 *
 * - Generic UI icons: re-exported from `lucide-react` (the house icon library).
 * - Brand marks that lucide can't provide: local components (e.g. GoogleIcon).
 * - Domain registries: string-keyed icon maps (e.g. category icons).
 */

// House icon library — the generic UI glyph set.
export * from "lucide-react";

// Custom brand marks (not available in lucide).
export { GoogleIcon } from "./google-icon";

// Category icon registry: maps a stored `iconName` string to a lucide icon.
export { CategoryIcon } from "./category-icon";
export {
  type CategoryIconOption,
  CATEGORY_ICON_OPTIONS,
  resolveCategoryIcon,
} from "./category-icons";
