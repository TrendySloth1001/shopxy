"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowDownLeft, ArrowUpRight, Minus, Package, Plus, Trash2 } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { TextAreaField } from "@/shared/ui/form";
import { PickerModal } from "@/shared/ui/picker-modal";
import { listProducts } from "@/features/products/api";
import { createAdjustment } from "./api";
import {
  ADJUSTMENT_REASONS,
  ADJUSTMENT_REASON_LABELS,
  defaultDirection,
  directionIsEditable,
} from "./schema";

const BACK = "/dashboard/stock-adjustments";
const loadProducts = (s: string) => listProducts({ search: s, limit: "20" }).then((r) => r.data);

type Line = { productId: number; productName: string; productSku: string; unit: string; quantity: number };

export function AdjustmentEditor() {
  const router = useRouter();

  const [reason, setReason] = useState<string>("DAMAGE");
  const [direction, setDirection] = useState<"IN" | "OUT">(defaultDirection("DAMAGE"));
  const [note, setNote] = useState("");
  const [lines, setLines] = useState<Line[]>([]);
  const [picker, setPicker] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function pickReason(r: string) {
    setReason(r);
    setDirection(defaultDirection(r));
  }

  function addProduct(p: Awaited<ReturnType<typeof loadProducts>>[number]) {
    setPicker(false);
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
    setSaving(true);
    try {
      await createAdjustment({
        reasonCode: reason,
        direction,
        note: note.trim() || undefined,
        items: lines.map((l) => ({ productId: l.productId, quantity: l.quantity })),
      });
      router.push(BACK);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not post the adjustment.");
      setSaving(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Stock adjustments" />
      <h1 className="mt-md text-headline-md text-ink">New adjustment</h1>
      <p className="mt-xs max-w-content text-body-md text-muted">
        Correct on-hand stock for damage, expiry, shrinkage, a recount or an opening balance. This posts a
        movement to the stock ledger.
      </p>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {/* Reason */}
      <div className="mt-xl">
        <p className="text-label-md uppercase tracking-wide text-subtle">Reason</p>
        <div className="mt-sm flex flex-wrap items-center gap-sm">
          {ADJUSTMENT_REASONS.map((r) => (
            <button
              key={r}
              type="button"
              onClick={() => pickReason(r)}
              className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors ${
                reason === r ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
              }`}
            >
              {ADJUSTMENT_REASON_LABELS[r]}
            </button>
          ))}
        </div>
      </div>

      {/* Direction (only when the reason can go either way) */}
      {directionIsEditable(reason) ? (
        <div className="mt-lg">
          <p className="text-label-md uppercase tracking-wide text-subtle">Direction</p>
          <div className="mt-sm flex flex-wrap items-center gap-sm">
            <button
              type="button"
              onClick={() => setDirection("IN")}
              className={`inline-flex h-9 items-center gap-sm rounded-button px-md text-label-md transition-colors ${
                direction === "IN" ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
              }`}
            >
              <ArrowDownLeft size={15} /> Add stock
            </button>
            <button
              type="button"
              onClick={() => setDirection("OUT")}
              className={`inline-flex h-9 items-center gap-sm rounded-button px-md text-label-md transition-colors ${
                direction === "OUT" ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
              }`}
            >
              <ArrowUpRight size={15} /> Remove stock
            </button>
          </div>
        </div>
      ) : null}

      {/* Items */}
      <div className="mt-xl">
        <div className="flex flex-wrap items-center justify-between gap-sm">
          <p className="text-label-md uppercase tracking-wide text-subtle">Products</p>
          <button
            type="button"
            onClick={() => setPicker(true)}
            className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Plus size={15} /> Add product
          </button>
        </div>

        {lines.length === 0 ? (
          <div className="mt-md flex flex-col items-center gap-sm py-xl text-center">
            <Package size={22} className="text-subtle" />
            <p className="text-body-sm text-subtle">No products yet — add one to adjust.</p>
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
          {saving ? "Posting…" : "Post adjustment"}
        </button>
      </div>

      {picker ? (
        <PickerModal
          title="Add product"
          placeholder="Search products by name or SKU"
          load={loadProducts}
          rowOf={(p) => ({ title: p.name, subtitle: `${p.sku}${p.unit ? ` · ${p.unit}` : ""}`, meta: `stock ${p.stockQuantity}` })}
          onPick={addProduct}
          onClose={() => setPicker(false)}
        />
      ) : null}
    </div>
  );
}

const qtyInput =
  "h-9 w-20 rounded-input border border-hairline bg-field px-sm text-right text-body-sm text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

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
