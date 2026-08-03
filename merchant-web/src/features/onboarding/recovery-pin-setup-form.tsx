"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/features/auth/auth-context";
import { Field } from "@/features/auth/components/field";
import { SubmitButton } from "@/features/auth/components/submit-button";
import { AuthErrorBanner } from "@/features/auth/components/auth-shell";
import { recoveryPinSchema } from "@/features/auth/schema";
import { needsRecoveryPinSetup } from "@/features/auth/types";

/**
 * Shown right after a Google sign-in creates (or first links) an account.
 * Google accounts have no password, so this PIN is the only fallback if
 * Google itself is ever unreachable — mirrors WhatsApp's 2-step PIN: short,
 * numeric, chosen by the user (not a generated code to save).
 */
export function RecoveryPinSetupForm() {
  const { status, user } = useAuth();
  const router = useRouter();

  const [pin, setPin] = useState("");
  const [confirmPin, setConfirmPin] = useState("");
  const [pinError, setPinError] = useState<string | undefined>();
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Gate: guests to login; anyone who already set a PIN skips straight to
  // the usual post-signup onboarding (naming the shop).
  useEffect(() => {
    if (status === "guest") {
      router.replace("/login");
      return;
    }
    if (status === "authed" && user && !needsRecoveryPinSetup(user)) {
      router.replace("/onboarding");
    }
  }, [status, user, router]);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const parsed = recoveryPinSchema.safeParse(pin);
    if (!parsed.success) {
      setPinError(parsed.error.issues[0]?.message);
      return;
    }
    if (pin !== confirmPin) {
      setPinError("PINs don't match");
      return;
    }
    setPinError(undefined);
    setSubmitting(true);
    try {
      const res = await fetch("/api/auth/recovery-pin", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pin }),
      });
      if (!res.ok) {
        const body = (await res.json().catch(() => ({}))) as { error?: string };
        throw new Error(body.error ?? "Could not save your PIN.");
      }
      router.replace("/onboarding");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save your PIN.");
      setSubmitting(false);
    }
  }

  if (status !== "authed" || !user || !needsRecoveryPinSetup(user)) {
    return (
      <main className="flex min-h-dvh items-center justify-center px-lg">
        <p className="text-body-md text-subtle">Loading…</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-form flex-col justify-center px-lg py-massive">
      <p className="text-label-md uppercase tracking-wide text-brand">ShopXY · Merchant</p>
      <h1 className="mt-xs text-headline-md text-ink">Set up a recovery PIN</h1>
      <p className="mt-sm text-body-md text-muted">
        Your account signed in with Google, which doesn&apos;t use a password.
        Choose a 4-6 digit PIN so you can still sign in if Google is ever
        unreachable. You can change it later in Settings.
      </p>

      <form onSubmit={onSubmit} noValidate className="mt-xxl flex flex-col gap-lg">
        {error ? <AuthErrorBanner message={error} /> : null}
        <Field
          label="PIN"
          name="pin"
          inputMode="numeric"
          autoComplete="off"
          toggleable
          autoFocus
          maxLength={6}
          value={pin}
          onChange={(e) => setPin(e.target.value.replace(/\D/g, ""))}
          error={pinError}
        />
        <Field
          label="Confirm PIN"
          name="confirmPin"
          inputMode="numeric"
          autoComplete="off"
          toggleable
          maxLength={6}
          value={confirmPin}
          onChange={(e) => setConfirmPin(e.target.value.replace(/\D/g, ""))}
        />
        <SubmitButton loading={submitting}>Save PIN</SubmitButton>
      </form>
    </main>
  );
}
