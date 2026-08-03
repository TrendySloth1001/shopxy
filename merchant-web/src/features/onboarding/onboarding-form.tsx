"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/features/auth/auth-context";
import { needsRecoveryPinSetup } from "@/features/auth/types";
import { Field } from "@/features/auth/components/field";
import { SubmitButton } from "@/features/auth/components/submit-button";
import { AuthErrorBanner } from "@/features/auth/components/auth-shell";

/**
 * First-shop onboarding, shown straight after signup. Registration creates
 * only the merchant account; this is where they name their shop.
 *
 * "Check requests, then skip": an account that was invited to a team is
 * already made staff at signup (the backend accepts a matching pending
 * invite during register), so it arrives here carrying a `shopId` and is
 * forwarded to the dashboard — it never sees the shop form.
 */
export function OnboardingForm() {
  const { status, user, refresh } = useAuth();
  const router = useRouter();

  const [name, setName] = useState("");
  const [phoneNumber, setPhoneNumber] = useState("");
  const [shopCity, setShopCity] = useState("");
  const [shopState, setShopState] = useState("");
  const [nameError, setNameError] = useState<string | undefined>();
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Gate: guests to login; anyone who already has a shop or joined a team
  // (shopId present) straight to the dashboard — they don't onboard.
  useEffect(() => {
    if (status === "guest") {
      router.replace("/login");
      return;
    }
    if (status !== "authed" || !user) return;
    if (needsRecoveryPinSetup(user)) {
      router.replace("/onboarding/recovery-pin");
      return;
    }
    if (user.shopId != null) {
      router.replace("/dashboard");
    }
  }, [status, user, router]);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const trimmed = name.trim();
    if (trimmed.length < 2) {
      setNameError("Shop name must be at least 2 characters");
      return;
    }
    setNameError(undefined);
    setSubmitting(true);
    try {
      const res = await fetch("/api/onboarding/shop", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: trimmed,
          phoneNumber: phoneNumber.trim() || undefined,
          shopCity: shopCity.trim() || undefined,
          shopState: shopState.trim() || undefined,
        }),
      });
      if (!res.ok) {
        const body = (await res.json().catch(() => ({}))) as { error?: string };
        throw new Error(body.error ?? "Could not create your shop.");
      }
      // Pull the enriched session so `shopId` is set before the dashboard
      // loads (the backend busts the membership cache on create).
      await refresh();
      router.replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not create your shop.");
      setSubmitting(false);
    }
  }

  // Don't flash the form while the session resolves or while a redirect (to
  // login / recovery-pin / dashboard) is in flight.
  if (
    status !== "authed" ||
    (user && (needsRecoveryPinSetup(user) || user.shopId != null))
  ) {
    return (
      <main className="flex min-h-dvh items-center justify-center px-lg">
        <p className="text-body-md text-subtle">Loading…</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-form flex-col justify-center px-lg py-massive">
      <p className="text-label-md uppercase tracking-wide text-brand">ShopXY · Merchant</p>
      <h1 className="mt-xs text-headline-md text-ink">Set up your shop</h1>
      <p className="mt-sm text-body-md text-muted">
        Name your shop and add a few details. You can refine everything — GST,
        policies, logo — later in Settings.
      </p>

      <form onSubmit={onSubmit} noValidate className="mt-xxl flex flex-col gap-lg">
        {error ? <AuthErrorBanner message={error} /> : null}
        <Field
          label="Shop name"
          name="shopName"
          autoComplete="organization"
          autoFocus
          helper="Shown to customers in the marketplace. You can rename it later."
          value={name}
          onChange={(e) => setName(e.target.value)}
          error={nameError}
        />
        <Field
          label="Phone (optional)"
          name="phoneNumber"
          type="tel"
          inputMode="tel"
          autoComplete="tel"
          value={phoneNumber}
          onChange={(e) => setPhoneNumber(e.target.value)}
        />
        <div className="flex flex-col gap-lg sm:flex-row">
          <div className="flex-1">
            <Field
              label="City (optional)"
              name="shopCity"
              autoComplete="address-level2"
              value={shopCity}
              onChange={(e) => setShopCity(e.target.value)}
            />
          </div>
          <div className="flex-1">
            <Field
              label="State (optional)"
              name="shopState"
              autoComplete="address-level1"
              value={shopState}
              onChange={(e) => setShopState(e.target.value)}
            />
          </div>
        </div>
        <SubmitButton loading={submitting}>Create shop</SubmitButton>
      </form>
    </main>
  );
}
