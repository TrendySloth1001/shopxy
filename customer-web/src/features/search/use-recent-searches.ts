"use client";

import { useCallback, useSyncExternalStore } from "react";

const KEY = "sx_recent_searches";
const MAX = 8;

const EMPTY: string[] = [];
let cachedRaw: string | null = null;
let cachedParsed: string[] = EMPTY;

function readStorage(): string[] {
  let raw: string | null = null;
  try {
    raw = localStorage.getItem(KEY);
  } catch {
    return EMPTY;
  }
  if (raw === cachedRaw) return cachedParsed;
  cachedRaw = raw;
  if (!raw) {
    cachedParsed = EMPTY;
    return cachedParsed;
  }
  try {
    const parsed = JSON.parse(raw) as unknown;
    cachedParsed = Array.isArray(parsed)
      ? (parsed as unknown[]).filter((v): v is string => typeof v === "string")
      : EMPTY;
  } catch {
    cachedParsed = EMPTY;
  }
  return cachedParsed;
}

function writeStorage(terms: string[]) {
  try {
    localStorage.setItem(KEY, JSON.stringify(terms));
    window.dispatchEvent(new Event("sx-recent-searches"));
  } catch {
  }
}

function subscribe(callback: () => void): () => void {
  window.addEventListener("sx-recent-searches", callback);
  window.addEventListener("storage", callback);
  return () => {
    window.removeEventListener("sx-recent-searches", callback);
    window.removeEventListener("storage", callback);
  };
}

export function useRecentSearches() {
  const recent = useSyncExternalStore(subscribe, readStorage, () => EMPTY);

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
