"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { ArrowDownLeft, ArrowUpRight, Package, Plus, Trash2, X } from "@/shared/icons";
import { BackLink } from "@/shared/ui/page-header";
import { SelectField, TextAreaField, TextField } from "@/shared/ui/form";
import { PickerModal } from "@/shared/ui/picker-modal";
import { Monogram } from "@/shared/ui/monogram";
import { formatINR2 } from "@/shared/money";
import { INDIAN_STATES } from "@/shared/india";
import { useAuth } from "@/features/auth/auth-context";
import { listProducts } from "@/features/products/api";
import { listParties } from "@/features/parties/api";
import { listVendors } from "@/features/vendors/api";
import { computeInvoiceTotals, type InvoiceLineDraft } from "./format";
import { SALE_DOC_TYPES, type Invoice } from "./schema";
import { createInvoice, updateInvoice, updateInvoiceStatus, type InvoiceWrite } from "./api";

const BACK = "/dashboard/invoices";

/* Stable loaders — passed to PickerModal whose effect depends on `load`. */
const loadProducts = (s: string) => listProducts({ search: s, limit: "20" }).then((r) => r.data);
const loadParties = (s: string) => listParties(s ? { search: s } : undefined);
const loadVendors = (s: string) => listVendors(s ? { search: s } : undefined);

type Contact = { id: number; name: string; phone?: string | null; gstin?: string | null; stateCode?: string | null };

