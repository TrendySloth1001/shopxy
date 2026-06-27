"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Minus, Package, Plus, Trash2, UserRound, X } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { TextAreaField, TextField } from "@/shared/ui/form";
import { PickerModal } from "@/shared/ui/picker-modal";
import { Monogram } from "@/shared/ui/monogram";
import { listProducts } from "@/features/products/api";
import { listParties } from "@/features/parties/api";
import { createChallan } from "./api";

const BACK = "/dashboard/challans";

const loadProducts = (s: string) => listProducts({ search: s, limit: "20" }).then((r) => r.data);
const loadParties = (s: string) => listParties(s ? { search: s } : undefined);

type Line = { productId: number; productName: string; productSku: string; unit: string; quantity: number };
type PartyRef = { id: number; name: string; phone?: string | null };

export function ChallanEditor() {
  const router = useRouter();

  const [party, setParty] = useState<PartyRef | null>(null);
  const [partyName, setPartyName] = useState("");
  const [partyPhone, setPartyPhone] = useState("");
  const [note, setNote] = useState("");
  const [lines, setLines] = useState<Line[]>([]);
  const [picker, setPicker] = useState<"product" | "party" | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function addProduct(p: Awaited<ReturnType<typeof loadProducts>>[number]) {
    setPicker(null);
    setLines((prev) => {
      const idx = prev.findIndex((l) => l.productId === p.id);
      if (idx >= 0) {
        const next = [...prev];
        next[idx] = { ...next[idx], quantity: next[idx].quantity + 1 };
        return next;
      }
      return [...prev, { productId: p.id, productName: p.name, productSku: p.sku, unit: p.unit, quantity: 1 }];
    });
  }

  function setQty(i: number, q: number) {
    setLines((prev) => prev.map((l, idx) => (idx === i ? { ...l, quantity: q } : l)));
  }

  async function save() {
    setError(null);
    if (lines.length === 0) return setError("Add at least one product.");
    if (!party && !partyName.trim()) return setError("Select a customer or enter a party name.");
    setSaving(true);
    try {
      const created = await createChallan({
        partyId: party?.id,
        partyName: party ? undefined : partyName.trim(),
        partyPhone: party ? undefined : partyPhone.trim() || undefined,
        note: note.trim() || undefined,
        items: lines.map((l) => ({ productId: l.productId, quantity: l.quantity })),
      });
      router.push(`/dashboard/challans/${created.id}`);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not create the challan.");
      setSaving(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Challans" />
      <h1 className="mt-md text-headline-md text-ink">Create challan</h1>
      <p className="mt-xs max-w-content text-body-md text-muted">
        A delivery note with quantities only — prices are not shown to the party. Stock leaves on creation.
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {/* Party */}
      <div className="mt-xl">
        <p className="text-label-md uppercase tracking-wide text-subtle">Party</p>
        {party ? (
          <div className="mt-sm flex items-center gap-md border-b border-hairline pb-md">
            <Monogram name={party.name} size={40} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-body-md text-ink">{party.name}</p>
              {party.phone ? <p className="text-body-sm text-muted">{party.phone}</p> : null}
            </div>
            <button
              type="button"
              onClick={() => setParty(null)}
              aria-label="Clear"
              className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
            >
              <X size={15} />
            </button>
          </div>
        ) : (
          <div className="mt-sm flex flex-col gap-sm">
            <button
              type="button"
              onClick={() => setPicker("party")}
              className="inline-flex h-10 w-fit items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              <UserRound size={16} /> Select a saved customer
            </button>
            <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
              <TextField label="Party name" value={partyName} onChange={setPartyName} placeholder="Recipient name" />
              <TextField label="Phone" value={partyPhone} onChange={setPartyPhone} type="tel" />
            </div>
          </div>
        )}
      </div>

      {/* Items */}
      <div className="mt-xl">
        <div className="flex flex-wrap items-center justify-between gap-sm">
          <p className="text-label-md uppercase tracking-wide text-subtle">Items</p>
          <button
            type="button"
            onClick={() => setPicker("product")}
            className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Plus size={15} /> Add product
          </button>
        </div>

        {lines.length === 0 ? (
          <div className="mt-md flex flex-col items-center gap-sm py-xl text-center">
            <Package size={22} className="text-subtle" />
            <p className="text-body-sm text-subtle">No items yet — add a product.</p>
          </div>
        ) : (
          <div className="mt-md">
            {lines.map((l, i) => (
              <LineRow
                key={l.productId}
                line={l}
                onQty={(v) => setQty(i, v)}
                onRemove={() => setLines((prev) => prev.filter((_, idx) => idx !== i))}
              />
            ))}
          </div>
        )}
      </div>

      {/* Note */}
      <div className="mt-xl max-w-content">
        <TextAreaField label="Note (optional)" value={note} onChange={setNote} rows={2} />
      </div>

      {/* Action */}
      <div className="mt-xxl flex flex-wrap items-center gap-sm">
        <button
          type="button"
          onClick={save}
          disabled={saving}
          className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {saving ? "Creating…" : "Create challan"}
        </button>
      </div>

      {picker === "product" ? (
        <PickerModal
          title="Add product"
          placeholder="Search products by name or SKU"
          load={loadProducts}
          rowOf={(p) => ({ title: p.name, subtitle: `${p.sku}${p.unit ? ` · ${p.unit}` : ""}`, meta: `stock ${p.stockQuantity}` })}
          onPick={addProduct}
          onClose={() => setPicker(null)}
        />
      ) : null}
      {picker === "party" ? (
        <PickerModal
          title="Select customer"
          placeholder="Search customers"
          load={loadParties}
          rowOf={(p) => ({ title: p.name, subtitle: p.phone ?? p.gstin ?? undefined })}
          onPick={(p) => {
            setParty({ id: p.id, name: p.name, phone: p.phone });
            setPicker(null);
          }}
          onClose={() => setPicker(null)}
        />
      ) : null}
    </div>
  );
}

const qtyInput =
  "h-9 w-20 rounded-input border border-hairline bg-surface px-sm text-right text-body-sm text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

function LineRow({ line, onQty, onRemove }: { line: Line; onQty: (v: number) => void; onRemove: () => void }) {
  return (
    <div className="flex flex-wrap items-end gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{line.productName}</p>
        <p className="truncate text-body-sm text-muted">{line.productSku || "—"}</p>
      </div>
      <div className="flex items-center gap-xs">
        <button
          type="button"
          onClick={() => onQty(Math.max(1, line.quantity - 1))}
          aria-label="Decrease"
          className="inline-flex size-8 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint"
        >
          <Minus size={14} />
        </button>
        <input
          inputMode="decimal"
          value={line.quantity}
          onChange={(e) => onQty(Number(e.target.value) || 0)}
          className={qtyInput}
        />
        <span className="text-body-sm text-muted">{line.unit}</span>
        <button
          type="button"
          onClick={() => onQty(line.quantity + 1)}
          aria-label="Increase"
          className="inline-flex size-8 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint"
        >
          <Plus size={14} />
        </button>
      </div>
      <button
        type="button"
        onClick={onRemove}
        aria-label="Remove"
        className="inline-flex size-9 items-center justify-center rounded-button text-muted transition-colors hover:bg-error-soft hover:text-error"
      >
        <Trash2 size={16} />
      </button>
    </div>
  );
}
