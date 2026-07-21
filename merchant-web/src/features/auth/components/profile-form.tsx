"use client";

import { useState, type FormEvent } from "react";
import { useTranslations } from "next-intl";
import { useAuth } from "../auth-context";
import { updateProfileSchema } from "../schema";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { Banner } from "./banner";
import { AvatarPicker } from "./avatar-picker";
import { ComboSelect } from "@/shared/ui/combo-select";

const REGISTRATION_TYPES = ["REGULAR", "COMPOSITION", "UNREGISTERED"] as const;

/**
 * Merchant profile + shop details. Pre-filled from the current user; PATCHes
 * the whole editable set (the backend treats it as a partial update). Shop
 * fields populate the invoice header / GST footer / UPI QR.
 */
export function ProfileForm({ onSaved }: { onSaved?: () => void } = {}) {
  const { user, updateProfile } = useAuth();
  const t = useTranslations("auth");
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
      setError(err instanceof Error ? err.message : t("profile.saveFailed"));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-lg">
      {error ? <Banner variant="error" message={error} /> : null}
      {saved ? <Banner variant="success" message={t("profile.saved")} /> : null}

      <AvatarPicker />

      <Field
        label={t("field.yourName")}
        value={values.name}
        onChange={(e) => set("name", e.target.value)}
        error={fieldErrors.name}
      />
      <Field
        label={t("field.shopName")}
        value={values.shopName}
        onChange={(e) => set("shopName", e.target.value)}
        error={fieldErrors.shopName}
      />
      <Field
        label={t("field.phoneNumber")}
        type="tel"
        value={values.phoneNumber}
        onChange={(e) => set("phoneNumber", e.target.value)}
        error={fieldErrors.phoneNumber}
      />
      <Field
        label={t("field.address")}
        value={values.shopAddress}
        onChange={(e) => set("shopAddress", e.target.value)}
        error={fieldErrors.shopAddress}
      />
      <div className="grid grid-cols-2 gap-lg">
        <Field
          label={t("field.city")}
          value={values.shopCity}
          onChange={(e) => set("shopCity", e.target.value)}
          error={fieldErrors.shopCity}
        />
        <Field
          label={t("field.state")}
          value={values.shopState}
          onChange={(e) => set("shopState", e.target.value)}
          error={fieldErrors.shopState}
        />
        <Field
          label={t("field.stateCode")}
          helper={t("field.stateCodeHelper")}
          value={values.shopStateCode}
          onChange={(e) => set("shopStateCode", e.target.value)}
          error={fieldErrors.shopStateCode}
        />
        <Field
          label={t("field.pinCode")}
          inputMode="numeric"
          value={values.shopPinCode}
          onChange={(e) => set("shopPinCode", e.target.value)}
          error={fieldErrors.shopPinCode}
        />
      </div>
      <Field
        label={t("field.gstin")}
        value={values.shopGstin}
        onChange={(e) => set("shopGstin", e.target.value)}
        error={fieldErrors.shopGstin}
      />
      <ComboSelect
        label={t("field.gstRegistration")}
        value={values.registrationType}
        onChange={(v) => set("registrationType", v)}
        options={[
          { value: "", label: t("common.notSet") },
          ...REGISTRATION_TYPES.map((rt) => ({
            value: rt,
            label: t(`regType.${rt}`),
          })),
        ]}
        className="w-full"
      />
      <div className="grid grid-cols-2 gap-lg">
        <Field
          label={t("field.pan")}
          value={values.shopPan}
          onChange={(e) => set("shopPan", e.target.value)}
          error={fieldErrors.shopPan}
        />
        <Field
          label={t("field.upiId")}
          value={values.upiVpa}
          onChange={(e) => set("upiVpa", e.target.value)}
          error={fieldErrors.upiVpa}
        />
      </div>
      <div className="pt-sm">
        <SubmitButton loading={submitting}>{t("profile.saveChanges")}</SubmitButton>
      </div>
    </form>
  );
}
