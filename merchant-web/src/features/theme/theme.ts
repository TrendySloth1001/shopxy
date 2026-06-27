/**
 * Theme primitives shared by the no-flash boot script (imported into the server
 * `layout.tsx`) and the client `ThemeProvider`. Kept free of the `"use client"`
 * directive and of any React import so the server layout can pull the boot
 * script string without dragging client code into the server bundle.
 *
 * Three themes, selected via the `data-theme` attribute on <html>; the CSS in
 * `globals.css` re-assigns the colour tokens per attribute value.
 *
 *   • light — default warm-canvas look
 *   • dark  — normal dark: deep-slate canvas, raised surfaces
 *   • oled  — true-black canvas for OLED panels (shares the dark palette)
 */

export type Theme = "light" | "dark" | "oled";

/** Canonical order — also the order shown in the settings picker. */
export const THEMES: readonly Theme[] = ["light", "dark", "oled"] as const;

/** localStorage key holding the user's choice (read by the boot script). */
export const THEME_STORAGE_KEY = "shopxy-theme";

export function isTheme(value: unknown): value is Theme {
  return value === "light" || value === "dark" || value === "oled";
}

/** Native `color-scheme` for the theme — drives form controls + scrollbars. */
export function colorSchemeFor(theme: Theme): "light" | "dark" {
  return theme === "light" ? "light" : "dark";
}

/** Apply a theme to <html> immediately (attribute + native colour-scheme). */
export function applyTheme(theme: Theme): void {
  if (typeof document === "undefined") return;
  const el = document.documentElement;
  el.dataset.theme = theme;
  el.style.colorScheme = colorSchemeFor(theme);
}

/** Read the theme the boot script already committed to the DOM (fallback for
 *  the very first client render so React state matches what's painted). */
export function readAppliedTheme(): Theme {
  if (typeof document === "undefined") return "light";
  const d = document.documentElement.dataset.theme;
  return isTheme(d) ? d : "light";
}

/**
 * Inline boot script — runs in <head> before first paint so the stored theme is
 * on <html> before any pixels land (no light-mode flash for dark users). Inlined
 * verbatim via dangerouslySetInnerHTML; keep it tiny, dependency-free and
 * exception-safe (private-mode localStorage throws).
 */
export const THEME_INIT_SCRIPT = `(function(){try{var t=localStorage.getItem(${JSON.stringify(
  THEME_STORAGE_KEY,
)});if(t!=="light"&&t!=="dark"&&t!=="oled")t="light";var e=document.documentElement;e.dataset.theme=t;e.style.colorScheme=(t==="light")?"light":"dark";}catch(e){}})();`;

/**
 * Display copy + a literal swatch triple for the settings picker. The swatch
 * intentionally carries raw hex (canvas / raised surface / ink) because each
 * tile must preview a *fixed* theme regardless of the one currently active —
 * the one place token utilities can't express the value. Mirrors the palettes
 * in `globals.css`; keep them in sync.
 */
export const THEME_META: Record<
  Theme,
  {
    label: string;
    description: string;
    swatch: { canvas: string; surface: string; ink: string };
  }
> = {
  light: {
    label: "Light",
    description: "Warm canvas, dark text — the default.",
    swatch: { canvas: "#f8f7f3", surface: "#ffffff", ink: "#14181d" },
  },
  dark: {
    label: "Dark",
    description: "Deep slate surfaces, easy on the eyes.",
    swatch: { canvas: "#0f1419", surface: "#171d24", ink: "#e7eaee" },
  },
  oled: {
    label: "OLED",
    description: "True black — best for OLED displays.",
    swatch: { canvas: "#000000", surface: "#0c1014", ink: "#e7eaee" },
  },
};
