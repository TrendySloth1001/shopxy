"use client";

export type DesktopAccount = {
  id: string;
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
  resumeAccount: (id: string) => Promise<ResumeResult>;
  forgetAccount: (id: string) => Promise<{ ok: boolean }>;
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

export async function rememberCurrentAccount(): Promise<void> {
  const b = bridge();
  if (!b) return;
  try {
    await b.rememberCurrentAccount();
  } catch {
  }
}

export async function resumeAccount(id: string): Promise<ResumeResult> {
  const b = bridge();
  if (!b) return { ok: false, error: "Not available." };
  return b.resumeAccount(id);
}

export async function forgetAccount(id: string): Promise<void> {
  const b = bridge();
  if (!b) return;
  try {
    await b.forgetAccount(id);
  } catch {
  }
}

export async function setDesktopTheme(theme: string): Promise<void> {
  const b = bridge();
  if (!b?.setTheme) return;
  try {
    await b.setTheme(theme);
  } catch {
  }
}
