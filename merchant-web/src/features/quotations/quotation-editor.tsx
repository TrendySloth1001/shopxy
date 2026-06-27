"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Minus, Package, Plus, Trash2, UserRound, X } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { TextAreaField } from "@/shared/ui/form";
import { PickerModal } from "@/shared/ui/picker-modal";
import { Monogram } from "@/shared/ui/monogram";
import { formatINR2 } from "@/shared/money";
import { listProducts } from "@/features/products/api";
import { listParties } from "@/features/parties/api";
import { createQuotation, respondQuotation, type QuotationItemWrite } from "./api";
import type { Quotation } from "./schema";

const BACK = "/dashboard/quotations";

const loadProducts = (s: string) => listProducts({ search: s, limit: "20" }).then((r) => r.data);
const loadParties = (s: string) => listParties(s ? { search: s } : undefined);

type QuoteLine = {
  productId: number;
  name: string;
  sku: string | null;
  quantity: number;
  unitPrice: number;
  taxPercent: number;
  imageUrl: string | null;
};

type PartyRef = { id: number; name: string; stateCode?: string | null };

export function QuotationEditor({ existing }: { existing?: Quotation }) {
  const router = useRouter();
  const respond = existing != null;

  const [party, setParty] = useState<PartyRef | null>(
    existing?.party ? { id: existing.party.id, name: existing.party.name } : null,
  );
  const [lines, setLines] = useState<QuoteLine[]>(
    existing?.items.map((it) => ({
      productId: it.productId,
      name: it.name ?? "Product",
      sku: it.sku ?? null,
      quantity: it.quantity || 1,
      unitPrice: it.unitPrice,
      taxPercent: it.taxPercent,
      imageUrl: it.imageUrl ?? null,
    })) ?? [],
  );
  const [note, setNote] = useState("");
  const [picker, setPicker] = useState<"product" | "party" | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const totals = useMemo(() => {
    const subtotal = lines.reduce((s, l) => s + l.quantity * l.unitPrice, 0);
    const tax = lines.reduce((s, l) => s + (l.quantity * l.unitPrice * l.taxPercent) / 100, 0);
    return { subtotal, tax, total: subtotal + tax };
  }, [lines]);

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
          name: p.name,
          sku: p.sku,
          quantity: 1,
          unitPrice: p.sellingPrice,
          taxPercent: p.taxPercent,
          imageUrl: p.images[0]?.url ?? null,
        },
      ];
    });
  }

  function patch(i: number, patchObj: Partial<QuoteLine>) {
    setLines((prev) => prev.map((l, idx) => (idx === i ? { ...l, ...patchObj } : l)));
  }

  function step(i: number, delta: number) {
    setLines((prev) =>
      prev.flatMap((l, idx) => {
        if (idx !== i) return [l];
        const q = l.quantity + delta;
        return q <= 0 ? [] : [{ ...l, quantity: q }];
      }),
    );
  }

  async function send() {
    setError(null);
    if (lines.length === 0) return setError("Add at least one product.");
    if (!respond && !party) return setError("Select the customer to send this quote to.");
    const items: QuotationItemWrite[] = lines.map((l) => ({
      productId: l.productId,
      name: l.name,
      sku: l.sku ?? undefined,
      quantity: l.quantity,
      unitPrice: l.unitPrice,
      taxPercent: l.taxPercent,
      imageUrl: l.imageUrl ?? undefined,
    }));
    const placeOfSupplyStateCode = party?.stateCode ?? existing?.placeOfSupplyStateCode ?? undefined;
    setSaving(true);
    try {
      const result = respond
        ? await respondQuotation(existing.id, { items, note: note.trim() || undefined, placeOfSupplyStateCode })
        : await createQuotation({
            partyId: party!.id,
            items,
            note: note.trim() || undefined,
            placeOfSupplyStateCode,
          });
      router.push(`/dashboard/quotations/${result.id}`);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not send the quotation.");
      setSaving(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Quotations" />
      <h1 className="mt-md text-headline-md text-ink">{respond ? "Price & send quote" : "New quotation"}</h1>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {/* Customer */}
      <div className="mt-xl">
        <p className="text-label-md uppercase tracking-wide text-subtle">Customer</p>
        {party ? (
          <div className="mt-sm flex items-center gap-md border-b border-hairline pb-md">
            <Monogram name={party.name} size={40} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-body-md text-ink">{party.name}</p>
              {respond ? <p className="text-body-sm text-muted">Requested this quote</p> : null}
            </div>
            {!respond ? (
              <button
                type="button"
                onClick={() => setParty(null)}
                aria-label="Clear"
                className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
              >
                <X size={15} />
              </button>
            ) : null}
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setPicker("party")}
            className="mt-sm inline-flex h-10 w-fit items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <UserRound size={16} /> Select a linked customer
          </button>
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
            <p className="text-body-sm text-subtle">Search and add the products to quote.</p>
          </div>
        ) : (
          <div className="mt-md">
            {lines.map((l, i) => (
              <QuoteLineRow
                key={l.productId}
                line={l}
                onPrice={(v) => patch(i, { unitPrice: v })}
                onStep={(d) => step(i, d)}
                onRemove={() => setLines((prev) => prev.filter((_, idx) => idx !== i))}
              />
            ))}
          </div>
        )}
      </div>

      {/* Totals + note */}
      {lines.length > 0 ? (
        <div className="mt-xl grid grid-cols-1 gap-xl lg:grid-cols-2">
          <TextAreaField label="Note (optional)" value={note} onChange={setNote} rows={3} />
          <div className="border-t border-hairline pt-md lg:border-t-0 lg:pt-0">
            <Row label="Subtotal" value={totals.subtotal} />
            <Row label="GST" value={totals.tax} />
            <div className="mt-sm flex items-center justify-between border-t border-hairline pt-sm">
              <span className="text-title-md text-ink">Total</span>
              <span className="text-title-lg font-bold text-ink">{formatINR2(totals.total)}</span>
            </div>
          </div>
        </div>
      ) : null}

      {/* Action */}
      <div className="mt-xxl flex flex-wrap items-center gap-sm">
        <button
          type="button"
          onClick={send}
          disabled={saving}
          className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {saving ? "Sending…" : `Send quotation · ${formatINR2(totals.total)}`}
        </button>
      </div>

      {picker === "product" ? (
        <PickerModal
          title="Add product"
          placeholder="Search products by name or SKU"
          load={loadProducts}
          rowOf={(p) => ({ title: p.name, subtitle: `${p.sku} · stock ${p.stockQuantity}`, meta: formatINR2(p.sellingPrice) })}
          onPick={addProduct}
          onClose={() => setPicker(null)}
        />
      ) : null}
      {picker === "party" ? (
        <PickerModal
          title="Select customer"
          placeholder="Search linked customers"
          load={loadParties}
          rowOf={(p) => ({ title: p.name, subtitle: p.linkedUserId ? "Linked" : p.phone ?? undefined })}
          onPick={(p) => {
            setParty({ id: p.id, name: p.name, stateCode: p.stateCode });
            setPicker(null);
          }}
          onClose={() => setPicker(null)}
          emptyHint="No customers found. Quotes can only be sent to linked customers."
        />
      ) : null}
    </div>
  );
}

