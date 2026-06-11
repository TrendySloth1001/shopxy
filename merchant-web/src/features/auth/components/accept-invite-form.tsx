"use client";

import { useEffect, useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
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

  // Derive the no-token case from the prop instead of setting it in the effect.
  const [loading, setLoading] = useState(Boolean(token));
  const [preview, setPreview] = useState<Preview | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(
    token ? null : "This invitation link is invalid.",
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
            roleLabel: body.roleLabel ?? "Staff",
            shopName: body.shopName ?? "a shop",
          });
        } else {
          setPreviewError(body.error ?? "This invitation is not valid.");
        }
      } catch {
        if (active) {
          setPreviewError(
            "Could not check this invitation — check your connection and reload the page.",
          );
        }
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [token]);

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
      setError(err instanceof Error ? err.message : "Could not accept this invitation.");
      setSubmitting(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-form flex-col justify-center px-lg py-massive">
      <p className="text-label-md uppercase tracking-wide text-brand">
        ShopXY · Merchant
      </p>
      <h1 className="mt-xs text-headline-md text-ink">Join the team</h1>

      {loading ? (
        <p className="mt-lg text-body-md text-subtle">Checking your invitation…</p>
      ) : previewError ? (
        <div className="mt-lg flex flex-col gap-lg">
          <Banner variant="error" message={previewError} />
          <Link
            href="/login"
            className="text-body-md text-brand-strong underline-offset-2 hover:underline"
          >
            Go to sign in →
          </Link>
        </div>
      ) : preview ? (
        <>
          <p className="mt-sm text-body-md text-muted">
            <span className="text-ink">{preview.shopName}</span> invited{" "}
            <span className="text-ink">{preview.email}</span> to join as{" "}
            <span className="text-ink">{preview.roleLabel}</span>. Set a password
            to accept.
          </p>

          <form onSubmit={onSubmit} noValidate className="mt-xxl flex flex-col gap-lg">
            {error ? <Banner variant="error" message={error} /> : null}
            <Field
              label="Your name (optional)"
              autoComplete="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              error={fieldErrors.name}
            />
            <Field
              label="Password"
              autoComplete="new-password"
              toggleable
              helper="At least 8 characters, with a letter and a number."
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              error={fieldErrors.password}
            />
            <Field
              label="Confirm password"
              autoComplete="new-password"
              toggleable
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              error={fieldErrors.confirmPassword}
            />
            <SubmitButton loading={submitting}>Accept & create account</SubmitButton>
          </form>

          <Divider className="mt-xxl" />
          <p className="mt-lg text-center text-body-md text-muted">
            Already have an account?{" "}
            <Link
              href="/login"
              className="text-brand-strong underline-offset-2 hover:underline"
            >
              Sign in
            </Link>
          </p>
        </>
      ) : null}
    </main>
  );
}
