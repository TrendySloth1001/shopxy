"use client";

import { Check } from "lucide-react";
import { useTheme } from "./theme-context";
import { THEME_META, THEMES, type Theme } from "./theme";

/** A single selectable theme tile: a mini window preview + label + radio role. */
function ThemeOption({
  value,
  selected,
  onSelect,
}: {
  value: Theme;
  selected: boolean;
  onSelect: (theme: Theme) => void;
}) {
  const meta = THEME_META[value];
  return (
    <button
      type="button"
      role="radio"
      aria-checked={selected}
      onClick={() => onSelect(value)}
      className={`group flex h-full flex-col gap-md rounded-lg border p-md text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
        selected
          ? "border-brand ring-2 ring-brand-soft"
          : "border-hairline hover:border-brand-soft hover:bg-surface-tint"
      }`}
    >
      {/* Mini window preview — fixed palette of the theme it represents. */}
      <span
        className="flex h-16 w-full items-end gap-xs overflow-hidden rounded-md border border-hairline p-sm"
        style={{ backgroundColor: meta.swatch.canvas }}
      >
        <span
          className="h-full flex-1 rounded-sm"
          style={{ backgroundColor: meta.swatch.surface }}
        />
        <span className="flex h-full flex-[2] flex-col justify-end gap-xs">
          <span
            className="h-1.5 w-3/4 rounded-full"
            style={{ backgroundColor: meta.swatch.ink, opacity: 0.85 }}
          />
          <span
            className="h-1.5 w-1/2 rounded-full"
            style={{ backgroundColor: meta.swatch.ink, opacity: 0.45 }}
          />
        </span>
      </span>

      <span className="flex items-center justify-between gap-sm">
        <span className="text-body-md text-ink">{meta.label}</span>
        <span
          className={`flex size-5 shrink-0 items-center justify-center rounded-full transition-colors ${
            selected ? "bg-brand text-white" : "border border-hairline text-transparent"
          }`}
          aria-hidden
        >
          <Check size={12} strokeWidth={3} />
        </span>
      </span>
      <span className="text-body-sm text-muted">{meta.description}</span>
    </button>
  );
}

/**
 * Theme picker for the settings → Preferences pane. Light, Dark and OLED, where
 * the two dark variants share a palette (OLED only deepens the blacks). Applies
 * instantly and persists across reloads via the ThemeProvider.
 */
export function ThemePicker() {
  const { theme, setTheme } = useTheme();
  return (
    <div
      role="radiogroup"
      aria-label="App theme"
      className="grid grid-cols-1 gap-md sm:grid-cols-2 xl:grid-cols-3"
    >
      {THEMES.map((value) => (
        <ThemeOption
          key={value}
          value={value}
          selected={theme === value}
          onSelect={setTheme}
        />
      ))}
    </div>
  );
}
