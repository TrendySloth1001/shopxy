"use client";

import { useTranslations } from "next-intl";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { formatINR2 } from "@/shared/money";

export type PreviewLine = {
  name: string;
  quantityLabel: string;
  amount: number;
};

export type PreviewTotal = { label: string; value: string; emphasis?: boolean };

export type InvoicePreview = {
  documentTypeLabel: string;
  counterpartyLabel: string;
  counterpartyName: string;
  counterpartyAddress: string | null;
  placeOfSupply: string | null;
  supplyTypeLabel: string;
  lines: PreviewLine[];
  totals: PreviewTotal[];
};

export function InvoicePreviewModal({
  preview,
  busy,
  onCancel,
  onConfirm,
}: {
  preview: InvoicePreview;
  busy: boolean;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  const t = useTranslations("invoices");

  return (
    <Modal title={t("preview.title")} onClose={onCancel} wide>
      <p className="text-body-sm text-muted">{t("preview.subtitle")}</p>

      <div className="mt-lg">
        <span className="inline-flex items-center rounded-full bg-brand-soft px-md py-xs text-label-md font-semibold text-brand-strong">
          {preview.documentTypeLabel}
        </span>
      </div>

      <div className="mt-lg grid grid-cols-1 gap-lg sm:grid-cols-2">
        <div>
          <p className="text-label-md uppercase tracking-wide text-subtle">
            {preview.counterpartyLabel}
          </p>
          <p className="mt-xs text-body-md font-semibold text-ink">
            {preview.counterpartyName}
          </p>
          <p
            className={`text-body-sm ${
              preview.counterpartyAddress ? "text-muted" : "text-warning"
            }`}
          >
            {preview.counterpartyAddress ?? t("preview.noAddress")}
          </p>
        </div>
        {preview.placeOfSupply ? (
          <div>
            <p className="text-label-md uppercase tracking-wide text-subtle">
              {t("form.placeOfSupply")}
            </p>
            <p className="mt-xs text-body-md text-ink">
              {preview.placeOfSupply} · {preview.supplyTypeLabel}
            </p>
          </div>
        ) : null}
      </div>

      <div className="mt-xl">
        <p className="text-label-md uppercase tracking-wide text-subtle">
          {preview.lines.length}{" "}
          {preview.lines.length === 1 ? t("list.countOne") : t("list.countOther")}
        </p>
        <div className="mt-xs max-h-64 overflow-y-auto">
          {preview.lines.map((line, i) => (
            <div
              key={`${line.name}-${i}`}
              className="flex items-start gap-md border-b border-hairline py-sm"
            >
              <div className="min-w-0 flex-1">
                <p className="truncate text-body-md text-ink">{line.name}</p>
                <p className="text-body-sm text-muted">{line.quantityLabel}</p>
              </div>
              <span className="shrink-0 text-body-md text-ink">
                {formatINR2(line.amount)}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-lg">
        {preview.totals.map((total) => (
          <div key={total.label} className="flex items-center justify-between py-xs">
            <span
              className={
                total.emphasis
                  ? "text-body-lg font-semibold text-ink"
                  : "text-body-md text-muted"
              }
            >
              {total.label}
            </span>
            <span
              className={
                total.emphasis
                  ? "text-body-lg font-semibold text-ink"
                  : "text-body-md text-ink"
              }
            >
              {total.value}
            </span>
          </div>
        ))}
      </div>

      <ModalActions
        busy={busy}
        confirmLabel={t("preview.confirm")}
        onCancel={onCancel}
        onConfirm={onConfirm}
      />
    </Modal>
  );
}
