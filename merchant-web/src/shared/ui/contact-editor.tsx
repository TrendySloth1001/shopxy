"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { BackLink } from "@/shared/ui/page-header";
import { SelectField, TextAreaField, TextField } from "@/shared/ui/form";
import { INDIAN_STATES, stateCodeForName, stateNameForCode } from "@/shared/india";

export type ContactWrite = {
  name: string;
  contactName: string | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  city: string | null;
  state: string | null;
  stateCode: string | null;
  pinCode: string | null;
  panNumber: string | null;
  gstin: string | null;
};

export type ContactInitial = Partial<ContactWrite>;

const blank = (v?: string | null) => (v ?? "").toString();
const orNull = (v: string) => {
  const t = v.trim();
  return t === "" ? null : t;
};

export function ContactEditor({
  title,
  subtitle,
  nameLabel,
  backHref,
  backLabel,
  isEdit,
  initial,
  onSubmit,
}: {
  title: string;
  subtitle: string;
  nameLabel: string;
  backHref: string;
  backLabel: string;
  isEdit: boolean;
  initial: ContactInitial;
  onSubmit: (values: ContactWrite) => Promise<void>;
}) {
  const t = useTranslations("common");
  const router = useRouter();

  const [name, setName] = useState(blank(initial.name));
  const [contactName, setContactName] = useState(blank(initial.contactName));
  const [phone, setPhone] = useState(blank(initial.phone));
  const [email, setEmail] = useState(blank(initial.email));
  const [gstin, setGstin] = useState(blank(initial.gstin));
  const [pan, setPan] = useState(blank(initial.panNumber));
  const [address, setAddress] = useState(blank(initial.address));
  const [city, setCity] = useState(blank(initial.city));
  const [pinCode, setPinCode] = useState(blank(initial.pinCode));
  const [stateCode, setStateCode] = useState(
    initial.stateCode ?? stateCodeForName(initial.state) ?? "",
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save() {
    setError(null);
    if (!name.trim()) return setError(t("contactEditor.nameRequired", { name: nameLabel.toLowerCase() }));
    const stateName = stateNameForCode(stateCode);
    const values: ContactWrite = {
      name: name.trim(),
      contactName: orNull(contactName),
      phone: orNull(phone),
      email: orNull(email),
      address: orNull(address),
      city: orNull(city),
      state: stateName ?? null,
      stateCode: stateCode || null,
      pinCode: orNull(pinCode),
      panNumber: pan.trim() ? pan.trim().toUpperCase() : null,
      gstin: gstin.trim() ? gstin.trim().toUpperCase() : null,
    };
    setBusy(true);
    try {
      await onSubmit(values);
      router.push(backHref);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("contactEditor.saveFailed"));
      setBusy(false);
    }
  }

  const stateOptions = [
    { value: "", label: t("contactEditor.stateNotSet") },
    ...INDIAN_STATES.map((s) => ({ value: s.code, label: `${s.code} — ${s.name}` })),
  ];

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={backHref} label={backLabel} />
      <h1 className="mt-md text-headline-md text-ink">{title}</h1>
      <p className="mt-xs max-w-content text-body-md text-muted">{subtitle}</p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl flex max-w-content flex-col gap-lg">
        <TextField label={nameLabel} value={name} onChange={setName} placeholder="Acme Traders" />
        <TextField
          label={t("contactField.contactName")}
          value={contactName}
          onChange={setContactName}
          placeholder={t("optional")}
        />

        <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
          <TextField label={t("contactField.phone")} value={phone} onChange={setPhone} inputMode="numeric" />
          <TextField label={t("contactField.email")} value={email} onChange={setEmail} type="email" />
        </div>

        <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
          <TextField label={t("contactField.gstin")} value={gstin} onChange={(v) => setGstin(v.toUpperCase())} />
          <TextField label={t("contactField.panNumber")} value={pan} onChange={(v) => setPan(v.toUpperCase())} />
        </div>

        <TextAreaField label={t("contactField.address")} value={address} onChange={setAddress} rows={2} />

        <div className="grid grid-cols-1 gap-md sm:grid-cols-3">
          <TextField label={t("contactField.city")} value={city} onChange={setCity} />
          <TextField label={t("contactField.pinCode")} value={pinCode} onChange={setPinCode} inputMode="numeric" />
          <SelectField label={t("contactField.state")} value={stateCode} onChange={setStateCode} options={stateOptions} />
        </div>
      </div>

      <div className="sticky bottom-0 mt-xxl -mx-lg flex items-center justify-end gap-md border-t border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
        <Link
          href={backHref}
          className="inline-flex h-11 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink"
        >
          {t("cancel")}
        </Link>
        <button
          type="button"
          onClick={save}
          disabled={busy}
          className="inline-flex h-11 items-center rounded-button bg-brand px-xl text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {busy ? t("saving") : isEdit ? t("saveChanges") : t("contactEditor.addContact", { name: nameLabel.toLowerCase() })}
        </button>
      </div>
    </div>
  );
}
