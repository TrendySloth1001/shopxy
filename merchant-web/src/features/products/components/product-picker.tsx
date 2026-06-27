"use client";

import { useEffect, useState } from "react";
import { Search } from "lucide-react";
import { Modal } from "@/shared/ui/modal";
import { listProducts } from "../api";
import { money } from "../format";
import { ProductThumb } from "./product-thumb";

/** Minimal product shape the marketing editors need from the picker. */
export type PickedProduct = {
  id: number;
  name: string;
  sku: string;
  mrp: number;
  sellingPrice: number;
  imageUrl: string | null;
};

/**
 * Search-your-catalog modal reused by the flash-deal and promotion editors so
 * the merchant picks a product without leaving the unsaved form. Mirrors the
 * Flutter `_ProductPickerSheet`: debounced search over the merchant's own
 * catalog, tap a row to select.
 */
export function ProductPicker({
  onPick,
  onClose,
}: {
  onPick: (product: PickedProduct) => void;
  onClose: () => void;
}) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<PickedProduct[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    const handle = setTimeout(() => {
      void (async () => {
        setLoading(true);
        setError(null);
        try {
          const page = await listProducts({ limit: "30", ...(query ? { search: query } : {}) });
          if (!active) return;
          setResults(
            page.data.map((p) => ({
              id: p.id,
              name: p.name,
              sku: p.sku,
              mrp: p.mrp,
              sellingPrice: p.sellingPrice,
              imageUrl: p.images[0]?.url ?? null,
            })),
          );
        } catch (e) {
          if (active) setError(e instanceof Error ? e.message : "Could not load products.");
        } finally {
          if (active) setLoading(false);
        }
      })();
    }, 250);
    return () => {
      active = false;
      clearTimeout(handle);
    };
  }, [query]);

  return (
    <Modal title="Pick a product" onClose={onClose} wide>
      <label className="flex items-center gap-sm rounded-input border border-hairline bg-surface px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
        <Search size={16} className="text-subtle" />
        <input
          autoFocus
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search your catalog"
          className="h-10 flex-1 bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
        />
      </label>

      <div className="-mx-lg mt-sm max-h-[50dvh] overflow-y-auto px-lg">
        {loading ? (
          <p className="py-xl text-center text-body-sm text-subtle">Searching…</p>
        ) : error ? (
          <p className="py-xl text-center text-body-sm text-error">{error}</p>
        ) : results.length === 0 ? (
          <p className="py-xl text-center text-body-sm text-muted">No products found.</p>
        ) : (
          results.map((p) => (
            <button
              key={p.id}
              type="button"
              onClick={() => onPick(p)}
              className="flex w-full items-center gap-md border-b border-hairline py-sm text-left transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
            >
              <ProductThumb url={p.imageUrl} alt={p.name} size={44} />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-body-md text-ink">{p.name}</span>
                <span className="block truncate text-body-sm text-muted">
                  SKU {p.sku} · {money(p.sellingPrice)}
                </span>
              </span>
            </button>
          ))
        )}
      </div>
    </Modal>
  );
}
