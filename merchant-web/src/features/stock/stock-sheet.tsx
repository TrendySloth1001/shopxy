"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { TextAreaField, TextField } from "@/shared/ui/form";
import { ComboSelect } from "@/shared/ui/combo-select";
import { listParties } from "@/features/parties/api";
import type { Party } from "@/features/parties/schema";
import { listVendors } from "@/features/vendors/api";
import type { Vendor } from "@/features/vendors/schema";
import { qty } from "@/features/products/format";
import { unitLabel } from "@/features/products/units";
import type { Product } from "@/features/products/schema";
import { createStockTransaction } from "./api";
import type { StockType } from "./schema";

/** number → editable string, blank when zero. */
function priceStr(n: number): string {
  return n > 0 ? String(n) : "";
}

/**
 * Record a stock movement for a product — the web mirror of the Flutter
 * `StockBottomSheet`. Purchase (STOCK_IN, counterparty = a vendor) or Sale
 * (STOCK_OUT, counterparty = a customer). The vendor / customer lists are
 * pre-loaded so the user just selects — no name searching. On submit the
 * backend creates a draft invoice; stock posts when that draft is confirmed.
 */
export function StockSheet({
  product,
  initialType,
  onClose,
  onDone,
}: {
  product: Product;
  initialType: StockType;
  onClose: () => void;
  onDone: (draftInvoiceId: string) => void;
}) {
  const t = useTranslations("stockAdjustments");
  const [type, setType] = useState<StockType>(initialType);
  const [quantity, setQuantity] = useState("");
  const [unitPrice, setUnitPrice] = useState(
    priceStr(initialType === "STOCK_IN" ? product.purchasePrice : product.sellingPrice),
  );
  const [vendorId, setVendorId] = useState("");
  const [partyId, setPartyId] = useState("");
  const [note, setNote] = useState("");

  const [vendors, setVendors] = useState<Vendor[]>([]);
  const [parties, setParties] = useState<Party[]>([]);
  const [loadingOpts, setLoadingOpts] = useState(true);

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Pre-load the counterparty options whenever the movement type changes.
  // Suppliers come from the full vendor list (not just past purchases), so a
  // freshly-added vendor is selectable straight away.
  useEffect(() => {
    let active = true;
    void (async () => {
      setLoadingOpts(true);
      try {
        if (type === "STOCK_IN") {
          const vs = await listVendors();
          if (active) setVendors(vs);
        } else {
          const ps = await listParties();
          if (active) {
            setParties(ps);
            // Default to Walk-in Customer (or the first party) like the app.
            setPartyId((cur) => {
              if (cur) return cur;
              const fallback = ps.find((p) => p.name === "Walk-in Customer") ?? ps[0];
              return fallback ? String(fallback.id) : "";
            });
          }
        }
      } catch {
        /* selection is optional — leave the dropdown empty on failure */
      } finally {
        if (active) setLoadingOpts(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [type, product.id]);

  function switchType(next: StockType) {
    if (next === type) return;
    setType(next);
    setUnitPrice(priceStr(next === "STOCK_IN" ? product.purchasePrice : product.sellingPrice));
    setVendorId("");
    setPartyId("");
    setError(null);
  }

  const quantityNum = Number(quantity);
  const unitPriceNum = Number(unitPrice);
  const quantityOk = Number.isFinite(quantityNum) && quantityNum > 0;
  // Unit price is required for a purchase, optional for a sale.
  const priceOk =
    type === "STOCK_OUT" ||
    (unitPrice.trim() !== "" && Number.isFinite(unitPriceNum) && unitPriceNum >= 0);
  const valid = quantityOk && priceOk;

  async function submit() {
    setError(null);
    if (!quantityOk) return setError(t("stockSheet.errorQuantity"));
    if (!priceOk) return setError(t("stockSheet.errorPrice"));
    setBusy(true);
    try {
      const res = await createStockTransaction({
        productId: product.id,
        type,
        quantity: quantityNum,
        unitPrice: unitPrice.trim() !== "" && Number.isFinite(unitPriceNum) ? unitPriceNum : undefined,
        vendorId: type === "STOCK_IN" && vendorId ? vendorId : undefined,
        partyId: type === "STOCK_OUT" && partyId ? partyId : undefined,
        note: note.trim() || undefined,
      });
      onDone(res.draftInvoice.id);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("stockSheet.errorRecord"));
    } finally {
      setBusy(false);
    }
  }

  const unit = unitLabel(product.unit);

  return (
    <Modal title={t("stockSheet.title")} onClose={onClose}>
      <p className="text-body-md text-muted">
        {product.name} · {t("stockSheet.inStock", { qty: qty(product.stockQuantity), unit })}
      </p>

      {/* Purchase / Sale toggle */}
      <div className="flex items-center gap-sm">
        <TypeTab label={t("stockSheet.purchaseTab")} active={type === "STOCK_IN"} onClick={() => switchType("STOCK_IN")} />
        <TypeTab label={t("stockSheet.saleTab")} active={type === "STOCK_OUT"} onClick={() => switchType("STOCK_OUT")} />
      </div>

      {error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="grid grid-cols-2 gap-md">
        <TextField
          label={t("stockSheet.quantityLabel", { unit })}
          value={quantity}
          onChange={setQuantity}
          inputMode="decimal"
          placeholder="0"
        />
        <TextField
          label={type === "STOCK_IN" ? t("stockSheet.purchasePriceLabel") : t("stockSheet.salePriceLabel")}
          value={unitPrice}
          onChange={setUnitPrice}
          inputMode="decimal"
          placeholder="0.00"
          helper={type === "STOCK_OUT" ? t("stockSheet.optional") : undefined}
        />
      </div>

      {type === "STOCK_IN" ? (
        <ComboSelect
          label={t("stockSheet.supplierLabel")}
          value={vendorId}
          onChange={setVendorId}
          placeholder={loadingOpts ? t("stockSheet.loadingVendors") : t("stockSheet.selectSupplier")}
          searchable={vendors.length > 6}
          emptyText={t("stockSheet.noVendors")}
          helper={t("stockSheet.supplierHelper")}
          options={vendors.map((v) => ({
            value: String(v.id),
            label: v.name,
            hint: v.phone ?? undefined,
          }))}
        />
      ) : (
        <ComboSelect
          label={t("stockSheet.customerLabel")}
          value={partyId}
          onChange={setPartyId}
          placeholder={loadingOpts ? t("stockSheet.loadingCustomers") : t("stockSheet.selectCustomer")}
          searchable={parties.length > 6}
          emptyText={t("stockSheet.noCustomers")}
          helper={t("stockSheet.customerHelper")}
          options={parties.map((p) => ({ value: String(p.id), label: p.name }))}
        />
      )}

      <TextAreaField label={t("stockSheet.noteLabel")} value={note} onChange={setNote} rows={2} />

      <p className="text-body-sm text-subtle">
        {t("stockSheet.draftHint")}
      </p>

      <ModalActions
        busy={busy}
        disabled={!valid || loadingOpts}
        confirmLabel={t("stockSheet.createDraft")}
        onCancel={onClose}
        onConfirm={submit}
      />
    </Modal>
  );
}

function TypeTab({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
        active ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
      }`}
    >
      {label}
    </button>
  );
}
