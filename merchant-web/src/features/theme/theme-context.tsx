"use client";

import {
  createContext,
  useCallback,
  useContext,
  useState,
  type ReactNode,
} from "react";
import {
  applyTheme,
  readAppliedTheme,
  THEME_STORAGE_KEY,
  type Theme,
} from "./theme";
import { setDesktopTheme } from "@/features/auth/desktop";

type ThemeContextValue = {
  theme: Theme;
  setTheme: (theme: Theme) => void;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

/**
 * Provides the active theme + a setter. The boot script in `layout.tsx` has
 * already applied the stored theme to <html> before hydration, so the initial
 * state is read straight off the DOM — no effect, no flash, and React state
 * agrees with what's painted. Changing the theme re-applies it, persists to
 * localStorage (so the boot script restores it next load), and forwards it to
 * the Electron main process (so the desktop window's native background matches
 * on the next cold start).
 */
export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(readAppliedTheme);

  const setTheme = useCallback((next: Theme) => {
    setThemeState(next);
    applyTheme(next);
    try {
      localStorage.setItem(THEME_STORAGE_KEY, next);
    } catch {
      /* private mode — best effort; the in-session theme still applies. */
    }
    void setDesktopTheme(next);
  }, []);

  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within a ThemeProvider");
  return ctx;
}
