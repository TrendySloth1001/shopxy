"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useAuth } from "../auth-context";
import { changePasswordSchema } from "../schema";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { Banner } from "./banner";

export function SecuritySection() {
  const { changePassword, logoutEverywhere } = useAuth();
  const router = useRouter();
  const t = useTranslations("auth");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [fieldErrors, setFieldErrors] = useState<{
    currentPassword?: string;
    newPassword?: string;
    confirmPassword?: string;
  }>({});
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [signingOut, setSigningOut] = useState(false);

  async function onChangePassword(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const parsed = changePasswordSchema.safeParse({
      currentPassword,
      newPassword,
      confirmPassword,
    });
    if (!parsed.success) {
      const f = parsed.error.flatten().fieldErrors;
      setFieldErrors({
        currentPassword: f.currentPassword?.[0],
        newPassword: f.newPassword?.[0],
        confirmPassword: f.confirmPassword?.[0],
      });
      return;
    }
    setFieldErrors({});
    setSubmitting(true);
    try {
      await changePassword(parsed.data.currentPassword, parsed.data.newPassword);
      router.replace("/login?reason=password-changed");
    } catch (err) {
      setError(err instanceof Error ? err.message : t("security.changeFailed"));
      setSubmitting(false);
    }
  }

  async function onSignOutEverywhere() {
    setSigningOut(true);
    try {
      await logoutEverywhere();
      router.replace("/login?reason=signed-out-everywhere");
    } catch {
      setSigningOut(false);
    }
  }

  return (
    <div className="flex flex-col gap-xl">
      <form onSubmit={onChangePassword} noValidate className="flex flex-col gap-lg">
        {error ? <Banner variant="error" message={error} /> : null}
        <Field
          label={t("security.currentPassword")}
          autoComplete="current-password"
          toggleable
          value={currentPassword}
          onChange={(e) => setCurrentPassword(e.target.value)}
          error={fieldErrors.currentPassword}
        />
        <Field
          label={t("security.newPassword")}
          autoComplete="new-password"
          toggleable
          helper={t("field.passwordHelper")}
          value={newPassword}
          onChange={(e) => setNewPassword(e.target.value)}
          error={fieldErrors.newPassword}
        />
        <Field
          label={t("security.confirmNewPassword")}
          autoComplete="new-password"
          toggleable
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          error={fieldErrors.confirmPassword}
        />
        <p className="text-body-sm text-subtle">
          {t("security.changeSignsOutNote")}
        </p>
        <div>
          <SubmitButton loading={submitting}>{t("security.changePassword")}</SubmitButton>
        </div>
      </form>

      <div className="flex flex-col gap-sm">
        <p className="text-body-md text-ink">{t("security.signOutAllTitle")}</p>
        <p className="text-body-sm text-muted">
          {t("security.signOutAllDesc")}
        </p>
        <button
          type="button"
          onClick={onSignOutEverywhere}
          disabled={signingOut}
          className="mt-xs inline-flex h-11 w-fit items-center justify-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
        >
          {signingOut ? t("security.signingOut") : t("security.signOutEverywhere")}
        </button>
      </div>
    </div>
  );
}
