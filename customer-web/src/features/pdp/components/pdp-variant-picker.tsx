"use client";

import { useState, useCallback } from "react";
import type { ProductDetail, Variant } from "../types";

interface Props {
  product: ProductDetail;
  onSelect: (variant: Variant | null) => void;
}

function findVariant(variants: Variant[], selected: Record<string, string>): Variant | null {
  const keys = Object.keys(selected);
  if (keys.length === 0) return null;
  for (const v of variants) {
    let match = true;
    for (const k of keys) {
      if ((v.attributes[k] ?? "") !== selected[k]) {
        match = false;
        break;
      }
    }
    if (match) return v;
  }
  return null;
}

export function PdpVariantPicker({ product, onSelect }: Props) {
  const { variants, variantAxes } = product;

  const defaultVariant = variants.find((v) => v.isDefault) ?? variants[0] ?? null;
  const [selected, setSelected] = useState<Record<string, string>>(() => {
    if (!defaultVariant || variantAxes.length === 0) return {};
    const s: Record<string, string> = {};
    for (const axis of variantAxes) {
      s[axis.name] = defaultVariant.attributes[axis.name] ?? axis.values[0] ?? "";
    }
    return s;
  });

  const pick = useCallback(
    (axis: string, value: string) => {
      setSelected((prev) => {
        const next = { ...prev, [axis]: value };
        const match = findVariant(variants, next);
        onSelect(match);
        return next;
      });
    },
    [variants, onSelect],
  );

  if (variants.length <= 1 || variantAxes.length === 0) return null;

  return (
    <div className="flex flex-col gap-md px-lg pb-sm">
      {variantAxes.map((axis) => (
        <div key={axis.name}>
          <p className="mb-sm text-body-md text-muted">
            {axis.name}:{" "}
            <span className="font-bold text-ink">{selected[axis.name] ?? ""}</span>
          </p>
          <div className="flex flex-wrap gap-sm">
            {axis.values.map((value) => {
              const isSelected = selected[axis.name] === value;
              const hasStock = variants.some((v) => {
                const match = { ...selected, [axis.name]: value };
                return (
                  Object.entries(match).every(([k, val]) => (v.attributes[k] ?? "") === val) &&
                  v.stockQuantity > 0
                );
              });
              const isDisabled = !hasStock;
              return (
                <button
                  key={value}
                  onClick={() => !isDisabled && pick(axis.name, value)}
                  disabled={isDisabled}
                  title={isDisabled ? "Out of stock" : undefined}
                  className={`relative rounded-button border px-md py-xs text-label-md font-bold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
                    isDisabled
                      ? "cursor-not-allowed border-hairline bg-canvas text-disabled line-through"
                      : isSelected
                        ? "border-brand bg-brand text-white shadow-sm"
                        : "border-hairline bg-white text-ink hover:border-brand/30"
                  }`}
                >
                  {value}
                </button>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