export function InvoiceEditor({
  existing,
  initialDocumentType,
}: {
  existing?: Invoice;
  /** Pre-select a SALE document type for a fresh editor (e.g. Estimate/Proforma). */
  initialDocumentType?: string;
}) {
  const router = useRouter();
  const t = useTranslations("invoices");
  const { user } = useAuth();
  const shopStateCode = user?.shopStateCode ?? null;
  const isEdit = existing != null;

  const stateOptions = [
    { value: "", label: t("form.selectState") },
    ...INDIAN_STATES.map((s) => ({ value: s.code, label: s.name })),
  ];

  const [type, setType] = useState<"SALE" | "PURCHASE">((existing?.type as "SALE" | "PURCHASE") ?? "SALE");
  const [documentType, setDocumentType] = useState<string>(
    existing?.documentType ?? initialDocumentType ?? "TAX_INVOICE",
  );

  const [party, setParty] = useState<Contact | null>(
    existing?.partyId
      ? { id: existing.partyId, name: existing.customerName ?? t("form.customerFallback"), phone: existing.customerPhone, gstin: existing.customerGstin, stateCode: existing.customerStateCode }
      : null,
  );
  const [vendor, setVendor] = useState<Contact | null>(
    existing?.vendorId
      ? { id: existing.vendorId, name: existing.vendorName ?? t("form.vendorFallback"), phone: existing.vendorPhone, gstin: existing.vendorGstin, stateCode: existing.vendorStateCode }
      : null,
  );

  const [walkInName, setWalkInName] = useState(existing && !existing.partyId ? (existing.customerName ?? "") : "");
  const [walkInPhone, setWalkInPhone] = useState(existing?.customerPhone ?? "");
  const [walkInGstin, setWalkInGstin] = useState(existing?.customerGstin ?? "");
  const [walkInStateCode, setWalkInStateCode] = useState(
    existing?.placeOfSupplyStateCode ?? existing?.customerStateCode ?? shopStateCode ?? "",
  );

  const [lines, setLines] = useState<InvoiceLineDraft[]>(
    existing?.items.map((it) => ({
      productId: it.productId,
      productName: it.productName ?? t("form.productFallback"),
      productSku: it.productSku ?? "",
      hsn: it.hsn ?? null,
      unit: it.unit ?? "PCS",
      quantity: it.quantity,
      unitPrice: it.unitPrice,
      taxPercent: it.taxPercent,
    })) ?? [],
  );

  const [discount, setDiscount] = useState(existing && existing.discount > 0 ? String(existing.discount) : "");
  const [note, setNote] = useState(existing?.note ?? "");
  const [picker, setPicker] = useState<"product" | "party" | "vendor" | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const placeOfSupply =
    type === "SALE" ? (party?.stateCode ?? (walkInStateCode || null)) : (vendor?.stateCode ?? null);
  const interstate = !!shopStateCode && !!placeOfSupply && shopStateCode !== placeOfSupply;

  const totals = useMemo(
    () => computeInvoiceTotals(lines, Number(discount) || 0, interstate),
    [lines, discount, interstate],
  );

  function addProduct(p: Awaited<ReturnType<typeof loadProducts>>[number]) {
    setPicker(null);
    setLines((prev) => {
      const idx = prev.findIndex((l) => l.productId === p.id);
      if (idx >= 0) {
        const next = [...prev];
        next[idx] = { ...next[idx], quantity: next[idx].quantity + 1 };
        return next;
      }
      return [
        ...prev,
        {
          productId: p.id,
          productName: p.name,
          productSku: p.sku,
          hsn: p.hsnCode ?? null,
          unit: p.unit,
          quantity: 1,
          unitPrice: type === "SALE" ? p.sellingPrice : p.purchasePrice,
          taxPercent: p.taxPercent,
        },
      ];
    });
  }

  function patchLine(i: number, patch: Partial<InvoiceLineDraft>) {
    setLines((prev) => prev.map((l, idx) => (idx === i ? { ...l, ...patch } : l)));
  }

  function removeLine(i: number) {
    setLines((prev) => prev.filter((_, idx) => idx !== i));
  }

  function buildPayload(confirm: boolean): InvoiceWrite | string {
    if (lines.length === 0) return t("errors.noItems");
    if (type === "PURCHASE" && !vendor) return t("errors.needVendor");
    if (lines.some((l) => l.quantity <= 0)) return t("errors.qtyPositive");
    if (lines.some((l) => l.unitPrice < 0)) return t("errors.rateNegative");
    if (lines.some((l) => l.taxPercent < 0 || l.taxPercent > 100)) {
      return t("errors.gstRange");
    }
    if ((Number(discount) || 0) < 0) return t("errors.discountNegative");
    const payload: InvoiceWrite = {
      type,
      documentType: type === "SALE" ? documentType : "TAX_INVOICE",
      items: lines.map((l) => ({
        productId: l.productId,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        taxPercent: l.taxPercent,
      })),
      discount: Number(discount) || 0,
      note: note.trim() || undefined,
      confirm,
    };
    if (placeOfSupply) payload.placeOfSupplyStateCode = placeOfSupply;
    if (type === "SALE") {
      if (party) payload.partyId = party.id;
      else {
        payload.customerName = walkInName.trim() || t("form.walkInDefault");
        if (walkInPhone.trim()) payload.customerPhone = walkInPhone.trim();
        if (walkInGstin.trim()) payload.customerGstin = walkInGstin.trim();
      }
    } else if (vendor) {
      payload.vendorId = vendor.id;
    }
    return payload;
  }

  async function save(confirm: boolean) {
    setError(null);
    const payload = buildPayload(confirm);
    if (typeof payload === "string") return setError(payload);
    setSaving(true);
    try {
      if (isEdit) {
        await updateInvoice(existing.id, payload);
        if (confirm) await updateInvoiceStatus(existing.id, "CONFIRMED");
        router.push(`/dashboard/invoices/${existing.id}`);
      } else {
        const result = await createInvoice(payload);
        if (confirm && !result.confirmed) {
          // The invoice saved as a draft but auto-confirm failed — hand the
          // message to the detail page (we navigate away, so local state dies).
          try {
            sessionStorage.setItem(
              `invoice-confirm-error-${result.invoice.id}`,
              result.confirmError ?? t("errors.confirmFailed"),
            );
          } catch {
            /* storage unavailable — the draft badge still tells the story */
          }
        }
        router.push(`/dashboard/invoices/${result.invoice.id}`);
      }
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("errors.saveFailed"));
      setSaving(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label={t("detail.back")} />
      <h1 className="mt-md text-headline-md text-ink">
        {isEdit ? t("form.editTitle") : t("form.newTitle")}
      </h1>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {/* Type */}
      <div className="mt-xl">
        <p className="text-label-md uppercase tracking-wide text-subtle">{t("form.typeLabel")}</p>
        <div className="mt-sm flex flex-wrap items-center gap-sm">
          <TypeChip
            active={type === "SALE"}
            disabled={isEdit}
            icon={<ArrowUpRight size={16} />}
            label={t("detail.sale")}
            onClick={() => {
              setType("SALE");
              setVendor(null);
            }}
          />
          <TypeChip
            active={type === "PURCHASE"}
            disabled={isEdit}
            icon={<ArrowDownLeft size={16} />}
            label={t("detail.purchase")}
            onClick={() => {
              setType("PURCHASE");
              setParty(null);
            }}
          />
        </div>
      </div>

      {/* Counterparty */}
      <div className="mt-xl">
        <p className="text-label-md uppercase tracking-wide text-subtle">
          {type === "SALE" ? t("form.customer") : t("form.vendor")}
        </p>
        {type === "SALE" ? (
          party ? (
            <SelectedContact contact={party} onChange={() => setPicker("party")} onClear={() => setParty(null)} />
          ) : (
            <div className="mt-sm flex flex-col gap-sm">
              <button
                type="button"
                onClick={() => setPicker("party")}
                className="inline-flex h-10 w-fit items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
              >
                <Plus size={16} /> {t("form.selectSavedCustomer")}
              </button>
              <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
                <TextField label={t("form.walkInName")} value={walkInName} onChange={setWalkInName} placeholder={t("form.walkInDefault")} />
                <TextField label={t("form.phone")} value={walkInPhone} onChange={setWalkInPhone} type="tel" />
                <TextField label="GSTIN" value={walkInGstin} onChange={(v) => setWalkInGstin(v.toUpperCase())} />
                <SelectField label={t("form.placeOfSupply")} value={walkInStateCode} onChange={setWalkInStateCode} options={stateOptions} />
              </div>
            </div>
          )
        ) : vendor ? (
          <SelectedContact contact={vendor} onChange={() => setPicker("vendor")} onClear={() => setVendor(null)} />
        ) : (
          <button
            type="button"
            onClick={() => setPicker("vendor")}
            className="mt-sm inline-flex h-10 w-fit items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Plus size={16} /> {t("form.selectVendor")}
          </button>
        )}
      </div>

      {/* Items */}
      <div className="mt-xl">
        <div className="flex flex-wrap items-center justify-between gap-sm">
          <p className="text-label-md uppercase tracking-wide text-subtle">{t("detail.items")}</p>
          <button
            type="button"
            onClick={() => setPicker("product")}
            className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Plus size={15} /> {t("form.addProduct")}
          </button>
        </div>

        {lines.length === 0 ? (
          <div className="mt-md flex flex-col items-center gap-sm py-xl text-center">
            <Package size={22} className="text-subtle" />
            <p className="text-body-sm text-subtle">{t("form.noItems")}</p>
          </div>
        ) : (
          <div className="mt-md">
            {lines.map((l, i) => (
              <LineRow
                key={l.productId}
                line={l}
                onQty={(v) => patchLine(i, { quantity: v })}
                onPrice={(v) => patchLine(i, { unitPrice: v })}
                onTax={(v) => patchLine(i, { taxPercent: v })}
                onRemove={() => removeLine(i)}
              />
            ))}
          </div>
        )}
      </div>

      {/* Totals + meta */}
      {lines.length > 0 ? (
        <div className="mt-xl grid grid-cols-1 gap-xl lg:grid-cols-2">
          <div className="flex flex-col gap-md">
            {type === "SALE" ? (
              <SelectField
                label={t("form.documentType")}
                value={documentType}
                onChange={setDocumentType}
                options={SALE_DOC_TYPES.map((d) => ({ value: d, label: t(`docType.${d}`) }))}
              />
            ) : null}
            <TextField label={t("form.discountLabel")} value={discount} onChange={setDiscount} inputMode="decimal" placeholder="0" helper={t("form.discountHelper")} />
            <TextAreaField label={t("form.noteLabel")} value={note} onChange={setNote} rows={2} />
          </div>

          <div className="border-t border-hairline pt-md lg:border-t-0 lg:pt-0">
            <TotalRow label={t("totals.subtotal")} value={totals.subtotal} />
            {totals.discount > 0 ? <TotalRow label={t("totals.discount")} value={-totals.discount} /> : null}
            {interstate ? (
              <TotalRow label="IGST" value={totals.igst} />
            ) : (
              <>
                <TotalRow label="CGST" value={totals.cgst} />
                <TotalRow label="SGST" value={totals.sgst} />
              </>
            )}
            {Math.abs(totals.roundOff) >= 0.005 ? <TotalRow label={t("totals.roundOff")} value={totals.roundOff} /> : null}
            <div className="mt-sm flex items-center justify-between border-t border-hairline pt-sm">
              <span className="text-title-md text-ink">{t("totals.total")}</span>
              <span className="text-title-lg font-bold text-ink">{formatINR2(totals.total)}</span>
            </div>
          </div>
        </div>
      ) : null}

      {/* Actions */}
      <div className="mt-xxl flex flex-wrap items-center gap-sm">
        <button
          type="button"
          onClick={() => save(false)}
          disabled={saving}
          className="inline-flex h-11 items-center gap-sm rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          {isEdit ? t("form.updateDraft") : t("form.saveDraft")}
        </button>
        <button
          type="button"
          onClick={() => save(true)}
          disabled={saving}
          className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {saving ? t("form.saving") : isEdit ? t("form.updateConfirm") : t("form.saveConfirm")}
        </button>
      </div>

      {/* Pickers */}
      {picker === "product" ? (
        <PickerModal
          title={t("form.addProduct")}
          placeholder={t("picker.searchProducts")}
          load={loadProducts}
          rowOf={(p) => ({
            title: p.name,
            subtitle: `${p.sku}${p.unit ? ` · ${p.unit}` : ""} · ${t("picker.stock")} ${p.stockQuantity}`,
            meta: formatINR2(type === "SALE" ? p.sellingPrice : p.purchasePrice),
          })}
          onPick={addProduct}
          onClose={() => setPicker(null)}
          emptyHint={t("picker.noProducts")}
        />
      ) : null}
      {picker === "party" ? (
        <PickerModal
          title={t("picker.selectCustomer")}
          placeholder={t("picker.searchCustomers")}
          load={loadParties}
          rowOf={(p) => ({ title: p.name, subtitle: p.phone ?? p.gstin ?? undefined })}
          onPick={(p) => {
            setParty({ id: p.id, name: p.name, phone: p.phone, gstin: p.gstin, stateCode: p.stateCode });
            setPicker(null);
          }}
          onClose={() => setPicker(null)}
        />
      ) : null}
      {picker === "vendor" ? (
        <PickerModal
          title={t("form.selectVendor")}
          placeholder={t("picker.searchVendors")}
          load={loadVendors}
          rowOf={(v) => ({ title: v.name, subtitle: v.phone ?? v.gstin ?? undefined })}
          onPick={(v) => {
            setVendor({ id: v.id, name: v.name, phone: v.phone, gstin: v.gstin, stateCode: v.stateCode });
            setPicker(null);
          }}
          onClose={() => setPicker(null)}
        />
      ) : null}
    </div>
  );
}

function TypeChip({
  active,
  disabled,
  icon,
  label,
  onClick,
}: {
  active: boolean;
  disabled?: boolean;
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={`inline-flex h-10 items-center gap-sm rounded-button px-md text-label-md transition-colors disabled:cursor-not-allowed ${
        active
          ? "bg-brand text-white"
          : "border border-hairline text-ink hover:bg-surface-tint disabled:text-disabled"
      } ${active && disabled ? "opacity-90" : ""}`}
    >
      {icon} {label}
    </button>
  );
}

function SelectedContact({
  contact,
  onChange,
  onClear,
}: {
  contact: Contact;
  onChange: () => void;
  onClear: () => void;
}) {
  const t = useTranslations("invoices");
  return (
    <div className="mt-sm flex items-center gap-md border-b border-hairline pb-md">
      <Monogram name={contact.name} size={40} />
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{contact.name}</p>
        <p className="truncate text-body-sm text-muted">
          {contact.phone ?? t("form.noPhone")}
          {contact.gstin ? ` · GSTIN ${contact.gstin}` : ""}
        </p>
      </div>
      <button
        type="button"
        onClick={onChange}
        className="inline-flex h-9 items-center rounded-button px-md text-label-md text-brand-strong transition-colors hover:bg-brand-soft"
      >
        {t("form.change")}
      </button>
      <button
        type="button"
        onClick={onClear}
        aria-label={t("form.clear")}
        className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
      >
        <X size={15} />
      </button>
    </div>
  );
}

const numInput =
  "h-9 w-full rounded-input border border-hairline bg-field px-sm text-right text-body-sm text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

function LineRow({
  line,
  onQty,
  onPrice,
  onTax,
  onRemove,
}: {
  line: InvoiceLineDraft;
  onQty: (v: number) => void;
  onPrice: (v: number) => void;
  onTax: (v: number) => void;
  onRemove: () => void;
}) {
  const t = useTranslations("invoices");
  // Pre-tax line amount (qty × rate), matching the "Subtotal" total and the
  // Flutter editor. We deliberately do NOT add tax or fold in the header
  // discount here: the header discount is apportioned across lines at the
  // totals level (computeInvoiceTotals), so showing a gross tax-on-top figure
  // per line wouldn't reconcile to the displayed Total. With this basis,
  // Σ(line amounts) = Subtotal, then − Discount + GST = Total. (FMD-5.)
  const lineAmount = line.quantity * line.unitPrice;
  return (
    <div className="flex flex-wrap items-end gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{line.productName}</p>
        <p className="truncate text-body-sm text-muted">
          {line.productSku || "—"}
          {line.hsn ? ` · HSN ${line.hsn}` : ""}
        </p>
      </div>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-subtle">{t("form.qty")}</span>
        <input
          inputMode="decimal"
          value={line.quantity}
          onChange={(e) => onQty(Number(e.target.value) || 0)}
          className={`${numInput} w-16`}
        />
      </label>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-subtle">{t("form.rate")}</span>
        <input
          inputMode="decimal"
          value={line.unitPrice}
          onChange={(e) => onPrice(Number(e.target.value) || 0)}
          className={`${numInput} w-24`}
        />
      </label>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-subtle">GST %</span>
        <input
          inputMode="decimal"
          value={line.taxPercent}
          onChange={(e) => onTax(Number(e.target.value) || 0)}
          className={`${numInput} w-16`}
        />
      </label>
      <div className="flex flex-col items-end gap-xs">
        <span className="text-label-md text-subtle">{t("form.amountPreTax")}</span>
        <span className="text-body-md font-semibold text-ink">{formatINR2(lineAmount)}</span>
      </div>
      <button
        type="button"
        onClick={onRemove}
        aria-label={t("form.removeItem")}
        className="inline-flex size-9 items-center justify-center rounded-button text-muted transition-colors hover:bg-error-soft hover:text-error"
      >
        <Trash2 size={16} />
      </button>
    </div>
  );
}

function TotalRow({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex items-center justify-between py-xs">
      <span className="text-body-md text-muted">{label}</span>
      <span className="text-body-md tabular-nums text-ink">{formatINR2(value)}</span>
    </div>
  );
}
