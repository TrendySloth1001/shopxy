"use client";

import { useState } from "react";
import type { UserAddress, AddressFormValues } from "../types";

function validate(values: AddressFormValues): Partial<Record<keyof AddressFormValues, string>> {
  const errors: Partial<Record<keyof AddressFormValues, string>> = {};
  if (!values.fullName.trim()) errors.fullName = "Full name is required.";
  if (!values.phone.trim()) {
    errors.phone = "Phone number is required.";
  } else if (!/^\d{10}$/.test(values.phone.trim())) {
    errors.phone = "Enter a 10-digit phone number.";
  }
  if (!values.line1.trim()) errors.line1 = "Address line 1 is required.";
  if (!values.city.trim()) errors.city = "City is required.";
  if (!values.state.trim()) errors.state = "State is required.";
  if (!values.pincode.trim()) {
    errors.pincode = "Pincode is required.";
  } else if (!/^\d{6}$/.test(values.pincode.trim())) {
    errors.pincode = "Enter a 6-digit pincode.";
  }
  return errors;
}

interface AddressFormProps {
  initial?: UserAddress;
  submitLabel?: string;
  onSubmit: (values: AddressFormValues) => Promise<void>;
  onCancel?: () => void;
}

export function AddressForm({
  initial,
  submitLabel = "Save address",
  onSubmit,
  onCancel,
}: AddressFormProps) {
  const [values, setValues] = useState<AddressFormValues>({
    label: initial?.label ?? "",
    fullName: initial?.fullName ?? "",
    phone: initial?.phone ?? "",
    line1: initial?.line1 ?? "",
    line2: initial?.line2 ?? "",
    city: initial?.city ?? "",
    state: initial?.state ?? "",
    pincode: initial?.pincode ?? "",
    landmark: initial?.landmark ?? "",
    isDefault: initial?.isDefault ?? false,
  });
  const [errors, setErrors] = useState<Partial<Record<keyof AddressFormValues, string>>>({});
  const [serverError, setServerError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  function set(field: keyof AddressFormValues, value: string | boolean) {
    setValues((prev) => ({ ...prev, [field]: value }));
    if (errors[field]) {
      setErrors((prev) => {
        const next = { ...prev };
        delete next[field];
        return next;
      });
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const errs = validate(values);
    if (Object.keys(errs).length > 0) {
      setErrors(errs);
      return;
    }
    setSubmitting(true);
    setServerError(null);
    try {
      await onSubmit(values);
    } catch (err) {
      setServerError(err instanceof Error ? err.message : "Something went wrong.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={(e) => { void handleSubmit(e); }} noValidate className="flex flex-col gap-sm">
      <Field label="Label (optional)" error={errors.label}>
        <input
          type="text"
          placeholder="Home, Work, etc."
          value={values.label}
          onChange={(e) => set("label", e.target.value)}
          className={inputCls(!!errors.label)}
        />
      </Field>

      <Field label="Full name" error={errors.fullName} required>
        <input
          type="text"
          placeholder="Recipient name"
          value={values.fullName}
          onChange={(e) => set("fullName", e.target.value)}
          className={inputCls(!!errors.fullName)}
        />
      </Field>

      <Field label="Phone number" error={errors.phone} required>
        <input
          type="tel"
          inputMode="numeric"
          maxLength={10}
          placeholder="10-digit mobile number"
          value={values.phone}
          onChange={(e) => set("phone", e.target.value.replace(/\D/g, ""))}
          className={inputCls(!!errors.phone)}
        />
      </Field>

      <Field label="Address line 1" error={errors.line1} required>
        <input
          type="text"
          placeholder="Flat / house no., building, street"
          value={values.line1}
          onChange={(e) => set("line1", e.target.value)}
          className={inputCls(!!errors.line1)}
        />
      </Field>

      <Field label="Address line 2 (optional)" error={errors.line2}>
        <input
          type="text"
          placeholder="Area, colony, locality"
          value={values.line2}
          onChange={(e) => set("line2", e.target.value)}
          className={inputCls(!!errors.line2)}
        />
      </Field>

      <div className="grid grid-cols-2 gap-sm">
        <Field label="City" error={errors.city} required>
          <input
            type="text"
            placeholder="City"
            value={values.city}
            onChange={(e) => set("city", e.target.value)}
            className={inputCls(!!errors.city)}
          />
        </Field>
        <Field label="State" error={errors.state} required>
          <input
            type="text"
            placeholder="State"
            value={values.state}
            onChange={(e) => set("state", e.target.value)}
            className={inputCls(!!errors.state)}
          />
        </Field>
      </div>

      <Field label="Pincode" error={errors.pincode} required>
        <input
          type="text"
          inputMode="numeric"
          maxLength={6}
          placeholder="6-digit pincode"
          value={values.pincode}
          onChange={(e) => set("pincode", e.target.value.replace(/\D/g, ""))}
          className={inputCls(!!errors.pincode)}
        />
      </Field>

      <Field label="Landmark (optional)" error={errors.landmark}>
        <input
          type="text"
          placeholder="Near a notable landmark"
          value={values.landmark}
          onChange={(e) => set("landmark", e.target.value)}
          className={inputCls(!!errors.landmark)}
        />
      </Field>

      <label className="flex cursor-pointer items-center gap-sm py-xs">
        <input
          type="checkbox"
          checked={values.isDefault}
          onChange={(e) => set("isDefault", e.target.checked)}
          className="h-4 w-4 rounded-xs accent-brand"
        />
        <span className="text-body-sm text-ink">Set as default address</span>
      </label>

      {serverError && (
        <p className="rounded-sm bg-error-soft px-md py-sm text-body-sm text-error">
          {serverError}
        </p>
      )}

      <div className="mt-sm flex items-center gap-sm">
        <button
          type="submit"
          disabled={submitting}
          className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:cursor-not-allowed disabled:opacity-50"
        >
          {submitting ? "Saving…" : submitLabel}
        </button>
        {onCancel && (
          <button
            type="button"
            onClick={onCancel}
            disabled={submitting}
            className="inline-flex h-10 items-center rounded-button border border-hairline bg-white px-lg text-label-md text-ink hover:bg-canvas focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-50"
          >
            Cancel
          </button>
        )}
      </div>
    </form>
  );
}

function Field({
  label,
  error,
  required,
  children,
}: {
  label: string;
  error?: string;
  required?: boolean;
  children: React.ReactNode;
}) {
  return (
    <div className="flex flex-col gap-xs">
      <label className="text-label-lg text-ink">
        {label}
        {required && <span className="ml-xs text-error">*</span>}
      </label>
      {children}
      {error && <p className="text-body-sm text-error">{error}</p>}
    </div>
  );
}

function inputCls(hasError: boolean) {
  return [
    "h-10 w-full rounded-input border bg-white px-md text-body-md text-ink placeholder:text-disabled",
    "focus:outline-none focus:ring-2 focus:ring-brand",
    hasError ? "border-error focus:ring-error" : "border-hairline",
  ].join(" ");
}
