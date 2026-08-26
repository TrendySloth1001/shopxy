"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { ChevronRight, X } from "@/shared/icons";
import { useAuth } from "../auth-context";
import {
  forgetAccount,
  listRememberedAccounts,
  resumeAccount,
  type DesktopAccount,
} from "../desktop";
import { AuthErrorBanner } from "./auth-shell";

export function RememberedAccounts() {
  const router = useRouter();
  const { refresh } = useAuth();
  const t = useTranslations("auth");
  const [accounts, setAccounts] = useState<DesktopAccount[] | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void listRememberedAccounts().then((a) => {
      if (active) setAccounts(a);
    });
    return () => {
      active = false;
    };
  }, []);

  if (!accounts || accounts.length === 0) return null;

  const resume = async (id: string) => {
    setBusyId(id);
    setError(null);
    const r = await resumeAccount(id);
    if (r.ok) {
      await refresh();
      router.replace("/dashboard");
      return;
    }
    setError(r.error ?? t("remembered.resumeFailed"));
    if (r.removed) setAccounts((prev) => prev?.filter((a) => a.id !== id) ?? null);
    setBusyId(null);
  };

  const forget = async (id: string) => {
    await forgetAccount(id);
    setAccounts((prev) => prev?.filter((a) => a.id !== id) ?? null);
  };

  return (
    <div className="mb-xl flex flex-col gap-sm">
      <p className="text-label-md text-muted">{t("remembered.continueAs")}</p>
      {error ? <AuthErrorBanner message={error} /> : null}
      <ul className="flex flex-col gap-sm">
        {accounts.map((a) => (
          <li
            key={a.id}
            className="flex items-center gap-sm rounded-button border border-hairline pr-sm transition-colors hover:border-brand"
          >
            <button
              type="button"
              disabled={busyId != null}
              onClick={() => void resume(a.id)}
              className="flex min-w-0 flex-1 items-center gap-md rounded-button p-sm text-left disabled:opacity-60"
            >
              <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-surface-tint text-label-md font-semibold text-brand-strong">
                {initials(a.name || a.email)}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-body-md text-ink">{a.name}</span>
                <span className="block truncate text-body-sm text-muted">{a.email}</span>
              </span>
              {busyId === a.id ? (
                <span className="text-body-sm text-muted">{t("remembered.signingIn")}</span>
              ) : (
                <ChevronRight size={18} className="shrink-0 text-subtle" />
              )}
            </button>
            <button
              type="button"
              onClick={() => void forget(a.id)}
              title={t("remembered.removeTitle")}
              aria-label={t("remembered.removeAria", { email: a.email })}
              className="shrink-0 rounded-button p-xs text-muted transition-colors hover:text-error"
            >
              <X size={16} />
            </button>
          </li>
        ))}
      </ul>
      <div className="mt-sm flex items-center gap-md text-label-sm text-subtle">
        <span className="h-px flex-1 bg-hairline" />
        {t("remembered.orSignIn")}
        <span className="h-px flex-1 bg-hairline" />
      </div>
    </div>
  );
}

function initials(s: string): string {
  const parts = s.trim().split(/\s+/);
  const first = parts[0]?.[0] ?? "";
  const second = parts.length > 1 ? (parts[parts.length - 1][0] ?? "") : "";
  return (first + second).toUpperCase() || "?";
}
