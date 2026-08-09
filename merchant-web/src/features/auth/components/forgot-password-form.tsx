"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { TriangleAlert } from "@/shared/icons";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { AuthErrorBanner } from "./auth-shell";

const COOLDOWN = 30;

/**
 * Forgotten-password reset in two steps: ask for the email, then take the
 * emailed code plus the new password together.
 *
 * The code is the authorisation, so it's submitted alongside the password in
 * one request rather than exchanged for an intermediate reset token. One
 * fewer credential to mint, expire and get wrong, and the server-side check
 * is identical either way.
 *
 * The "sent" step never confirms the address exists — the backend answers the
 * same for a stranger's email as for a real one, and this copy has to match
 * that, or the UI leaks what the API deliberately doesn't.
 */
export function ForgotPasswordForm() {
  const t = useTranslations("auth");
  const router = useRouter();

  const [step, setStep] = useState<"email" | "code">("email");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [cooldown, setCooldown] = useState(0);

  useEffect(() => {
    if (cooldown <= 0) return;
    const id = setInterval(() => setCooldown((c) => c - 1), 1000);
    return () => clearInterval(id);
  }, [cooldown]);

  async function requestCode(e?: FormEvent) {
    e?.preventDefault();
    if (submitting || !email.trim()) return;
    setSubmitting(true);
    setError(null);
    try {
      const res = await fetch("/api/auth/forgot-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email.trim() }),
      });
      if (!res.ok && res.status === 400) {
        const body = (await res.json()) as { error?: string };
        throw new Error(body.error ?? t("forgot.failed"));
      }
      setStep("code");
      setCooldown(COOLDOWN);
    } catch (err) {
      setError(err instanceof Error ? err.message : t("forgot.failed"));
    } finally {
      setSubmitting(false);
    }
  }

  async function submitReset(e: FormEvent) {
    e.preventDefault();
    if (submitting) return;
    if (password !== confirm) {
      setError(t("forgot.mismatch"));
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const res = await fetch("/api/auth/reset-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email.trim(), otp, newPassword: password }),
      });
      if (!res.ok) {
        const body = (await res.json()) as { error?: string };
        throw new Error(body.error ?? t("forgot.failed"));
      }
      // Straight to sign-in: the reset issues no session, and every device was
      // signed out, so there is nothing to return to.
      router.replace("/login?reason=password-reset");
    } catch (err) {
      setError(err instanceof Error ? err.message : t("forgot.failed"));
      setSubmitting(false);
    }
  }

  if (step === "email") {
    return (
      <form onSubmit={requestCode} className="flex flex-col gap-lg">
        {error ? <AuthErrorBanner message={error} /> : null}
        <Field
          label={t("forgot.emailLabel")}
          type="email"
          name="email"
          autoComplete="email"
          inputMode="email"
          autoFocus
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <SubmitButton loading={submitting} pill disabled={!email.trim()}>
          {t("forgot.sendCode")}
        </SubmitButton>
      </form>
    );
  }

  return (
    <form onSubmit={submitReset} className="flex flex-col gap-lg">
      <p className="rounded-md bg-info-soft px-md py-sm text-body-sm text-ink">
        {t("forgot.sent", { email: email.trim() })}
      </p>
      {error ? <AuthErrorBanner message={error} /> : null}

      <Field
        label={t("forgot.codeLabel")}
        name="otp"
        inputMode="numeric"
        autoComplete="one-time-code"
        maxLength={6}
        autoFocus
        value={otp}
        onChange={(e) => setOtp(e.target.value.replace(/\D/g, "").slice(0, 6))}
      />
      <Field
        label={t("forgot.newPasswordLabel")}
        name="newPassword"
        autoComplete="new-password"
        toggleable
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      <Field
        label={t("forgot.confirmLabel")}
        name="confirmPassword"
        autoComplete="new-password"
        toggleable
        value={confirm}
        onChange={(e) => setConfirm(e.target.value)}
      />

      {/* Stated up front, not discovered afterwards — being signed out
          everywhere is surprising if you weren't told. */}
      <p className="flex items-start gap-sm text-body-sm text-muted">
        <TriangleAlert size={16} className="mt-px shrink-0 text-warning" />
        {t("forgot.signOutWarning")}
      </p>

      <SubmitButton
        loading={submitting}
        pill
        disabled={otp.length !== 6 || password.length === 0 || confirm.length === 0}
      >
        {t("forgot.submit")}
      </SubmitButton>

      <div className="flex flex-wrap items-center justify-center gap-x-sm gap-y-xs text-body-sm text-muted">
        <span>{t("forgot.noCode")}</span>
        <button
          type="button"
          onClick={() => void requestCode()}
          disabled={cooldown > 0 || submitting}
          className="font-medium text-brand-strong underline-offset-2 hover:underline focus-visible:underline focus-visible:outline-none disabled:text-subtle disabled:no-underline"
        >
          {cooldown > 0 ? t("forgot.resendIn", { seconds: cooldown }) : t("forgot.resend")}
        </button>
        <span aria-hidden>·</span>
        <button
          type="button"
          onClick={() => {
            setStep("email");
            setOtp("");
            setPassword("");
            setConfirm("");
            setError(null);
          }}
          disabled={submitting}
          className="underline-offset-2 hover:text-ink hover:underline focus-visible:outline-none focus-visible:underline disabled:text-disabled"
        >
          {t("forgot.changeEmail")}
        </button>
      </div>
    </form>
  );
}
