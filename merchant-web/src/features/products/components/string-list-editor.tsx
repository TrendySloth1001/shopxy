"use client";

import { X, Plus } from "lucide-react";

/** Editable list of short strings (used for tags and highlights). */
export function StringListEditor({
  items,
  onChange,
  placeholder,
  max,
}: {
  items: string[];
  onChange: (next: string[]) => void;
  placeholder?: string;
  max?: number;
}) {
  function set(i: number, v: string) {
    onChange(items.map((it, idx) => (idx === i ? v : it)));
  }
  function add() {
    if (max && items.length >= max) return;
    onChange([...items, ""]);
  }
  function remove(i: number) {
    onChange(items.filter((_, idx) => idx !== i));
  }

  return (
    <div className="flex flex-col gap-sm">
      {items.map((item, i) => (
        <div key={i} className="flex items-center gap-sm">
          <input
            value={item}
            placeholder={placeholder}
            onChange={(e) => set(i, e.target.value)}
            className="h-10 flex-1 rounded-input border border-hairline bg-surface px-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
          />
          <button
            type="button"
            onClick={() => remove(i)}
            aria-label="Remove"
            className="rounded-md p-sm text-muted transition-colors hover:bg-surface-tint hover:text-ink"
          >
            <X size={16} />
          </button>
        </div>
      ))}
      {!max || items.length < max ? (
        <button
          type="button"
          onClick={add}
          className="inline-flex h-9 w-fit items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Plus size={16} /> Add
        </button>
      ) : null}
    </div>
  );
}
