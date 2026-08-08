"use client";

import { useCallback, useEffect, useState } from "react";
import { AlertCircle, Check } from "@/shared/icons";

/**
 * Developer-only backend switcher — the customer-web mirror of merchant-web's
 * `features/settings/environment-picker.tsx`.
 *
 * Visibility is inferred from the server, not decided here: `GET
 * /api/dev/environment` answers 404 for everyone but the developer account,
 * so the gate lives in one place and the developer's address never ships in
 * this bundle. Options carry no URLs either — `API_BASE_URL` stays server-only
 * (see `shared/config/env.ts`).
 *
 * Strings are intentionally not localised: the screen is gated to a single
 * hardcoded developer account, so a translation of "Dev tunnel" would be
 * shipped weight nobody can ever read.
 */

type EnvOption = { id: string; label: string; description: string };
type EnvState = {
  options: EnvOption[];
  currentId: string | null;
  isDefault: boolean;
};

/**
 * Loads the switcher's state. `available` stays false for non-developers (the
 * endpoint 404s) and while the first request is in flight, so the account page
 * never flashes a section this account can't use.
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

/**
 * The picker, rendered only when {@link useDeveloperEnvironments} reports
 * `available`. Renders nothing otherwise, so the caller can drop it in
 * unconditionally.
 */
export function DeveloperEnvironmentSection() {
  const { available, state } = useDeveloperEnvironments();
  const [switching, setSwitching] = useState<string | null>(null);
  const [pending, setPending] = useState<EnvOption | null>(null);
  const [error, setError] = useState<string | null>(null);

  const confirmSwitch = useCallback(async () => {
    if (!pending || switching) return;
    setSwitching(pending.id);
    setError(null);
    try {
      const res = await fetch("/api/dev/environment", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: pending.id }),
      });
      if (!res.ok) throw new Error("Switch failed");
      // A hard navigation, not router.push: every cached RSC payload on this
      // page was rendered against the previous database.
      window.location.href = "/login";
    } catch {
      setSwitching(null);
      setPending(null);
      setError("Could not switch environments. Check the server logs.");
    }
  }, [pending, switching]);

  if (!available || !state) return null;

  return (
    <section className="mt-xxl">
      <h2 className="text-label-md uppercase tracking-wide text-subtle">
        Developer
      </h2>
      <p className="mt-xs text-body-sm text-muted">
        Point this browser at a different backend. Each one has its own
        database, so switching signs you out.
      </p>

      <div
        role="radiogroup"
        aria-label="Backend environment"
        className="mt-lg grid grid-cols-1 gap-md sm:grid-cols-2 xl:grid-cols-3"
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
              onClick={() => setPending(option)}
              className={`flex h-full flex-col gap-xs rounded-lg border p-md text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:cursor-default ${
                selected
                  ? "border-brand ring-2 ring-brand-soft"
                  : "border-hairline hover:border-brand-soft hover:bg-surface-tint disabled:opacity-60"
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
        <p className="mt-md text-body-sm text-muted">
          This deployment&apos;s configured backend is not one of the entries
          above, so none is marked selected.
        </p>
      ) : null}

      {error ? <p className="mt-md text-body-sm text-error">{error}</p> : null}

      {pending ? (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-scrim/30 p-lg sm:items-center"
          role="dialog"
          aria-modal="true"
          aria-label={`Switch to ${pending.label}?`}
        >
          <div className="w-full max-w-form rounded-lg bg-surface p-xl shadow-lg">
            <h3 className="flex items-start gap-sm text-title-md text-ink">
              <AlertCircle size={18} className="mt-xxs shrink-0 text-warning" />
              Switch to {pending.label}?
            </h3>
            <p className="mt-md text-body-md text-muted">
              You will be signed out and the page will reload. {pending.label}{" "}
              has its own database, so nothing from the current environment
              carries over.
            </p>
            <div className="mt-xl flex flex-wrap items-center justify-end gap-sm">
              <button
                type="button"
                onClick={() => setPending(null)}
                disabled={switching !== null}
                className="inline-flex h-10 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => void confirmSwitch()}
                disabled={switching !== null}
                className="inline-flex h-10 items-center rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong disabled:bg-disabled"
              >
                {switching ? "Signing out…" : "Switch and sign out"}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </section>
  );
}
