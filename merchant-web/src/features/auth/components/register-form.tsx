"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "../auth-context";
import { registerSchema } from "../schema";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { AuthErrorBanner } from "./auth-shell";

type FieldKey =
  | "name"
  | "shopName"
  | "email"
  | "password"
  | "confirmPassword"
  | "acceptedTerms"
  | "acceptedPrivacy";

export function RegisterForm() {
  const { register, status } = useAuth();
  const router = useRouter();
  const [values, setValues] = useState({
    name: "",
    shopName: "",
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
    if (status === "authed") router.replace("/dashboard");
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
        shopName: f.shopName?.[0],
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
        shopName: parsed.data.shopName,
        email: parsed.data.email,
        password: parsed.data.password,
        acceptedTerms: true,
        acceptedPrivacy: true,
      });
      router.replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not create your account.");
    } finally {
      setSubmitting(false);
    }
  }

  const consentError = fieldErrors.acceptedTerms ?? fieldErrors.acceptedPrivacy;

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-lg">
      {error ? <AuthErrorBanner message={error} /> : null}
      <Field
        label="Your name"
        name="name"
        autoComplete="name"
        autoFocus
        value={values.name}
        onChange={(e) => set("name", e.target.value)}
        error={fieldErrors.name}
      />
      <Field
        label="Shop name"
        name="shopName"
        autoComplete="organization"
        helper="Shown to customers in the marketplace. You can rename it later."
        value={values.shopName}
        onChange={(e) => set("shopName", e.target.value)}
        error={fieldErrors.shopName}
      />
      <Field
        label="Email"
        type="email"
        name="email"
        autoComplete="email"
        inputMode="email"
        value={values.email}
        onChange={(e) => set("email", e.target.value)}
        error={fieldErrors.email}
      />
      <Field
        label="Password"
        name="password"
        autoComplete="new-password"
        toggleable
        helper="At least 8 characters, with a letter and a number."
        value={values.password}
        onChange={(e) => set("password", e.target.value)}
        error={fieldErrors.password}
      />
      <Field
        label="Confirm password"
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
          label="I accept the Terms of Service"
        />
        <ConsentRow
          checked={acceptedPrivacy}
          onChange={setAcceptedPrivacy}
          label="I accept the Privacy Policy"
        />
        {consentError ? (
          <p className="text-body-sm text-error">{consentError}</p>
        ) : null}
      </fieldset>

      <SubmitButton loading={submitting}>Create account</SubmitButton>
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
  label: string;
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
