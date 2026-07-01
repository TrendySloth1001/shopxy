"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useAuth } from "../auth-context";
import { registerSchema } from "../schema";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { AuthErrorBanner } from "./auth-shell";

type FieldKey =
  | "name"
  | "email"
  | "password"
  | "confirmPassword"
  | "acceptedTerms"
  | "acceptedPrivacy";

export function RegisterForm() {
  const { register, status } = useAuth();
  const router = useRouter();
  const t = useTranslations("auth");
  const [values, setValues] = useState({
    name: "",
    email: "",
    password: "",
    confirmPassword: "",
  });
  const [acceptedTerms, setAcceptedTerms] = useState(false);
  const [acceptedPrivacy, setAcceptedPrivacy] = useState(false);
  const [fieldErrors, setFieldErrors] = useState<Partial<Record<FieldKey, string>>>(
    {},
  );
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    // Authed visitors continue to onboarding; its own gate forwards anyone
    // who already has a shop (or joined a team) straight to the dashboard.
    if (status === "authed") router.replace("/onboarding");
  }, [status, router]);

  function set<K extends keyof typeof values>(key: K, value: string) {
    setValues((v) => ({ ...v, [key]: value }));
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const parsed = registerSchema.safeParse({
      ...values,
      acceptedTerms,
      acceptedPrivacy,
    });
    if (!parsed.success) {
      const f = parsed.error.flatten().fieldErrors;
      setFieldErrors({
        name: f.name?.[0],
        email: f.email?.[0],
        password: f.password?.[0],
        confirmPassword: f.confirmPassword?.[0],
        acceptedTerms: f.acceptedTerms?.[0],
        acceptedPrivacy: f.acceptedPrivacy?.[0],
      });
      return;
    }
    setFieldErrors({});
    setSubmitting(true);
    try {
      await register({
        name: parsed.data.name,
        email: parsed.data.email,
        password: parsed.data.password,
        acceptedTerms: true,
        acceptedPrivacy: true,
      });
      // Next step: name the shop (or skip if they joined a team via invite).
      router.replace("/onboarding");
    } catch (err) {
      setError(err instanceof Error ? err.message : t("register.failed"));
    } finally {
      setSubmitting(false);
    }
  }

  const consentError = fieldErrors.acceptedTerms ?? fieldErrors.acceptedPrivacy;

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-lg">
      {error ? <AuthErrorBanner message={error} /> : null}
      <Field
        label={t("field.yourName")}
        name="name"
        autoComplete="name"
        autoFocus
        value={values.name}
        onChange={(e) => set("name", e.target.value)}
        error={fieldErrors.name}
      />
      <Field
        label={t("field.email")}
        type="email"
        name="email"
        autoComplete="email"
        inputMode="email"
        value={values.email}
        onChange={(e) => set("email", e.target.value)}
        error={fieldErrors.email}
      />
      <Field
        label={t("field.password")}
        name="password"
        autoComplete="new-password"
        toggleable
        helper={t("field.passwordHelper")}
        value={values.password}
        onChange={(e) => set("password", e.target.value)}
        error={fieldErrors.password}
      />
      <Field
        label={t("field.confirmPassword")}
        name="confirmPassword"
        autoComplete="new-password"
        toggleable
        value={values.confirmPassword}
        onChange={(e) => set("confirmPassword", e.target.value)}
        error={fieldErrors.confirmPassword}
      />

      <fieldset className="flex flex-col gap-sm">
        <ConsentRow
          checked={acceptedTerms}
          onChange={setAcceptedTerms}
          label={t.rich("register.acceptTerms", {
            link: (chunks) => <LegalLink href="/legal/terms">{chunks}</LegalLink>,
          })}
        />
        <ConsentRow
          checked={acceptedPrivacy}
          onChange={setAcceptedPrivacy}
          label={t.rich("register.acceptPrivacy", {
            link: (chunks) => <LegalLink href="/legal/privacy">{chunks}</LegalLink>,
          })}
        />
        {consentError ? (
          <p className="text-body-sm text-error">{consentError}</p>
        ) : null}
      </fieldset>

      <SubmitButton loading={submitting} pill>{t("register.submit")}</SubmitButton>
    </form>
  );
}

function ConsentRow({
  checked,
  onChange,
  label,
}: {
  checked: boolean;
  onChange: (next: boolean) => void;
  label: React.ReactNode;
}) {
  return (
    <label className="flex cursor-pointer items-center gap-sm text-body-md text-muted">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="size-4 accent-brand"
      />
      {label}
    </label>
  );
}

function LegalLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="text-brand-strong underline-offset-2 hover:underline focus-visible:underline focus-visible:outline-none"
      onClick={(e) => e.stopPropagation()}
    >
      {children}
    </a>
  );
}
