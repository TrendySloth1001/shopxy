"use client";

import { useCallback, useEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "../auth-context";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { AuthErrorBanner } from "./auth-shell";

const COOLDOWN = 30;
const CODE_LENGTH = 6;

export function VerifyEmailForm({ email }: { email: string }) {
  const { verifyEmail, resendOtp } = useAuth();
  const router = useRouter();

  const [otp, setOtp] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [cooldown, setCooldown] = useState(COOLDOWN);
  const done = useRef(false);

  useEffect(() => {
    if (cooldown <= 0) return;
    const id = setInterval(() => setCooldown((c) => c - 1), 1000);
    return () => clearInterval(id);
  }, [cooldown]);

  useEffect(() => {
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      if (done.current) return;
      e.preventDefault();
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, []);

  const submit = useCallback(
    async (code: string) => {
      if (submitting || code.length !== CODE_LENGTH) return;
      setSubmitting(true);
      setError(null);
      try {
        await verifyEmail(email, code);
        done.current = true;
        router.replace("/");
      } catch (err) {
        setError(err instanceof Error ? err.message : "That code didn't work.");
        setOtp("");
        setSubmitting(false);
      }
    },
    [email, router, submitting, verifyEmail],
  );

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    await submit(otp);
  }

  async function resend() {
    if (cooldown > 0 || submitting) return;
    setError(null);
    try {
      await resendOtp(email);
      setCooldown(COOLDOWN);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not send a new code.");
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-lg">
      <p className="rounded-md bg-info-soft px-md py-sm text-body-sm text-ink">
        We sent a 6-digit code to <span className="font-semibold">{email}</span>. Enter
        it to finish creating your account — your account isn&apos;t created until you
        do.
      </p>
      {error ? <AuthErrorBanner message={error} /> : null}

      <Field
        label="Verification code"
        name="otp"
        inputMode="numeric"
        autoComplete="one-time-code"
        maxLength={CODE_LENGTH}
        autoFocus
        value={otp}
        onChange={(e) => {
          const next = e.target.value.replace(/\D/g, "").slice(0, CODE_LENGTH);
          setOtp(next);
          setError(null);
          if (next.length === CODE_LENGTH) void submit(next);
        }}
      />

      <SubmitButton loading={submitting} disabled={otp.length !== CODE_LENGTH}>
        Verify and create account
      </SubmitButton>

      <div className="flex flex-wrap items-center justify-center gap-x-sm gap-y-xs text-body-sm text-muted">
        <span>Didn&apos;t get it?</span>
        <button
          type="button"
          onClick={() => void resend()}
          disabled={cooldown > 0 || submitting}
          className="font-medium text-brand-strong underline-offset-2 hover:underline focus-visible:underline focus-visible:outline-none disabled:text-subtle disabled:no-underline"
        >
          {cooldown > 0 ? `Resend in ${cooldown}s` : "Resend code"}
        </button>
      </div>
    </form>
  );
}
