"use client";

import {
  useEffect,
  useRef,
  useState,
  type ClipboardEvent,
  type FormEvent,
  type KeyboardEvent,
} from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useAuth } from "../auth-context";
import { SubmitButton } from "./submit-button";
import { AuthErrorBanner } from "./auth-shell";
import { Modal, ModalActions } from "@/shared/ui/modal";

const LENGTH = 6;
const COOLDOWN = 30;

/**
 * Signup OTP entry. **Deliberately hard to leave by accident**: the account
 * does not exist until the code is confirmed, so wandering off mid-flow
 * silently discards the signup. Back-navigation and tab-close are both
 * guarded, and there is exactly one explicit way out.
 *
 * The browser can't be prevented from navigating, only asked — so this is a
 * confirmation, not a cage. That's the honest ceiling on the web; the Flutter
 * app can and does intercept its back gesture outright.
 */
export function VerifyEmailForm({ email }: { email: string }) {
  const { verifyEmail, resendOtp } = useAuth();
  const router = useRouter();
  const t = useTranslations("auth");

  const [digits, setDigits] = useState<string[]>(() => Array(LENGTH).fill(""));
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [cooldown, setCooldown] = useState(COOLDOWN);
  const [confirmLeave, setConfirmLeave] = useState(false);
  const inputs = useRef<Array<HTMLInputElement | null>>([]);
  /// Set once the code is accepted, so the guards below stop firing while we
  /// navigate on to onboarding — otherwise success itself trips the warning.
  const done = useRef(false);

  const code = digits.join("");

  // No email in the URL → nothing to verify; back to signup.
  useEffect(() => {
    if (!email) router.replace("/register");
  }, [email, router]);

  useEffect(() => {
    inputs.current[0]?.focus();
  }, []);

  useEffect(() => {
    if (cooldown <= 0) return;
    const id = setInterval(() => setCooldown((c) => c - 1), 1000);
    return () => clearInterval(id);
  }, [cooldown]);

  // Refresh / tab-close warning. The browser shows its own generic copy; we
  // only get to say that there IS unsaved work.
  useEffect(() => {
    function onBeforeUnload(e: BeforeUnloadEvent) {
      if (done.current) return;
      e.preventDefault();
    }
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, []);

  // Back-button guard. Push a throwaway history entry so the first Back lands
  // here instead of leaving; on popstate, re-push it and ask. Declining keeps
  // them on the page with history intact.
  useEffect(() => {
    window.history.pushState(null, "", window.location.href);
    function onPopState() {
      if (done.current) return;
      window.history.pushState(null, "", window.location.href);
      setConfirmLeave(true);
    }
    window.addEventListener("popstate", onPopState);
    return () => window.removeEventListener("popstate", onPopState);
  }, []);

  async function submit(codeArg?: string, e?: FormEvent) {
    e?.preventDefault();
    const c = codeArg ?? code;
    if (c.length !== LENGTH || submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      await verifyEmail(email, c);
      done.current = true;
      router.replace("/onboarding");
    } catch (err) {
      setError(err instanceof Error ? err.message : t("verify.failed"));
      setDigits(Array(LENGTH).fill(""));
      inputs.current[0]?.focus();
      setSubmitting(false);
    }
  }

  function setDigit(i: number, value: string) {
    const d = value.replace(/\D/g, "").slice(-1);
    const next = [...digits];
    next[i] = d;
    setDigits(next);
    setError(null);
    if (d && i < LENGTH - 1) inputs.current[i + 1]?.focus();
    if (next.every((x) => x !== "")) void submit(next.join(""));
  }

  function onKeyDown(i: number, e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Backspace" && !digits[i] && i > 0) {
      inputs.current[i - 1]?.focus();
    }
  }

  function onPaste(e: ClipboardEvent<HTMLDivElement>) {
    const text = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, LENGTH);
    if (!text) return;
    e.preventDefault();
    const next = Array<string>(LENGTH).fill("");
    for (let i = 0; i < text.length; i++) next[i] = text[i];
    setDigits(next);
    inputs.current[Math.min(text.length, LENGTH - 1)]?.focus();
    if (next.every((x) => x !== "")) void submit(next.join(""));
  }

  async function resend() {
    if (cooldown > 0) return;
    try {
      await resendOtp(email);
      setCooldown(COOLDOWN);
    } catch (err) {
      setError(err instanceof Error ? err.message : t("verify.failed"));
    }
  }

  return (
    <form onSubmit={(e) => submit(undefined, e)} className="flex flex-col gap-lg">
      {error ? <AuthErrorBanner message={error} /> : null}
      <div className="flex justify-center gap-sm" onPaste={onPaste}>
        {digits.map((d, i) => (
          <input
            key={i}
            ref={(el) => {
              inputs.current[i] = el;
            }}
            value={d}
            onChange={(e) => setDigit(i, e.target.value)}
            onKeyDown={(e) => onKeyDown(i, e)}
            inputMode="numeric"
            autoComplete={i === 0 ? "one-time-code" : "off"}
            maxLength={1}
            aria-label={`${t("verify.codeLabel")} ${i + 1}`}
            className="h-14 w-12 rounded-input border border-hairline bg-surface text-center text-headline-sm font-semibold text-ink outline-none transition-colors focus:border-brand"
          />
        ))}
      </div>

      <div className="flex items-center justify-center gap-xs text-body-md text-muted">
        <span>{t("verify.noCode")}</span>
        <button
          type="button"
          onClick={resend}
          disabled={cooldown > 0}
          className="font-medium text-brand-strong underline-offset-2 hover:underline focus-visible:underline focus-visible:outline-none disabled:text-subtle disabled:no-underline"
        >
          {cooldown > 0 ? t("verify.resendIn", { seconds: cooldown }) : t("verify.resend")}
        </button>
      </div>

      <SubmitButton loading={submitting} pill disabled={code.length !== LENGTH}>
        {t("verify.submit")}
      </SubmitButton>

      {/* The one explicit way out. A screen with no exit at all is worse than
          one whose exit costs a confirmation. */}
      <button
        type="button"
        onClick={() => setConfirmLeave(true)}
        disabled={submitting}
        className="mx-auto text-body-md text-muted underline-offset-2 transition-colors hover:text-ink hover:underline focus-visible:outline-none focus-visible:underline disabled:text-disabled"
      >
        {t("verify.cancelSignup")}
      </button>

      {confirmLeave ? (
        <Modal title={t("verify.leaveTitle")} onClose={() => setConfirmLeave(false)}>
          <p className="text-body-md text-muted">{t("verify.leaveBody")}</p>
          <ModalActions
            busy={false}
            danger
            confirmLabel={t("verify.leaveDiscard")}
            cancelLabel={t("verify.leaveStay")}
            onCancel={() => setConfirmLeave(false)}
            onConfirm={() => {
              done.current = true;
              router.replace("/login");
            }}
          />
        </Modal>
      ) : null}
    </form>
  );
}
