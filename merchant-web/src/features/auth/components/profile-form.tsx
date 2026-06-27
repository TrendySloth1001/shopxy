"use client";

import { useId, useState, type FormEvent } from "react";
import { useAuth } from "../auth-context";
import { updateProfileSchema } from "../schema";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { Banner } from "./banner";
import { AvatarPicker } from "./avatar-picker";

const REGISTRATION_TYPES = ["REGULAR", "COMPOSITION", "UNREGISTERED"] as const;

/**
 * Merchant profile + shop details. Pre-filled from the current user; PATCHes
 * the whole editable set (the backend treats it as a partial update). Shop
 * fields populate the invoice header / GST footer / UPI QR.
 */
export function ProfileForm({ onSaved }: { onSaved?: () => void } = {}) {
  const { user, updateProfile } = useAuth();
  const [values, setValues] = useState({
    name: user?.name ?? "",
    shopName: user?.shopName ?? "",
    shopAddress: user?.shopAddress ?? "",
    shopCity: user?.shopCity ?? "",
    shopState: user?.shopState ?? "",
    shopStateCode: user?.shopStateCode ?? "",
    shopPinCode: user?.shopPinCode ?? "",
    shopGstin: user?.shopGstin ?? "",
    registrationType: user?.registrationType ?? "",
    shopPan: user?.shopPan ?? "",
    upiVpa: user?.upiVpa ?? "",
    phoneNumber: user?.phoneNumber ?? "",
  });
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const regId = useId();

  function set(key: keyof typeof values, value: string) {
    setValues((v) => ({ ...v, [key]: value }));
    setSaved(false);
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSaved(false);
    const candidate = {
      ...values,
      registrationType: values.registrationType || undefined,
    };
    const parsed = updateProfileSchema.safeParse(candidate);
    if (!parsed.success) {
      const flat = parsed.error.flatten().fieldErrors;
      setFieldErrors(
        Object.fromEntries(
          Object.entries(flat).map(([k, v]) => [k, v?.[0] ?? ""]),
        ),
      );
      return;
    }
    setFieldErrors({});
    setSubmitting(true);
    try {
      await updateProfile(parsed.data);
      setSaved(true);
      onSaved?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save your changes.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-lg">
      {error ? <Banner variant="error" message={error} /> : null}
      {saved ? <Banner variant="success" message="Profile saved." /> : null}

      <AvatarPicker />

      <Field
        label="Your name"
        value={values.name}
        onChange={(e) => set("name", e.target.value)}
        error={fieldErrors.name}
      />
      <Field
        label="Shop name"
        value={values.shopName}
        onChange={(e) => set("shopName", e.target.value)}
        error={fieldErrors.shopName}
      />
      <Field
        label="Phone number"
        type="tel"
        value={values.phoneNumber}
        onChange={(e) => set("phoneNumber", e.target.value)}
        error={fieldErrors.phoneNumber}
      />
      <Field
        label="Address"
        value={values.shopAddress}
        onChange={(e) => set("shopAddress", e.target.value)}
        error={fieldErrors.shopAddress}
      />
      <div className="grid grid-cols-2 gap-lg">
        <Field
          label="City"
          value={values.shopCity}
          onChange={(e) => set("shopCity", e.target.value)}
          error={fieldErrors.shopCity}
        />
        <Field
          label="State"
          value={values.shopState}
          onChange={(e) => set("shopState", e.target.value)}
          error={fieldErrors.shopState}
        />
        <Field
          label="State code"
          helper="2-digit GST code"
          value={values.shopStateCode}
          onChange={(e) => set("shopStateCode", e.target.value)}
          error={fieldErrors.shopStateCode}
        />
        <Field
          label="PIN code"
          inputMode="numeric"
          value={values.shopPinCode}
          onChange={(e) => set("shopPinCode", e.target.value)}
          error={fieldErrors.shopPinCode}
        />
      </div>
      <Field
        label="GSTIN"
        value={values.shopGstin}
        onChange={(e) => set("shopGstin", e.target.value)}
        error={fieldErrors.shopGstin}
      />
      <div className="flex flex-col gap-xs">
        <label htmlFor={regId} className="text-label-md text-muted">
          GST registration
        </label>
        <select
          id={regId}
          value={values.registrationType}
          onChange={(e) => set("registrationType", e.target.value)}
          className="w-full rounded-input border border-hairline bg-surface px-md py-sm text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <option value="">Not set</option>
          {REGISTRATION_TYPES.map((t) => (
            <option key={t} value={t}>
              {t.charAt(0) + t.slice(1).toLowerCase()}
            </option>
          ))}
        </select>
      </div>
      <div className="grid grid-cols-2 gap-lg">
        <Field
          label="PAN"
          value={values.shopPan}
          onChange={(e) => set("shopPan", e.target.value)}
          error={fieldErrors.shopPan}
        />
        <Field
          label="UPI ID"
          value={values.upiVpa}
          onChange={(e) => set("upiVpa", e.target.value)}
          error={fieldErrors.upiVpa}
        />
      </div>
      <div className="pt-sm">
        <SubmitButton loading={submitting}>Save changes</SubmitButton>
      </div>
    </form>
  );
}
