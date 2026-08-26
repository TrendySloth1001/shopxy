"use client";

import { useState } from "react";
import { X, Minus, Plus } from "@/shared/icons";
import { RETURN_REASONS, reasonLabel, type ReturnReason } from "../types";
import { submitReturn } from "../api";
import { formatINR } from "@/shared/format";
import type { ShopOrderDetail, OrderItem } from "@/features/orders/types";

type ItemPick = {
  purchaseRequestItemId: string;
  quantity: number;
  unitPrice: number;
  maxQuantity: number;
};

type Props = {
  parentOrderId: string;
  shopOrder: ShopOrderDetail;
  onClose: () => void;
  onSubmitted: (returnId: string) => void;
};

export function RequestReturnDialog({ parentOrderId, shopOrder, onClose, onSubmitted }: Props) {
  const [picks, setPicks] = useState<Map<string, ItemPick>>(new Map());
  const [reason, setReason] = useState<ReturnReason>("DAMAGED");
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refundEstimate = Array.from(picks.values()).reduce(
    (sum, p) => sum + p.quantity * p.unitPrice,
    0,
  );

  function toggleItem(item: OrderItem, checked: boolean) {
    setPicks((prev) => {
      const next = new Map(prev);
      if (!checked) {
        next.delete(item.id);
      } else {
        next.set(item.id, {
          purchaseRequestItemId: item.id,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          maxQuantity: item.quantity,
        });
      }
      return next;
    });
  }

  function adjustQty(itemId: string, delta: number) {
    setPicks((prev) => {
      const pick = prev.get(itemId);
      if (!pick) return prev;
      const next = new Map(prev);
      const newQty = Math.max(1, Math.min(pick.maxQuantity, pick.quantity + delta));
      next.set(itemId, { ...pick, quantity: newQty });
      return next;
    });
  }

  async function handleSubmit() {
    if (submitting) return;
    if (picks.size === 0) {
      setError("Pick at least one item to return.");
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const result = await submitReturn(parentOrderId, {
        childId: shopOrder.id,
        note: note.trim() || undefined,
        items: Array.from(picks.values()).map((p) => ({
          purchaseRequestItemId: p.purchaseRequestItemId,
          quantity: p.quantity,
          reason,
        })),
      });
      onSubmitted(result.id);
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Could not submit return.";
      if (msg === "WINDOW_EXPIRED") setError("The return window for this order has closed.");
      else if (msg === "RETURNS_DISABLED") setError("This shop does not accept returns.");
      else if (msg === "ALREADY_REQUESTED") setError("A return has already been submitted for this item.");
      else setError(msg);
      setSubmitting(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-ink/20 sm:items-center"
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div className="w-full max-w-panel rounded-t-bottom-sheet bg-canvas sm:rounded-dialog sm:my-lg max-h-[92vh] flex flex-col shadow-menu">
        <div className="flex items-center justify-between px-lg py-md border-b border-hairline flex-shrink-0">
          <h2 className="text-title-md text-ink font-extrabold">Return items</h2>
          <button
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full text-muted hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>

        <div
          className="flex-1 overflow-y-auto px-lg py-md space-y-lg"
          style={{ overscrollBehavior: "contain" }}
        >
          <div>
            <p className="mb-sm text-caption font-extrabold tracking-[0.6px] text-muted uppercase">
              Choose items
            </p>
            <div className="space-y-sm">
              {shopOrder.items.map((item) => {
                const pick = picks.get(item.id);
                const selected = !!pick;
                return (
                  <div
                    key={item.id}
                    className={`rounded-lg border p-md ${selected ? "border-brand bg-brand-soft/30" : "border-hairline bg-white"}`}
                  >
                    <div className="flex items-start gap-sm">
                      <input
                        type="checkbox"
                        id={`item-${item.id}`}
                        checked={selected}
                        onChange={(e) => toggleItem(item, e.target.checked)}
                        className="mt-[3px] h-4 w-4 accent-brand cursor-pointer flex-shrink-0"
                      />
                      <div className="flex-1 min-w-0">
                        <label
                          htmlFor={`item-${item.id}`}
                          className="text-body-sm font-bold text-ink cursor-pointer line-clamp-2"
                        >
                          {item.productName}
                        </label>
                        <p className="mt-xs text-caption text-muted">
                          Ordered: {formatQty(item.quantity)} {item.unit} ·{" "}
                          {formatINR(item.unitPrice, { decimals: 2 })} each
                        </p>
                        {selected && (
                          <p className="mt-xxs text-caption font-bold text-success">
                            Returning {formatQty(pick!.quantity)} ×{" "}
                            {formatINR(item.unitPrice, { decimals: 2 })}
                          </p>
                        )}
                      </div>
                    </div>
                    {selected && item.quantity > 1 && (
                      <div className="mt-sm flex items-center gap-sm pl-[28px]">
                        <span className="text-body-sm text-muted font-bold">Quantity:</span>
                        <button
                          onClick={() => adjustQty(item.id, -1)}
                          disabled={pick!.quantity <= 1}
                          className="flex h-7 w-7 items-center justify-center rounded-full text-muted hover:bg-surface-tint disabled:opacity-40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
                        >
                          <Minus size={14} />
                        </button>
                        <span className="text-body-sm font-extrabold text-ink w-6 text-center">
                          {formatQty(pick!.quantity)}
                        </span>
                        <button
                          onClick={() => adjustQty(item.id, 1)}
                          disabled={pick!.quantity >= item.quantity}
                          className="flex h-7 w-7 items-center justify-center rounded-full text-muted hover:bg-surface-tint disabled:opacity-40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
                        >
                          <Plus size={14} />
                        </button>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          <div>
            <p className="mb-sm text-caption font-extrabold tracking-[0.6px] text-muted uppercase">
              Reason
            </p>
            <div className="flex flex-wrap gap-sm">
              {RETURN_REASONS.map((r) => (
                <button
                  key={r}
                  onClick={() => setReason(r)}
                  className={`rounded-full border px-md py-[6px] text-body-sm font-bold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
                    reason === r
                      ? "border-ink bg-ink text-white"
                      : "border-hairline bg-white text-ink hover:bg-surface-tint"
                  }`}
                >
                  {reasonLabel(r)}
                </button>
              ))}
            </div>
          </div>

          <div>
            <p className="mb-sm text-caption font-extrabold tracking-[0.6px] text-muted uppercase">
              Add a note (optional)
            </p>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              maxLength={500}
              rows={3}
              placeholder="Tell the seller what happened"
              className="w-full rounded-input border border-hairline bg-white px-md py-sm text-body-sm text-ink placeholder:text-muted focus:border-brand focus:outline-none focus:ring-1 focus:ring-brand resize-none"
            />
          </div>

          {error && (
            <p className="text-body-sm font-bold text-error">{error}</p>
          )}
        </div>

        <div className="flex items-center justify-between border-t border-hairline px-lg py-md flex-shrink-0">
          <div>
            <p className="text-caption font-extrabold tracking-[0.4px] text-muted uppercase">
              Estimated refund
            </p>
            <p className="text-title-sm font-extrabold text-ink">
              {formatINR(refundEstimate, { decimals: 2 })}
            </p>
            <p className="text-micro text-muted">Taxes & discounts adjusted at processing</p>
          </div>
          <button
            onClick={handleSubmit}
            disabled={submitting}
            className="inline-flex h-10 items-center gap-sm rounded-button bg-ink px-xl text-label-md font-extrabold text-white disabled:opacity-60 hover:bg-ink/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
          >
            {submitting ? (
              <span className="h-4 w-4 rounded-full border-2 border-white/30 border-t-white animate-spin" />
            ) : null}
            Submit return
          </button>
        </div>
      </div>
    </div>
  );
}

function formatQty(n: number): string {
  return Number.isInteger(n) ? String(n) : n.toFixed(2);
}
