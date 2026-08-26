"use client";

import { useCallback, useEffect, useState } from "react";
import { Check, TriangleAlert } from "@/shared/icons";
import { Modal, ModalActions } from "@/shared/ui/modal";

type EnvOption = { id: string; label: string; description: string };
type EnvState = { options: EnvOption[]; currentId: string | null; isDefault: boolean };

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
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return { available: state !== null, state };
}

export function EnvironmentPicker({ state }: { state: EnvState }) {
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
      window.location.href = "/login";
    } catch {
      setSwitching(null);
      setPending(null);
      setError("Could not switch environments. Check the server logs.");
    }
  }, [pending, switching]);

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
              onClick={() => setPending(option)}
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

      {pending ? (
        <Modal
          title={`Switch to ${pending.label}?`}
          onClose={() => (switching ? undefined : setPending(null))}
        >
          <p className="text-body-md text-muted">
            You will be signed out and the page will reload. {pending.label} has
            its own database, so nothing from the current environment carries
            over.
          </p>
          <ModalActions
            busy={switching !== null}
            confirmLabel={switching ? "Signing out…" : "Switch and sign out"}
            onCancel={() => setPending(null)}
            onConfirm={() => void confirmSwitch()}
          />
        </Modal>
      ) : null}
    </div>
  );
}
