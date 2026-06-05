"use client";

import { useEffect, useState } from "react";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { SelectField, TextAreaField, TextField } from "@/shared/ui/form";
import { listParties } from "@/features/parties/api";
import type { Party } from "@/features/parties/schema";
import { qty } from "@/features/products/format";
import { unitLabel } from "@/features/products/units";
import type { Product } from "@/features/products/schema";
import { createStockTransaction, listSuppliers } from "./api";
import type { StockType, SupplierVendor } from "./schema";

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
  onDone: (draftInvoiceId: number) => void;
}) {
  const [type, setType] = useState<StockType>(initialType);
  const [quantity, setQuantity] = useState("");
  const [unitPrice, setUnitPrice] = useState(
    priceStr(initialType === "STOCK_IN" ? product.purchasePrice : product.sellingPrice),
  );
  const [vendorId, setVendorId] = useState("");
  const [partyId, setPartyId] = useState("");
  const [note, setNote] = useState("");

  const [vendors, setVendors] = useState<SupplierVendor[]>([]);
  const [parties, setParties] = useState<Party[]>([]);
  const [loadingOpts, setLoadingOpts] = useState(true);

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Pre-load the counterparty options whenever the movement type changes.
  useEffect(() => {
    let active = true;
    void (async () => {
      setLoadingOpts(true);
      try {
        if (type === "STOCK_IN") {
          let res = await listSuppliers({ productId: product.id, limit: 30 });
          if (active && res.vendors.length === 0) res = await listSuppliers({ limit: 30 });
          if (active) setVendors(res.vendors);
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
    if (!quantityOk) return setError("Enter a quantity greater than zero.");
    if (!priceOk) return setError("Enter the purchase price.");
    setBusy(true);
    try {
      const res = await createStockTransaction({
        productId: product.id,
        type,
        quantity: quantityNum,
        unitPrice: unitPrice.trim() !== "" && Number.isFinite(unitPriceNum) ? unitPriceNum : undefined,
        vendorId: type === "STOCK_IN" && vendorId ? Number(vendorId) : undefined,
        partyId: type === "STOCK_OUT" && partyId ? Number(partyId) : undefined,
        note: note.trim() || undefined,
      });
      onDone(res.draftInvoice.id);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not record the stock movement.");
    } finally {
      setBusy(false);
    }
  }

  const unit = unitLabel(product.unit);

  return (
    <Modal title="Update stock" onClose={onClose}>
      <p className="text-body-md text-muted">
        {product.name} · in stock {qty(product.stockQuantity)} {unit}
      </p>

      {/* Purchase / Sale toggle */}
      <div className="flex items-center gap-sm">
        <TypeTab label="Purchase (Stock in)" active={type === "STOCK_IN"} onClick={() => switchType("STOCK_IN")} />
        <TypeTab label="Sale (Stock out)" active={type === "STOCK_OUT"} onClick={() => switchType("STOCK_OUT")} />
      </div>

      {error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="grid grid-cols-2 gap-md">
        <TextField
          label={`Quantity (${unit})`}
          value={quantity}
          onChange={setQuantity}
          inputMode="decimal"
          placeholder="0"
        />
        <TextField
          label={type === "STOCK_IN" ? "Purchase price (₹)" : "Sale price (₹)"}
          value={unitPrice}
          onChange={setUnitPrice}
          inputMode="decimal"
          placeholder="0.00"
          helper={type === "STOCK_OUT" ? "Optional" : undefined}
        />
      </div>

      {type === "STOCK_IN" ? (
        <SelectField
          label="Supplier"
          value={vendorId}
          onChange={setVendorId}
          helper={loadingOpts ? "Loading vendors…" : "Pick from your vendors — optional."}
          options={[
            { value: "", label: vendors.length ? "No supplier" : "No saved vendors" },
            ...vendors.map((v) => ({
              value: String(v.id),
              label: v.phone ? `${v.name} · ${v.phone}` : v.name,
            })),
          ]}
        />
      ) : (
        <SelectField
          label="Customer"
          value={partyId}
          onChange={setPartyId}
          helper={loadingOpts ? "Loading customers…" : "Pick the customer — defaults to Walk-in."}
          options={[
            { value: "", label: "No customer" },
            ...parties.map((p) => ({ value: String(p.id), label: p.name })),
          ]}
        />
      )}

      <TextAreaField label="Note (optional)" value={note} onChange={setNote} rows={2} />

      <p className="text-body-sm text-subtle">
        This creates a draft invoice — confirm it from Invoices to actually post the stock.
      </p>

      <ModalActions
        busy={busy}
        disabled={!valid || loadingOpts}
        confirmLabel="Create draft"
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
