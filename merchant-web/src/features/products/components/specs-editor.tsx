"use client";

import { Plus, X } from "lucide-react";
import type { SpecGroup } from "../schema";
import { MiniButton } from "./form-controls";

const cell =
  "h-10 rounded-input border border-hairline bg-surface px-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

/** Grouped spec sheet editor — groups of (label, value) rows, optional tab. */
export function SpecsEditor({
  groups,
  onChange,
}: {
  groups: SpecGroup[];
  onChange: (next: SpecGroup[]) => void;
}) {
  function patch(i: number, p: Partial<SpecGroup>) {
    onChange(groups.map((g, idx) => (idx === i ? { ...g, ...p } : g)));
  }
  function addGroup() {
    onChange([...groups, { title: "", tab: null, rows: [{ label: "", value: "" }] }]);
  }

  return (
    <div className="flex flex-col gap-lg">
      {groups.map((g, gi) => (
        <div key={gi} className="rounded-md border border-hairline p-md">
          <div className="flex items-center gap-sm">
            <input
              value={g.title}
              placeholder="Group title (e.g. Dimensions)"
              onChange={(e) => patch(gi, { title: e.target.value })}
              className={`${cell} flex-1`}
            />
            <input
              value={g.tab ?? ""}
              placeholder="Tab (optional)"
              onChange={(e) => patch(gi, { tab: e.target.value || null })}
              className={`${cell} w-40`}
            />
            <button
              type="button"
              onClick={() => onChange(groups.filter((_, idx) => idx !== gi))}
              aria-label="Remove group"
              className="rounded-md p-sm text-muted hover:bg-surface-tint hover:text-ink"
            >
              <X size={16} />
            </button>
          </div>
          <div className="mt-sm flex flex-col gap-sm">
            {g.rows.map((r, ri) => (
              <div key={ri} className="flex items-center gap-sm">
                <input
                  value={r.label}
                  placeholder="Label"
                  onChange={(e) =>
                    patch(gi, {
                      rows: g.rows.map((x, idx) =>
                        idx === ri ? { ...x, label: e.target.value } : x,
                      ),
                    })
                  }
                  className={`${cell} flex-1`}
                />
                <input
                  value={r.value}
                  placeholder="Value"
                  onChange={(e) =>
                    patch(gi, {
                      rows: g.rows.map((x, idx) =>
                        idx === ri ? { ...x, value: e.target.value } : x,
                      ),
                    })
                  }
                  className={`${cell} flex-1`}
                />
                <button
                  type="button"
                  onClick={() =>
                    patch(gi, { rows: g.rows.filter((_, idx) => idx !== ri) })
                  }
                  aria-label="Remove row"
                  className="rounded-md p-sm text-muted hover:bg-surface-tint hover:text-ink"
                >
                  <X size={16} />
                </button>
              </div>
            ))}
            <MiniButton
              onClick={() => patch(gi, { rows: [...g.rows, { label: "", value: "" }] })}
            >
              <Plus size={16} /> Add row
            </MiniButton>
          </div>
        </div>
      ))}
      <MiniButton onClick={addGroup}>
        <Plus size={16} /> Add spec group
      </MiniButton>
    </div>
  );
}
