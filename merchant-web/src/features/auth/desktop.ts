"use client";

/**
 * Thin, safe wrapper over the Electron preload bridge (`window.shopxyDesktop`).
 * On the browser web build the bridge is absent, so every call no-ops / returns
 * empty — the remembered-accounts feature is desktop-only by construction.
 * Tokens never cross this boundary: the main process holds them; we only ever
 * receive display profiles + ok/err.
 */
export type DesktopAccount = {
  id: number;
  name: string;
  email: string;
  avatarUrl: string | null;
};

type ResumeResult = { ok: boolean; error?: string; removed?: boolean };

type DesktopBridge = {
  isDesktop: boolean;
  platform: string;
  listRememberedAccounts: () => Promise<DesktopAccount[]>;
  rememberCurrentAccount: () => Promise<{ ok: boolean }>;
  resumeAccount: (id: number) => Promise<ResumeResult>;
  forgetAccount: (id: number) => Promise<{ ok: boolean }>;
  /** Persist the chosen theme so the native window background matches on the
   *  next cold start, and re-tint the live Electron chrome. Optional: older
   *  desktop builds won't expose it. */
  setTheme?: (theme: string) => Promise<{ ok: boolean }>;
};

function bridge(): DesktopBridge | null {
  if (typeof window === "undefined") return null;
  const b = (window as unknown as { shopxyDesktop?: DesktopBridge }).shopxyDesktop;
  return b && b.isDesktop ? b : null;
}

export const isDesktop = (): boolean => bridge() != null;

export async function listRememberedAccounts(): Promise<DesktopAccount[]> {
  const b = bridge();
  if (!b) return [];
  try {
    return await b.listRememberedAccounts();
  } catch {
    return [];
  }
}

/** Fire-and-forget: remember the just-signed-in account on this device. */
export async function rememberCurrentAccount(): Promise<void> {
  const b = bridge();
  if (!b) return;
  try {
    await b.rememberCurrentAccount();
  } catch {
    /* best effort — never block sign-in */
  }
}

export async function resumeAccount(id: number): Promise<ResumeResult> {
  const b = bridge();
  if (!b) return { ok: false, error: "Not available." };
  return b.resumeAccount(id);
}

export async function forgetAccount(id: number): Promise<void> {
  const b = bridge();
  if (!b) return;
  try {
    await b.forgetAccount(id);
  } catch {
    /* best effort */
  }
}

/** Tell the desktop shell about a theme change. No-op on the browser build and
 *  on older desktop builds that predate the bridge method. */
export async function setDesktopTheme(theme: string): Promise<void> {
  const b = bridge();
  if (!b?.setTheme) return;
  try {
    await b.setTheme(theme);
  } catch {
    /* best effort — the web layer already applied the theme. */
  }
}
