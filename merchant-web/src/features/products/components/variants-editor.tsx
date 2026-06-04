"use client";

import { Plus, X } from "lucide-react";
import type { ProductVariant, VariantAxis } from "../schema";
import { MiniButton } from "./form-controls";
import { StringListEditor } from "./string-list-editor";

const cell =
  "h-9 rounded-input border border-hairline bg-white px-sm text-body-sm text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

function emptyVariant(): ProductVariant {
  return {
    sku: "",
    attributes: {},
    mrp: 0,
    sellingPrice: 0,
    purchasePrice: 0,
    stockQuantity: 0,
    imageUrls: [],
    isActive: true,
    sortOrder: 0,
  };
}

function cartesian(axes: VariantAxis[]): Array<Record<string, string>> {
  return axes.reduce<Array<Record<string, string>>>(
    (acc, axis) =>
      acc.flatMap((combo) =>
        axis.values.filter(Boolean).map((v) => ({ ...combo, [axis.name]: v })),
      ),
    [{}],
  );
}

/** Variant axes (max 3) + per-variant rows. */
export function VariantsEditor({
  axes,
  variants,
  onAxes,
  onVariants,
}: {
  axes: VariantAxis[];
  variants: ProductVariant[];
  onAxes: (next: VariantAxis[]) => void;
  onVariants: (next: ProductVariant[]) => void;
}) {
  function patchVariant(i: number, p: Partial<ProductVariant>) {
    onVariants(variants.map((v, idx) => (idx === i ? { ...v, ...p } : v)));
  }

  function generate() {
    const named = axes.filter((a) => a.name.trim() && a.values.some(Boolean));
    if (named.length === 0) return;
    const combos = cartesian(named);
    onVariants(
      combos.map((attributes, idx) => ({
        ...emptyVariant(),
        attributes,
        sku: Object.values(attributes).join("-"),
        sortOrder: idx,
      })),
    );
  }

  const namedAxes = axes.filter((a) => a.name.trim());

  return (
    <div className="flex flex-col gap-lg">
      {/* Axes */}
      <div className="flex flex-col gap-md">
        <p className="text-label-md text-muted">Axes (e.g. Colour, Size)</p>
        {axes.map((axis, ai) => (
          <div key={ai} className="rounded-md border border-hairline p-sm">
            <div className="flex items-center gap-sm">
              <input
                className={`${cell} flex-1`}
                placeholder="Axis name"
                value={axis.name}
                onChange={(e) =>
                  onAxes(axes.map((a, idx) => (idx === ai ? { ...a, name: e.target.value } : a)))
                }
              />
              <button type="button" aria-label="Remove axis"
                onClick={() => onAxes(axes.filter((_, idx) => idx !== ai))}
                className="rounded-md p-sm text-muted hover:bg-surface-tint hover:text-ink">
                <X size={16} />
              </button>
            </div>
            <div className="mt-sm">
              <StringListEditor
                items={axis.values}
                onChange={(v) => onAxes(axes.map((a, idx) => (idx === ai ? { ...a, values: v } : a)))}
                placeholder="Value"
              />
            </div>
          </div>
        ))}
        <div className="flex flex-wrap gap-sm">
          {axes.length < 3 ? (
            <MiniButton onClick={() => onAxes([...axes, { name: "", values: [""] }])}>
              <Plus size={16} /> Add axis
            </MiniButton>
          ) : null}
          {namedAxes.length > 0 ? (
            <MiniButton onClick={generate}>Generate variants</MiniButton>
          ) : null}
        </div>
      </div>

      {/* Variants */}
      {variants.length > 0 ? (
        <div className="flex flex-col gap-sm">
          <p className="text-label-md text-muted">Variants ({variants.length})</p>
          {variants.map((v, vi) => (
            <div key={vi} className="flex flex-wrap items-center gap-sm rounded-md border border-hairline p-sm">
              {namedAxes.map((axis) => (
                <select
                  key={axis.name}
                  className={`${cell} w-28`}
                  value={v.attributes[axis.name] ?? ""}
                  onChange={(e) =>
                    patchVariant(vi, { attributes: { ...v.attributes, [axis.name]: e.target.value } })
                  }
                >
                  <option value="">{axis.name}</option>
                  {axis.values.filter(Boolean).map((opt) => (
                    <option key={opt} value={opt}>
                      {opt}
                    </option>
                  ))}
                </select>
              ))}
              <input className={`${cell} w-28`} placeholder="SKU" value={v.sku}
                onChange={(e) => patchVariant(vi, { sku: e.target.value })} />
              <input className={`${cell} w-20`} type="number" placeholder="MRP" value={String(v.mrp)}
                onChange={(e) => patchVariant(vi, { mrp: Number(e.target.value) || 0 })} />
              <input className={`${cell} w-20`} type="number" placeholder="Sell" value={String(v.sellingPrice)}
                onChange={(e) => patchVariant(vi, { sellingPrice: Number(e.target.value) || 0 })} />
              <input className={`${cell} w-20`} type="number" placeholder="Cost" value={String(v.purchasePrice)}
                onChange={(e) => patchVariant(vi, { purchasePrice: Number(e.target.value) || 0 })} />
              <input className={`${cell} w-16`} type="number" placeholder="Qty" value={String(v.stockQuantity)}
                onChange={(e) => patchVariant(vi, { stockQuantity: Number(e.target.value) || 0 })} />
              <button type="button" aria-label="Remove variant"
                onClick={() => onVariants(variants.filter((_, idx) => idx !== vi))}
                className="rounded-md p-sm text-muted hover:bg-surface-tint hover:text-ink">
                <X size={16} />
              </button>
            </div>
          ))}
          <MiniButton onClick={() => onVariants([...variants, emptyVariant()])}>
            <Plus size={16} /> Add variant
          </MiniButton>
        </div>
      ) : null}
    </div>
  );
}
