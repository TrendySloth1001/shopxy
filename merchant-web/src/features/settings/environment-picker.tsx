"use client";

import { useCallback, useEffect, useState } from "react";
import { Check, TriangleAlert } from "@/shared/icons";

/**
 * Developer-only backend switcher — the web half of the Flutter merchant
 * app's Settings → Environment screen.
 *
 * Visibility is inferred from the server, not decided here: `GET
 * /api/dev/environment` answers 404 for everyone but the developer account,
 * so the gate lives in one place and the developer's address never ships in
 * this bundle. Options carry no URLs either — `API_BASE_URL` stays server-only
 * (see `shared/config/env.ts`).
 *
 * Strings are intentionally not localised: the screen is gated to a single
 * hardcoded developer account, so a Hindi translation of "Dev tunnel" would be
 * shipped weight nobody can ever read.
 */

type EnvOption = { id: string; label: string; description: string };
type EnvState = { options: EnvOption[]; currentId: string | null; isDefault: boolean };

/**
 * Loads the switcher's state. `available` stays false for non-developers (the
 * endpoint 404s) and while the first request is in flight, so the settings
 * rail never flashes a section the account can't use.
 */
export function useDeveloperEnvironments() {
  const [state, setState] = useState<EnvState | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetch("/api/dev/environment")
      .then((res) => (res.ok ? (res.json() as Promise<EnvState>) : null))
      .then((data) => {
        if (!cancelled && data) setState(data);
      })
      .catch(() => {
        // Not a developer, or the endpoint is unreachable — either way the
        // section simply doesn't exist for this session.
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return { available: state !== null, state };
}

export function EnvironmentPicker({ state }: { state: EnvState }) {
  const [switching, setSwitching] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const select = useCallback(
    async (option: EnvOption) => {
      if (switching) return;
      const ok = window.confirm(
        `Switch to ${option.label}?\n\n` +
          "You will be signed out and the page will reload. " +
          `${option.label} has its own database, so nothing from the current ` +
          "environment carries over.",
      );
      if (!ok) return;

      setSwitching(option.id);
      setError(null);
      try {
        const res = await fetch("/api/dev/environment", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ id: option.id }),
        });
        if (!res.ok) throw new Error("Switch failed");
        // A hard navigation, not router.push: every cached RSC payload on this
        // page was rendered against the previous database.
        window.location.href = "/login";
      } catch {
        setSwitching(null);
        setError("Could not switch environments. Check the server logs.");
      }
    },
    [switching],
  );

  return (
    <div className="space-y-lg">
      <div className="flex items-start gap-sm rounded-lg bg-info-soft p-md">
        <TriangleAlert size={18} className="mt-px shrink-0 text-info" />
        <p className="text-body-sm text-ink">
          Each backend has its own database. Switching signs you out and
          reloads the page so nothing from the current environment is left on
          screen.
        </p>
      </div>

      <div
        role="radiogroup"
        aria-label="Backend environment"
        className="grid grid-cols-1 gap-md sm:grid-cols-2 xl:grid-cols-3"
      >
        {state.options.map((option) => {
          const selected = option.id === state.currentId;
          const busy = switching === option.id;
          return (
            <button
              key={option.id}
              type="button"
              role="radio"
              aria-checked={selected}
              disabled={selected || switching !== null}
              onClick={() => select(option)}
              className={`flex h-full flex-col gap-xs rounded-lg border p-md text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:cursor-default ${
                selected
                  ? "border-brand ring-2 ring-brand-soft"
                  : "border-hairline hover:border-brand-soft hover:bg-surface-tint disabled:opacity-60 disabled:hover:border-hairline disabled:hover:bg-transparent"
              }`}
            >
              <span className="flex items-center justify-between gap-sm">
                <span className="text-body-md text-ink">{option.label}</span>
                <span
                  className={`flex size-5 shrink-0 items-center justify-center rounded-full transition-colors ${
                    selected
                      ? "bg-brand text-white"
                      : "border border-hairline text-transparent"
                  }`}
                  aria-hidden
                >
                  <Check size={12} strokeWidth={3} />
                </span>
              </span>
              <span className="text-body-sm text-muted">
                {busy ? "Signing out…" : option.description}
              </span>
            </button>
          );
        })}
      </div>

      {state.currentId === null ? (
        <p className="text-body-sm text-muted">
          This deployment&apos;s configured backend is not one of the entries
          above, so none is marked selected.
        </p>
      ) : null}

      {error ? <p className="text-body-sm text-error">{error}</p> : null}
    </div>
  );
}
