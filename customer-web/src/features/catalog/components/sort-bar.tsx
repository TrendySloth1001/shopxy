"use client";

import { SORT_OPTIONS, type SortOption } from "../types";

/**
 * Horizontal chip-strip sort control. Emits the new sort value via `onChange`.
 * Stays scrollable on mobile (overflow-x-auto).
 */
export function SortBar({
  value,
  onChange,
}: {
  value: SortOption;
  onChange: (v: SortOption) => void;
}) {
  return (
    <div className="flex items-center gap-sm overflow-x-auto py-sm [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      {SORT_OPTIONS.map((opt) => {
        const active = value === opt.value;
        return (
          <button
            key={opt.value}
            type="button"
            onClick={() => onChange(opt.value)}
            className={[
              "inline-flex shrink-0 items-center rounded-full border px-md py-xs text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft",
              active
                ? "border-ink bg-ink text-white"
                : "border-hairline bg-white text-muted hover:border-brand hover:text-brand",
            ].join(" ")}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}
