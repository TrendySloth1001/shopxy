"use client";

import { useState } from "react";
import { ArrowLeft, ArrowRight, CheckCircle2, Loader2, ShieldCheck } from "lucide-react";
import { TextField, SelectField } from "@/shared/ui/form";
import { onboardingSchema, startOnboarding, type OnboardingInput } from "./api";

const BUSINESS_TYPES = [
  { value: "proprietorship", label: "Proprietorship" },
  { value: "partnership", label: "Partnership" },
  { value: "private_limited", label: "Private Limited" },
  { value: "public_limited", label: "Public Limited" },
  { value: "llp", label: "LLP" },
  { value: "trust", label: "Trust" },
  { value: "society", label: "Society" },
  { value: "ngo", label: "NGO" },
  { value: "individual", label: "Individual" },
  { value: "not_yet_registered", label: "Not yet registered" },
] as const;

const CATEGORIES = [
  { value: "ecommerce", label: "E-commerce" },
  { value: "retail", label: "Retail" },
  { value: "services", label: "Services" },
  { value: "food_and_beverage", label: "Food & beverage" },
  { value: "education", label: "Education" },
  { value: "healthcare", label: "Healthcare" },
  { value: "others", label: "Others" },
] as const;

type Field =
  | "legalBusinessName" | "customerFacingBusinessName" | "contactName" | "email" | "phone"
  | "businessType" | "category" | "pan" | "gst"
  | "street1" | "street2" | "city" | "state" | "postalCode"
  | "beneficiaryName" | "bankAccountNumber" | "bankIfsc";

const STEPS: { title: string; fields: Field[] }[] = [
  { title: "Business", fields: ["legalBusinessName", "customerFacingBusinessName", "contactName", "email", "phone", "businessType", "category"] },
  { title: "Identity", fields: ["pan", "gst"] },
  { title: "Address", fields: ["street1", "street2", "city", "state", "postalCode"] },
  { title: "Bank", fields: ["beneficiaryName", "bankAccountNumber", "bankIfsc"] },
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
  const [v, setV] = useState<Record<Field, string>>(EMPTY);
  const [step, setStep] = useState(0);
  const [errors, setErrors] = useState<Partial<Record<Field, string>>>({});
  const [busy, setBusy] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

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
      setSubmitError(e instanceof Error ? e.message : "Could not start onboarding.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="max-w-content rounded-lg border border-hairline p-lg">
      <div className="flex items-center gap-sm">
        <span className="flex size-9 items-center justify-center rounded-md bg-surface-tint text-ink"><ShieldCheck size={18} /></span>
        <div>
          <p className="text-title-sm font-semibold text-ink">Set up payouts (KYC)</p>
          <p className="text-body-sm text-muted">New to Razorpay? Onboard here. PAN & bank go straight to the provider — never stored by us.</p>
        </div>
      </div>

      {/* Stepper header */}
      <div className="mt-lg flex items-center gap-xs">
        {STEPS.map((s, i) => (
          <div key={s.title} className="flex flex-1 items-center gap-xs">
            <span className={`flex size-6 shrink-0 items-center justify-center rounded-full text-body-sm ${i < step ? "bg-success text-white" : i === step ? "bg-brand text-white" : "bg-surface-tint text-muted"}`}>
              {i < step ? <CheckCircle2 size={14} /> : i + 1}
            </span>
            <span className={`text-label-md ${i === step ? "text-ink" : "text-muted"}`}>{s.title}</span>
            {i < STEPS.length - 1 ? <span className="h-px flex-1 bg-hairline" /> : null}
          </div>
        ))}
      </div>

      <div className="mt-lg grid grid-cols-1 gap-md sm:grid-cols-2">
        {step === 0 ? (
          <>
            <TextField label="Legal business name" value={v.legalBusinessName} onChange={set("legalBusinessName")} error={errors.legalBusinessName} />
            <TextField label="Display name (optional)" value={v.customerFacingBusinessName} onChange={set("customerFacingBusinessName")} />
            <TextField label="Contact name" value={v.contactName} onChange={set("contactName")} error={errors.contactName} />
            <TextField label="Email" value={v.email} onChange={set("email")} type="email" error={errors.email} />
            <TextField label="Phone" value={v.phone} onChange={set("phone")} inputMode="numeric" error={errors.phone} />
            <SelectField label="Business type" value={v.businessType} onChange={set("businessType")} options={BUSINESS_TYPES} />
            <SelectField label="Category" value={v.category} onChange={set("category")} options={CATEGORIES} />
          </>
        ) : null}
        {step === 1 ? (
          <>
            <TextField label="PAN" value={v.pan} onChange={set("pan")} error={errors.pan} helper="10 chars, e.g. AAACL1234C" />
            <TextField label="GSTIN (optional)" value={v.gst} onChange={set("gst")} error={errors.gst} />
          </>
        ) : null}
        {step === 2 ? (
          <>
            <TextField label="Street address" value={v.street1} onChange={set("street1")} error={errors.street1} />
            <TextField label="Street line 2 (optional)" value={v.street2} onChange={set("street2")} />
            <TextField label="City" value={v.city} onChange={set("city")} error={errors.city} />
            <TextField label="State" value={v.state} onChange={set("state")} error={errors.state} />
            <TextField label="PIN code" value={v.postalCode} onChange={set("postalCode")} inputMode="numeric" error={errors.postalCode} />
          </>
        ) : null}
        {step === 3 ? (
          <>
            <TextField label="Account holder name" value={v.beneficiaryName} onChange={set("beneficiaryName")} error={errors.beneficiaryName} />
            <TextField label="Bank account number" value={v.bankAccountNumber} onChange={set("bankAccountNumber")} inputMode="numeric" error={errors.bankAccountNumber} />
            <TextField label="IFSC" value={v.bankIfsc} onChange={set("bankIfsc")} error={errors.bankIfsc} helper="e.g. HDFC0001234" />
          </>
        ) : null}
      </div>

      {submitError ? <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{submitError}</p> : null}

      <div className="mt-lg flex items-center gap-sm">
        {step > 0 ? (
          <button type="button" onClick={() => setStep((s) => s - 1)} disabled={busy} className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink hover:bg-surface-tint">
            <ArrowLeft size={15} /> Back
          </button>
        ) : null}
        {step < STEPS.length - 1 ? (
          <button type="button" onClick={next} className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong">
            Next <ArrowRight size={15} />
          </button>
        ) : (
          <button type="button" onClick={() => void submit()} disabled={busy} className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled">
            {busy ? <Loader2 size={15} className="animate-spin" /> : <ShieldCheck size={15} />} Submit for KYC
          </button>
        )}
      </div>
    </div>
  );
}
