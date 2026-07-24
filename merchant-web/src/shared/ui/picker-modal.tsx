"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Search, X } from "@/shared/icons";

/** What each result row renders — derived from the picked entity. */
export type PickerRow = { title: string; subtitle?: string; meta?: string };

/**
 * Generic search-driven picker dialog reused by the invoice / quotation /
 * challan editors to choose a product, party or vendor. `load` runs (debounced)
 * on each query; `rowOf` maps a result to its display row; `onPick` returns the
 * full entity so the caller keeps every field it needs.
 */
export function PickerModal<T extends { id: string }>({
  title,
  placeholder,
  load,
  rowOf,
  onPick,
  onClose,
  emptyHint,
}: {
  title: string;
  placeholder: string;
  load: (search: string) => Promise<T[]>;
  rowOf: (item: T) => PickerRow;
  onPick: (item: T) => void;
  onClose: () => void;
  emptyHint?: string;
}) {
  const t = useTranslations("common");
  const [input, setInput] = useState("");
  const [query, setQuery] = useState("");
  const [rows, setRows] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const t = setTimeout(() => setQuery(input.trim()), 250);
    return () => clearTimeout(t);
  }, [input]);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const result = await load(query);
        if (!active) return;
        setRows(result);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("picker.loadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [query, load, t]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-scrim/30 p-lg sm:items-center"
      onClick={onClose}
    >
      <div
        className="flex max-h-[85dvh] w-full max-w-form flex-col gap-md overflow-hidden rounded-dialog bg-surface p-lg shadow-menu"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h3 className="text-title-md text-ink">{title}</h3>
          <button
            type="button"
            onClick={onClose}
            aria-label={t("close")}
            className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
          >
            <X size={16} />
          </button>
        </div>

        <div className="flex items-center gap-sm rounded-input border border-hairline bg-field px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
          <Search size={16} className="shrink-0 text-subtle" />
          <input
            autoFocus
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder={placeholder}
            className="h-10 w-full bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
          />
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {error ? (
            <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
          ) : loading ? (
            <p className="py-xl text-center text-body-sm text-subtle">{t("loading")}</p>
          ) : rows.length === 0 ? (
            <p className="py-xl text-center text-body-sm text-subtle">
              {emptyHint ?? t("picker.noMatches")}
            </p>
          ) : (
            <ul>
              {rows.map((item) => {
                const row = rowOf(item);
                return (
                  <li key={item.id}>
                    <button
                      type="button"
                      onClick={() => onPick(item)}
                      className="flex w-full items-center gap-md border-b border-hairline py-sm text-left transition-colors hover:bg-surface-tint"
                    >
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-body-md text-ink">{row.title}</p>
                        {row.subtitle ? (
                          <p className="truncate text-body-sm text-muted">{row.subtitle}</p>
                        ) : null}
                      </div>
                      {row.meta ? (
                        <span className="shrink-0 text-body-sm font-semibold text-ink">{row.meta}</span>
                      ) : null}
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}
