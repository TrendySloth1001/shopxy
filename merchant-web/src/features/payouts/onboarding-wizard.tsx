"use client";

import { useState } from "react";
import { ArrowLeft, ArrowRight, CheckCircle2, Loader2, ShieldCheck } from "@/shared/icons";
import { useTranslations } from "next-intl";
import { TextField, SelectField } from "@/shared/ui/form";
import { onboardingSchema, startOnboarding, type OnboardingInput } from "./api";

const BUSINESS_TYPE_VALUES = [
  "proprietorship",
  "partnership",
  "private_limited",
  "public_limited",
  "llp",
  "trust",
  "society",
  "ngo",
  "individual",
  "not_yet_registered",
] as const;

const CATEGORY_VALUES = [
  "ecommerce",
  "retail",
  "services",
  "food_and_beverage",
  "education",
  "healthcare",
  "others",
] as const;

type Field =
  | "legalBusinessName" | "customerFacingBusinessName" | "contactName" | "email" | "phone"
  | "businessType" | "category" | "pan" | "gst"
  | "street1" | "street2" | "city" | "state" | "postalCode"
  | "beneficiaryName" | "bankAccountNumber" | "bankIfsc";

const STEPS: { key: string; fields: Field[] }[] = [
  { key: "business", fields: ["legalBusinessName", "customerFacingBusinessName", "contactName", "email", "phone", "businessType", "category"] },
  { key: "identity", fields: ["pan", "gst"] },
  { key: "address", fields: ["street1", "street2", "city", "state", "postalCode"] },
  { key: "bank", fields: ["beneficiaryName", "bankAccountNumber", "bankIfsc"] },
];

const EMPTY: Record<Field, string> = {
  legalBusinessName: "", customerFacingBusinessName: "", contactName: "", email: "", phone: "",
  businessType: "proprietorship", category: "ecommerce", pan: "", gst: "",
  street1: "", street2: "", city: "", state: "", postalCode: "",
  beneficiaryName: "", bankAccountNumber: "", bankIfsc: "",
};

function toPayload(v: Record<Field, string>): OnboardingInput {
  return {
    legalBusinessName: v.legalBusinessName,
    customerFacingBusinessName: v.customerFacingBusinessName || undefined,
    contactName: v.contactName,
    email: v.email,
    phone: v.phone,
    businessType: v.businessType,
    category: v.category,
    pan: v.pan,
    gst: v.gst || undefined,
    registeredAddress: {
      street1: v.street1,
      street2: v.street2 || undefined,
      city: v.city,
      state: v.state,
      postalCode: v.postalCode,
      country: "IN",
    },
    beneficiaryName: v.beneficiaryName,
    bankAccountNumber: v.bankAccountNumber,
    bankIfsc: v.bankIfsc,
  };
}

/** Map zod issues → a flat {field: message} map (address subfields flattened). */
function validate(v: Record<Field, string>): Partial<Record<Field, string>> {
  const res = onboardingSchema.safeParse(toPayload(v));
  if (res.success) return {};
  const errors: Partial<Record<Field, string>> = {};
  for (const issue of res.error.issues) {
    const key = (issue.path[issue.path.length - 1] as Field) ?? null;
    if (key && !errors[key]) errors[key] = issue.message;
  }
  return errors;
}

/**
 * Razorpay Route KYC onboarding on the web — the 4-step wizard mirroring the
 * mobile app (Business → Identity → Address → Bank). PAN/GST/bank are forwarded
 * to Razorpay by the backend and never stored on the web.
 */
