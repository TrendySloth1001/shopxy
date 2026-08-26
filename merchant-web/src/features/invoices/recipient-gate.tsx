"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { TriangleAlert } from "@/shared/icons";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { SelectField, TextField } from "@/shared/ui/form";
import { INDIAN_STATES, stateNameForCode } from "@/shared/india";

export const NAMED_RECIPIENT_THRESHOLD = 50000;

export type RecipientRequirement = "b2b" | "highValue";

export type RecipientDetails = {
  customerAddress?: string;
  customerCity?: string;
  customerState?: string;
  customerStateCode?: string;
  customerPinCode?: string;
  acknowledgeMissingRecipientDetails?: true;
};

export function checkRecipient(args: {
  type: "SALE" | "PURCHASE";
  documentType: string;
  customerName: string;
  customerGstin: string;
  total: number;
  party: { address?: string | null; city?: string | null; pinCode?: string | null } | null;
}): { requirement: RecipientRequirement; nameMissing: boolean; addressMissing: boolean } | null {
  const { type, documentType, customerName, customerGstin, total, party } = args;
  if (type !== "SALE") return null;
  if (documentType !== "TAX_INVOICE" && documentType !== "BILL_OF_SUPPLY") return null;

  const hasGstin = customerGstin.trim().length > 0;
  const requirement: RecipientRequirement | null = hasGstin
    ? "b2b"
    : total >= NAMED_RECIPIENT_THRESHOLD
      ? "highValue"
      : null;
  if (!requirement) return null;

  const filled = (v?: string | null) => (v ?? "").trim().length > 0;
  const nameMissing = !filled(customerName);
  const addressMissing =
    !filled(party?.address) && !filled(party?.city) && !filled(party?.pinCode);
  if (!nameMissing && !addressMissing) return null;

  return { requirement, nameMissing, addressMissing };
}

export function RecipientGateModal({
  requirement,
  nameMissing,
  addressMissing,
  canSaveToParty,
  initialCity,
  initialStateCode,
  initialPinCode,
  busy,
  onCancel,
  onFill,
  onSkip,
}: {
  requirement: RecipientRequirement;
  nameMissing: boolean;
  addressMissing: boolean;
  canSaveToParty: boolean;
  initialCity?: string | null;
  initialStateCode?: string | null;
  initialPinCode?: string | null;
  busy: boolean;
  onCancel: () => void;
  onFill: (details: RecipientDetails, saveToParty: boolean) => void;
  onSkip: () => void;
}) {
  const t = useTranslations("invoices");
  const [address, setAddress] = useState("");
  const [city, setCity] = useState(initialCity ?? "");
  const [stateCode, setStateCode] = useState(initialStateCode ?? "");
  const [pinCode, setPinCode] = useState(initialPinCode ?? "");
  const [saveToParty, setSaveToParty] = useState(canSaveToParty);
  const [confirmingSkip, setConfirmingSkip] = useState(false);

  const anyFilled =
    address.trim() !== "" || city.trim() !== "" || pinCode.trim() !== "" || stateCode !== "";

  const missing = [
    nameMissing ? t("recipient.missingName") : null,
    addressMissing ? t("recipient.missingAddress") : null,
  ]
    .filter(Boolean)
    .join(" · ");

  if (confirmingSkip) {
    return (
      <Modal title={t("recipient.skipTitle")} onClose={() => setConfirmingSkip(false)}>
        <p className="text-body-md text-muted">{t("recipient.skipBody")}</p>
        <ModalActions
          busy={busy}
          danger
          confirmLabel={t("recipient.skipConfirm")}
          onCancel={() => setConfirmingSkip(false)}
          onConfirm={onSkip}
        />
      </Modal>
    );
  }

  return (
    <Modal title={t("recipient.title")} onClose={onCancel} wide>
      <p className="text-body-md text-muted">
        {requirement === "b2b" ? t("recipient.whyB2b") : t("recipient.whyHighValue")}
      </p>

      <div className="mt-md flex items-start gap-sm rounded-md bg-warning-soft p-md">
        <TriangleAlert size={18} className="mt-px shrink-0 text-warning" />
        <p className="text-body-sm text-ink">
          {t("recipient.missingIntro")} {missing}
        </p>
      </div>

      <div className="mt-lg grid grid-cols-1 gap-md sm:grid-cols-2">
        <div className="sm:col-span-2">
          <TextField label={t("recipient.address")} value={address} onChange={setAddress} />
        </div>
        <TextField label={t("recipient.city")} value={city} onChange={setCity} />
        <TextField label={t("recipient.pin")} value={pinCode} onChange={setPinCode} />
        <div className="sm:col-span-2">
          <SelectField
            label={t("recipient.state")}
            value={stateCode}
            onChange={setStateCode}
            options={[
              { value: "", label: t("form.selectState") },
              ...INDIAN_STATES.map((s) => ({ value: s.code, label: s.name })),
            ]}
          />
        </div>
      </div>

      {canSaveToParty ? (
        <label className="mt-md flex items-start gap-sm text-body-md text-ink">
          <input
            type="checkbox"
            checked={saveToParty}
            onChange={(e) => setSaveToParty(e.target.checked)}
            className="mt-1 size-4 accent-brand"
          />
          <span>
            {t("recipient.saveToParty")}
            <span className="block text-body-sm text-muted">
              {t("recipient.saveToPartyHint")}
            </span>
          </span>
        </label>
      ) : null}

      <div className="mt-lg flex flex-wrap items-center justify-between gap-sm">
        <button
          type="button"
          onClick={() => setConfirmingSkip(true)}
          disabled={busy}
          className="inline-flex h-10 items-center rounded-button px-md text-label-md text-muted underline-offset-2 transition-colors hover:text-ink hover:underline disabled:text-disabled"
        >
          {t("recipient.skip")}
        </button>
        <div className="flex flex-wrap items-center gap-sm">
          <button
            type="button"
            onClick={onCancel}
            disabled={busy}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            {t("recipient.back")}
          </button>
          <button
            type="button"
            disabled={busy || !anyFilled}
            onClick={() =>
              onFill(
                {
                  customerAddress: address.trim() || undefined,
                  customerCity: city.trim() || undefined,
                  customerState: stateNameForCode(stateCode) ?? undefined,
                  customerStateCode: stateCode || undefined,
                  customerPinCode: pinCode.trim() || undefined,
                },
                saveToParty,
              )
            }
            className="inline-flex h-10 items-center rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong disabled:bg-disabled"
          >
            {t("recipient.fillAndContinue")}
          </button>
        </div>
      </div>
    </Modal>
  );
}
