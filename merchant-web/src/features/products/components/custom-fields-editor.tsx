"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import {
  getProductCustomFields,
  listCustomFieldDefs,
  saveProductCustomFields,
} from "../api";
import type { CustomFieldDef } from "../schema";
import { ComboSelect } from "@/shared/ui/combo-select";

const cell =
  "h-10 w-full rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

/**
 * Per-product custom-field values. Self-contained: loads the shop's field
 * definitions + this product's values, and saves via its own endpoint (these
 * aren't part of the product PATCH payload).
 */
export function CustomFieldsEditor({ productId }: { productId: string }) {
  const t = useTranslations("products");
  const [defs, setDefs] = useState<CustomFieldDef[]>([]);
  const [values, setValues] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const [d, v] = await Promise.all([
          listCustomFieldDefs(),
          getProductCustomFields(productId),
        ]);
        if (!active) return;
        setDefs(d);
        const map: Record<string, string> = {};
        for (const row of v) {
          if (typeof row.value === "string") map[row.definitionId] = row.value;
        }
        setValues(map);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("customFields.loadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [productId, t]);

  async function save() {
    setSaving(true);
    setError(null);
    setSaved(false);
    try {
      await saveProductCustomFields(
        productId,
        defs.map((d) => ({ definitionId: d.id, value: values[d.id] ?? "" })),
      );
      setSaved(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("customFields.saveError"));
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <p className="text-body-sm text-subtle">{t("customFields.loading")}</p>;
  if (error && defs.length === 0)
    return <p className="text-body-sm text-error">{error}</p>;
  if (defs.length === 0)
    return (
      <p className="text-body-sm text-muted">
        {t("customFields.empty")}
      </p>
    );

  return (
    <div className="flex flex-col gap-md">
      {error ? <p className="text-body-sm text-error">{error}</p> : null}
      {saved ? <p className="text-body-sm text-brand-strong">{t("customFields.saved")}</p> : null}
      {defs.map((d) => {
        const label = d.label ?? d.name ?? t("customFields.fieldFallback", { id: d.id });
        const value = values[d.id] ?? "";
        const set = (v: string) => {
          setValues((prev) => ({ ...prev, [d.id]: v }));
          setSaved(false);
        };
        return (
          <div key={d.id} className="flex flex-col gap-xs">
            <label className="text-label-md text-muted">{label}</label>
            {d.options.length > 0 ? (
              <ComboSelect
                ariaLabel={label}
                className="w-full"
                value={value}
                onChange={set}
                options={[
                  { value: "", label: "—" },
                  ...d.options.map((o) => ({ value: o, label: o })),
                ]}
              />
            ) : (
              <input
                className={cell}
                type={/number|int|decimal/i.test(d.type) ? "number" : "text"}
                value={value}
                onChange={(e) => set(e.target.value)}
              />
            )}
          </div>
        );
      })}
      <button
        type="button"
        onClick={save}
        disabled={saving}
        className="inline-flex h-10 w-fit items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
      >
        {saving ? t("customFields.saving") : t("customFields.save")}
      </button>
    </div>
  );
}
