"use client";

/**
 * Hook: manages recent search history in localStorage (max 8 terms, newest
 * first). SSR-safe — uses useSyncExternalStore so the server snapshot is
 * stable and the client hydrates without a setState-in-effect call.
 */

import { useCallback, useSyncExternalStore } from "react";

const KEY = "sx_recent_searches";
const MAX = 8;

// ── Storage helpers ───────────────────────────────────────────────────────────

function readStorage(): string[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return (parsed as unknown[]).filter((v): v is string => typeof v === "string");
  } catch {
    return [];
  }
}

function writeStorage(terms: string[]) {
  try {
    localStorage.setItem(KEY, JSON.stringify(terms));
    // Notify all subscribed hooks in this tab.
    window.dispatchEvent(new Event("sx-recent-searches"));
  } catch {
    /* quota exceeded or private mode — ignore */
  }
}

// ── useSyncExternalStore subscription ────────────────────────────────────────

function subscribe(callback: () => void): () => void {
  window.addEventListener("sx-recent-searches", callback);
  // Also sync if another tab writes to storage (cross-tab).
  window.addEventListener("storage", callback);
  return () => {
    window.removeEventListener("sx-recent-searches", callback);
    window.removeEventListener("storage", callback);
  };
}

// ── Hook ─────────────────────────────────────────────────────────────────────

export function useRecentSearches() {
  // getSnapshot reads live storage; getServerSnapshot returns empty (no localStorage on server).
  const recent = useSyncExternalStore(subscribe, readStorage, () => []);

  const add = useCallback((term: string) => {
    const t = term.trim();
    if (!t) return;
    const prev = readStorage();
    const next = [t, ...prev.filter((s) => s !== t)].slice(0, MAX);
    writeStorage(next);
  }, []);

  const clear = useCallback(() => {
    writeStorage([]);
  }, []);

  return { recent, add, clear };
}
