"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "../auth-context";
import { recoveryPinSchema } from "../schema";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { AuthErrorBanner } from "./auth-shell";

/**
 * Fallback sign-in for Google-only accounts when Google itself isn't
 * reachable. Doesn't collect a TOTP code — an account with both a
 * recovery PIN and 2FA enabled hitting this exact path is a narrow edge
 * case not covered in this pass (see PENDING.md).
 */
export function RecoveryPinLoginForm() {
  const { loginWithRecoveryPin, status } = useAuth();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [pin, setPin] = useState("");
  const [fieldErrors, setFieldErrors] = useState<{ email?: string; pin?: string }>({});
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (status === "authed") router.replace("/dashboard");
  }, [status, router]);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const emailOk = /\S+@\S+\.\S+/.test(email);
    const pinParsed = recoveryPinSchema.safeParse(pin);
    if (!emailOk || !pinParsed.success) {
      setFieldErrors({
        email: emailOk ? undefined : "Enter a valid email address",
        pin: pinParsed.success ? undefined : pinParsed.error.issues[0]?.message,
      });
      return;
    }
    setFieldErrors({});
    setSubmitting(true);
    try {
      await loginWithRecoveryPin(email, pin);
      router.replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign in failed.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-lg">
      {error ? <AuthErrorBanner message={error} /> : null}
      <Field
        label="Email"
        type="email"
        name="email"
        autoComplete="email"
        inputMode="email"
        autoFocus
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        error={fieldErrors.email}
      />
      <Field
        label="Recovery PIN"
        name="pin"
        inputMode="numeric"
        autoComplete="off"
        toggleable
        maxLength={6}
        value={pin}
        onChange={(e) => setPin(e.target.value.replace(/\D/g, ""))}
        error={fieldErrors.pin}
      />
      <SubmitButton loading={submitting} pill>
        Sign in
      </SubmitButton>
    </form>
  );
}
