"use client";

import { useEffect, useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useAuth } from "../auth-context";
import { acceptInviteSchema } from "../schema";
import { Divider } from "@/shared/ui/divider";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { Banner } from "./banner";

type Preview = { email: string; roleLabel: string; shopName: string };

export function AcceptInviteForm({ token }: { token: string }) {
  const { acceptInvite } = useAuth();
  const router = useRouter();
  const t = useTranslations("auth");

  const [loading, setLoading] = useState(Boolean(token));
  const [preview, setPreview] = useState<Preview | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(
    token ? null : t("invite.linkInvalid"),
  );

  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [fieldErrors, setFieldErrors] = useState<{
    name?: string;
    password?: string;
    confirmPassword?: string;
  }>({});
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!token) return;
    let active = true;
    void (async () => {
      try {
        const res = await fetch(
          `/api/auth/team-invite/${encodeURIComponent(token)}`,
          { cache: "no-store" },
        );
        const body = (await res.json().catch(() => ({}))) as {
          email?: string;
          roleLabel?: string;
          shopName?: string;
          error?: string;
        };
        if (!active) return;
        if (res.ok && body.email) {
          setPreview({
            email: body.email,
            roleLabel: body.roleLabel ?? t("invite.defaultRole"),
            shopName: body.shopName ?? t("invite.defaultShop"),
          });
        } else {
          setPreviewError(body.error ?? t("invite.notValid"));
        }
      } catch {
        if (active) {
          setPreviewError(t("invite.checkFailed"));
        }
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [token, t]);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const parsed = acceptInviteSchema.safeParse({
      token,
      name: name || undefined,
      password,
      confirmPassword,
    });
    if (!parsed.success) {
      const f = parsed.error.flatten().fieldErrors;
      setFieldErrors({
        name: f.name?.[0],
        password: f.password?.[0],
        confirmPassword: f.confirmPassword?.[0],
      });
      return;
    }
    setFieldErrors({});
    setSubmitting(true);
    try {
      await acceptInvite({ token, name: name || undefined, password });
      router.replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : t("invite.acceptFailed"));
      setSubmitting(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-form flex-col justify-center px-lg py-massive">
      <p className="text-label-md uppercase tracking-wide text-brand">
        ShopXY · Merchant
      </p>
      <h1 className="mt-xs text-headline-md text-ink">{t("invite.title")}</h1>

      {loading ? (
        <p className="mt-lg text-body-md text-subtle">{t("invite.checking")}</p>
      ) : previewError ? (
        <div className="mt-lg flex flex-col gap-lg">
          <Banner variant="error" message={previewError} />
          <Link
            href="/login"
            className="text-body-md text-brand-strong underline-offset-2 hover:underline"
          >
            {t("invite.goToSignIn")}
          </Link>
        </div>
      ) : preview ? (
        <>
          <p className="mt-sm text-body-md text-muted">
            {t.rich("invite.summary", {
              shop: () => <span className="text-ink">{preview.shopName}</span>,
              email: () => <span className="text-ink">{preview.email}</span>,
              role: () => <span className="text-ink">{preview.roleLabel}</span>,
            })}
          </p>

          <form onSubmit={onSubmit} noValidate className="mt-xxl flex flex-col gap-lg">
            {error ? <Banner variant="error" message={error} /> : null}
            <Field
              label={t("field.yourNameOptional")}
              autoComplete="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              error={fieldErrors.name}
            />
            <Field
              label={t("field.password")}
              autoComplete="new-password"
              toggleable
              helper={t("field.passwordHelper")}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              error={fieldErrors.password}
            />
            <Field
              label={t("field.confirmPassword")}
              autoComplete="new-password"
              toggleable
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              error={fieldErrors.confirmPassword}
            />
            <SubmitButton loading={submitting} pill>{t("invite.submit")}</SubmitButton>
          </form>

          <Divider className="mt-xxl" />
          <p className="mt-lg text-center text-body-md text-muted">
            {t("invite.haveAccount")}{" "}
            <Link
              href="/login"
              className="text-brand-strong underline-offset-2 hover:underline"
            >
              {t("invite.signIn")}
            </Link>
          </p>
        </>
      ) : null}
    </main>
  );
}