export function OnboardingWizard({ onLinked }: { onLinked: () => void }) {
  const t = useTranslations("payouts");
  const [v, setV] = useState<Record<Field, string>>(EMPTY);
  const [step, setStep] = useState(0);
  const [errors, setErrors] = useState<Partial<Record<Field, string>>>({});
  const [busy, setBusy] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const businessTypeOptions = BUSINESS_TYPE_VALUES.map((value) => ({ value, label: t(`onboarding.businessType.${value}`) }));
  const categoryOptions = CATEGORY_VALUES.map((value) => ({ value, label: t(`onboarding.category.${value}`) }));

  const set = (f: Field) => (val: string) => setV((prev) => ({ ...prev, [f]: val }));
  const stepFields = STEPS[step].fields;

  function next() {
    const all = validate(v);
    const stepErrors: Partial<Record<Field, string>> = {};
    for (const f of stepFields) if (all[f]) stepErrors[f] = all[f];
    if (Object.keys(stepErrors).length > 0) {
      setErrors(stepErrors);
      return;
    }
    setErrors({});
    setStep((s) => Math.min(STEPS.length - 1, s + 1));
  }

  async function submit() {
    const all = validate(v);
    if (Object.keys(all).length > 0) {
      setErrors(all);
      // Jump to the earliest step with an error.
      const bad = STEPS.findIndex((st) => st.fields.some((f) => all[f]));
      if (bad >= 0) setStep(bad);
      return;
    }
    setBusy(true);
    setSubmitError(null);
    try {
      await startOnboarding(toPayload(v));
      onLinked();
    } catch (e) {
      setSubmitError(e instanceof Error ? e.message : t("onboarding.errors.start"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="max-w-content rounded-lg border border-hairline p-lg">
      <div className="flex items-center gap-sm">
        <span className="flex size-9 items-center justify-center rounded-md bg-surface-tint text-ink"><ShieldCheck size={18} /></span>
        <div>
          <p className="text-title-sm font-semibold text-ink">{t("onboarding.title")}</p>
          <p className="text-body-sm text-muted">{t("onboarding.subtitle")}</p>
        </div>
      </div>

      {/* Stepper header */}
      <div className="mt-lg flex items-center gap-xs">
        {STEPS.map((s, i) => (
          <div key={s.key} className="flex flex-1 items-center gap-xs">
            <span className={`flex size-6 shrink-0 items-center justify-center rounded-full text-body-sm ${i < step ? "bg-success text-white" : i === step ? "bg-brand text-white" : "bg-surface-tint text-muted"}`}>
              {i < step ? <CheckCircle2 size={14} /> : i + 1}
            </span>
            <span className={`text-label-md ${i === step ? "text-ink" : "text-muted"}`}>{t(`onboarding.step.${s.key}`)}</span>
            {i < STEPS.length - 1 ? <span className="h-px flex-1 bg-hairline" /> : null}
          </div>
        ))}
      </div>

      <div className="mt-lg grid grid-cols-1 gap-md sm:grid-cols-2">
        {step === 0 ? (
          <>
            <TextField label={t("onboarding.field.legalBusinessName")} value={v.legalBusinessName} onChange={set("legalBusinessName")} error={errors.legalBusinessName} />
            <TextField label={t("onboarding.field.displayName")} value={v.customerFacingBusinessName} onChange={set("customerFacingBusinessName")} />
            <TextField label={t("onboarding.field.contactName")} value={v.contactName} onChange={set("contactName")} error={errors.contactName} />
            <TextField label={t("onboarding.field.email")} value={v.email} onChange={set("email")} type="email" error={errors.email} />
            <TextField label={t("onboarding.field.phone")} value={v.phone} onChange={set("phone")} inputMode="numeric" error={errors.phone} />
            <SelectField label={t("onboarding.field.businessType")} value={v.businessType} onChange={set("businessType")} options={businessTypeOptions} />
            <SelectField label={t("onboarding.field.category")} value={v.category} onChange={set("category")} options={categoryOptions} />
          </>
        ) : null}
        {step === 1 ? (
          <>
            <TextField label={t("onboarding.field.pan")} value={v.pan} onChange={set("pan")} error={errors.pan} helper={t("onboarding.helper.pan")} />
            <TextField label={t("onboarding.field.gstin")} value={v.gst} onChange={set("gst")} error={errors.gst} />
          </>
        ) : null}
        {step === 2 ? (
          <>
            <TextField label={t("onboarding.field.streetAddress")} value={v.street1} onChange={set("street1")} error={errors.street1} />
            <TextField label={t("onboarding.field.streetLine2")} value={v.street2} onChange={set("street2")} />
            <TextField label={t("onboarding.field.city")} value={v.city} onChange={set("city")} error={errors.city} />
            <TextField label={t("onboarding.field.state")} value={v.state} onChange={set("state")} error={errors.state} />
            <TextField label={t("onboarding.field.pinCode")} value={v.postalCode} onChange={set("postalCode")} inputMode="numeric" error={errors.postalCode} />
          </>
        ) : null}
        {step === 3 ? (
          <>
            <TextField label={t("onboarding.field.accountHolderName")} value={v.beneficiaryName} onChange={set("beneficiaryName")} error={errors.beneficiaryName} />
            <TextField label={t("onboarding.field.bankAccountNumber")} value={v.bankAccountNumber} onChange={set("bankAccountNumber")} inputMode="numeric" error={errors.bankAccountNumber} />
            <TextField label={t("onboarding.field.ifsc")} value={v.bankIfsc} onChange={set("bankIfsc")} error={errors.bankIfsc} helper={t("onboarding.helper.ifsc")} />
          </>
        ) : null}
      </div>

      {submitError ? <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{submitError}</p> : null}

      <div className="mt-lg flex items-center gap-sm">
        {step > 0 ? (
          <button type="button" onClick={() => setStep((s) => s - 1)} disabled={busy} className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint">
            <ArrowLeft size={15} /> {t("onboarding.back")}
          </button>
        ) : null}
        {step < STEPS.length - 1 ? (
          <button type="button" onClick={next} className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong">
            {t("onboarding.next")} <ArrowRight size={15} />
          </button>
        ) : (
          <button type="button" onClick={() => void submit()} disabled={busy} className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled">
            {busy ? <Loader2 size={15} className="animate-spin" /> : <ShieldCheck size={15} />} {t("onboarding.submit")}
          </button>
        )}
      </div>
    </div>
  );
}
