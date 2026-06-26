"use client";

import { useEffect, useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "../auth-context";
import { loginSchema } from "../schema";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { AuthErrorBanner } from "./auth-shell";
import { GoogleButton } from "./google-button";

export function LoginForm() {
  const { login, status } = useAuth();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [fieldErrors, setFieldErrors] = useState<{
    email?: string;
    password?: string;
  }>({});
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Already signed in → leave the auth screen.
  useEffect(() => {
    if (status === "authed") router.replace("/dashboard");
  }, [status, router]);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const parsed = loginSchema.safeParse({ email, password });
    if (!parsed.success) {
      const f = parsed.error.flatten().fieldErrors;
      setFieldErrors({ email: f.email?.[0], password: f.password?.[0] });
      return;
    }
    setFieldErrors({});
    setSubmitting(true);
    try {
      await login(parsed.data.email, parsed.data.password);
      router.replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign in failed.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-lg">
      <GoogleButton />
      <div className="flex items-center gap-md text-label-sm text-subtle">
        <span className="h-px flex-1 bg-hairline" />
        or continue with email
        <span className="h-px flex-1 bg-hairline" />
      </div>
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
        label="Password"
        name="password"
        autoComplete="current-password"
        toggleable
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        error={fieldErrors.password}
      />
      <SubmitButton loading={submitting} pill>Sign in</SubmitButton>
      {/* Pre-signin discoverability of the published policies — the DPDP notice
          and the user agreement must be accessible before/around collection,
          not only behind auth. (DPDP Act 2023 s.5; IT Intermediary Rules 2021
          r.3(1)(b)/(f).) */}
      <p className="text-center text-body-sm text-muted">
        By signing in you agree to our{" "}
        <Link href="/legal/terms" className="text-ink underline hover:text-brand">
          Terms
        </Link>{" "}
        and acknowledge our{" "}
        <Link href="/legal/privacy" className="text-ink underline hover:text-brand">
          Privacy Policy
        </Link>
        . We use a strictly-necessary session cookie to keep you signed in.
      </p>
      <p className="text-center text-body-sm text-subtle">
        Trouble signing in?{" "}
        <a
          href="mailto:support@shopxy.app"
          className="text-muted underline hover:text-brand"
        >
          Contact support
        </a>
      </p>
      <p className="text-center text-body-sm text-subtle">
        <Link
          href="/legal/compliance"
          className="text-muted underline hover:text-brand"
        >
          Compliance, laws &amp; formulas
        </Link>
      </p>
    </form>
  );
}
