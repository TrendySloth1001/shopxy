"use client";

import { useTranslations } from "next-intl";
import { Plus, X } from "lucide-react";
import type { SpecGroup } from "../schema";
import { MiniButton } from "./form-controls";

const cell =
  "h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

/** Grouped spec sheet editor — groups of (label, value) rows, optional tab. */
export function SpecsEditor({
  groups,
  onChange,
}: {
  groups: SpecGroup[];
  onChange: (next: SpecGroup[]) => void;
}) {
  const t = useTranslations("products");
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
              placeholder={t("specs.groupTitlePlaceholder")}
              onChange={(e) => patch(gi, { title: e.target.value })}
              className={`${cell} flex-1`}
            />
            <input
              value={g.tab ?? ""}
              placeholder={t("specs.tabPlaceholder")}
              onChange={(e) => patch(gi, { tab: e.target.value || null })}
              className={`${cell} w-40`}
            />
            <button
              type="button"
              onClick={() => onChange(groups.filter((_, idx) => idx !== gi))}
              aria-label={t("specs.removeGroup")}
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
                  placeholder={t("specs.labelPlaceholder")}
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
                  placeholder={t("specs.valuePlaceholder")}
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
                  aria-label={t("specs.removeRow")}
                  className="rounded-md p-sm text-muted hover:bg-surface-tint hover:text-ink"
                >
                  <X size={16} />
                </button>
              </div>
            ))}
            <MiniButton
              onClick={() => patch(gi, { rows: [...g.rows, { label: "", value: "" }] })}
            >
              <Plus size={16} /> {t("specs.addRow")}
            </MiniButton>
          </div>
        </div>
      ))}
      <MiniButton onClick={addGroup}>
        <Plus size={16} /> {t("specs.addGroup")}
      </MiniButton>
    </div>
  );
}