const priceInput =
  "h-9 w-24 rounded-input border border-hairline bg-field px-sm text-right text-body-sm text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

function QuoteLineRow({
  line,
  onPrice,
  onStep,
  onRemove,
}: {
  line: QuoteLine;
  onPrice: (v: number) => void;
  onStep: (delta: number) => void;
  onRemove: () => void;
}) {
  const lineTotal = line.quantity * line.unitPrice * (1 + line.taxPercent / 100);
  return (
    <div className="flex flex-wrap items-end gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{line.name}</p>
        <p className="truncate text-body-sm text-muted">
          {line.taxPercent > 0 ? `${line.taxPercent}% GST` : "No GST"}
          {line.sku ? ` · ${line.sku}` : ""}
        </p>
      </div>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-subtle">Rate ₹</span>
        <input
          inputMode="decimal"
          value={line.unitPrice}
          onChange={(e) => onPrice(Number(e.target.value) || 0)}
          className={priceInput}
        />
      </label>
      <div className="flex items-center gap-xs">
        <button
          type="button"
          onClick={() => onStep(-1)}
          aria-label="Decrease"
          className="inline-flex size-8 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint"
        >
          <Minus size={14} />
        </button>
        <span className="min-w-8 text-center text-body-md tabular-nums text-ink">{line.quantity}</span>
        <button
          type="button"
          onClick={() => onStep(1)}
          aria-label="Increase"
          className="inline-flex size-8 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint"
        >
          <Plus size={14} />
        </button>
      </div>
      <span className="min-w-24 text-right text-body-md font-semibold text-ink">{formatINR2(lineTotal)}</span>
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

function Row({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex items-center justify-between py-xs">
      <span className="text-body-md text-muted">{label}</span>
      <span className="text-body-md tabular-nums text-ink">{formatINR2(value)}</span>
    </div>
  );
}
