/**
 * Single source of truth for icons in customer-web.
 *
 * Every component imports icons from `@/shared/icons` — never from an icon
 * library directly, and never by hand-writing an inline `<svg>`. That keeps the
 * icon set enumerable in one place: the underlying library and any custom
 * glyphs all funnel through here, so swapping the library or adding a custom
 * icon is a one-file change.
 *
 * Underlying set: Hugeicons (`@hugeicons/react` + `@hugeicons/core-free-icons`),
 * fronted by thin wrapper components in `./lucide-compat` that keep the icon
 * names the app already uses. The barrel is registered in `next.config.ts`
 * under `experimental.optimizePackageImports` so only named icons are bundled.
 *
 * - Generic UI icons: Hugeicons wrappers (`./lucide-compat`).
 * - Custom glyphs the set can't provide: local components (e.g. StarSolidIcon).
 */

// Generic UI glyph set — Hugeicons wrappers keyed by the app's icon names.
export * from "./lucide-compat";

// Custom glyphs (not available in the icon set as-is).
export { StarSolidIcon } from "./star-solid-icon";
