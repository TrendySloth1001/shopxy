export const THEMES = [
  "light",
  "beige",
  "rose",
  "sage",
  "dark",
  "oled",
  "midnight",
  "nord",
] as const;

export type Theme = (typeof THEMES)[number];

export const LIGHT_THEMES: readonly Theme[] = ["light", "beige", "rose", "sage"];

export const THEME_STORAGE_KEY = "shopxy-theme";

export function isTheme(value: unknown): value is Theme {
  return (
    typeof value === "string" && (THEMES as readonly string[]).includes(value)
  );
}

export function colorSchemeFor(theme: Theme): "light" | "dark" {
  return (LIGHT_THEMES as readonly string[]).includes(theme) ? "light" : "dark";
}

export function applyTheme(theme: Theme): void {
  if (typeof document === "undefined") return;
  const el = document.documentElement;
  el.dataset.theme = theme;
  el.style.colorScheme = colorSchemeFor(theme);
}

export function readAppliedTheme(): Theme {
  if (typeof document === "undefined") return "light";
  const d = document.documentElement.dataset.theme;
  return isTheme(d) ? d : "light";
}

export const THEME_INIT_SCRIPT = `(function(){try{var v=${JSON.stringify(
  THEMES,
)};var l=${JSON.stringify(
  LIGHT_THEMES,
)};var t=localStorage.getItem(${JSON.stringify(
  THEME_STORAGE_KEY,
)});if(v.indexOf(t)<0)t="light";var e=document.documentElement;e.dataset.theme=t;e.style.colorScheme=(l.indexOf(t)>=0)?"light":"dark";}catch(e){}})();`;

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
  beige: {
    label: "Beige",
    description: "Soft sepia paper — warm, low glare.",
    swatch: { canvas: "#ece3d1", surface: "#f8f2e6", ink: "#241f16" },
  },
  rose: {
    label: "Rose",
    description: "Warm blush — soft and easy on the eye.",
    swatch: { canvas: "#fbf0f2", surface: "#fff7f9", ink: "#3a2530" },
  },
  sage: {
    label: "Sage",
    description: "Cool mint-green — calm and quiet.",
    swatch: { canvas: "#eaf1ea", surface: "#f5faf5", ink: "#1c2b23" },
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
  midnight: {
    label: "Midnight",
    description: "Deep navy — indigo-tinted dark.",
    swatch: { canvas: "#0d1220", surface: "#141b30", ink: "#e6e9f2" },
  },
  nord: {
    label: "Nord",
    description: "Muted arctic blue-grey — soft dark.",
    swatch: { canvas: "#2e3440", surface: "#3b4252", ink: "#e5e9f0" },
  },
};
