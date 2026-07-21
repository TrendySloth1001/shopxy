/**
 * Single source of truth for icons in merchant-web.
 *
 * Every component imports icons from `@/shared/icons` — never from an icon
 * library directly, and never by hand-writing an inline `<svg>`. That keeps the
 * icon set enumerable in one place: the underlying library, the custom brand
 * marks, and domain icon registries all funnel through here, so swapping the
 * library or adding a custom glyph is a one-file change.
 *
 * Underlying set: Hugeicons (`@hugeicons/react` + `@hugeicons/core-free-icons`),
 * fronted by thin wrapper components in `./lucide-compat` that keep the icon
 * names the app already uses. The barrel is registered in `next.config.ts`
 * under `experimental.optimizePackageImports` so only named icons are bundled.
 *
 * - Generic UI icons: Hugeicons wrappers (`./lucide-compat`).
 * - Brand marks the set can't provide: local components (e.g. GoogleIcon).
 * - Domain registries: string-keyed icon maps (e.g. category icons).
 */

// Generic UI glyph set — Hugeicons wrappers keyed by the app's icon names.
export * from "./lucide-compat";

// Custom brand marks (not available in the icon set).
export { GoogleIcon } from "./google-icon";

// Category icon registry: maps a stored `iconName` string to an icon component.
export { CategoryIcon } from "./category-icon";
export {
  type CategoryIconOption,
  CATEGORY_ICON_OPTIONS,
  resolveCategoryIcon,
} from "./category-icons";
