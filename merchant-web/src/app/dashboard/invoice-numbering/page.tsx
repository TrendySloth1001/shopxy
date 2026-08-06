"use client";

import { useEffect, useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { Receipt, RotateCcw } from "@/shared/icons";
import { Divider } from "@/shared/ui/divider";
import { ComboSelect } from "@/shared/ui/combo-select";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { Field } from "@/features/auth/components/field";
import { Banner } from "@/features/auth/components/banner";
import { useCanManage } from "@/features/auth/use-can";
import {
  listNumberingSchemes,
  setNumberingNextNumber,
  updateNumberingScheme,
} from "@/features/numbering/api";
import {
  formatDocNoPreview,
  SEPARATOR_VALUES,
  SERIES_LABELS,
  updateSchemeSchema,
  type NumberingScheme,
  type Series,
} from "@/features/numbering/schema";

/** Display grouping — same series set the backend/Flutter side use, just
 * clustered into three headed groups so the page doesn't read as one flat
 * list of seven unrelated rows. */
const GROUPS: { titleKey: string; series: Series[] }[] = [
  {
    titleKey: "groups.invoices",
    series: ["SALE_INVOICE", "PURCHASE_INVOICE", "ESTIMATE", "CREDIT_NOTE", "DEBIT_NOTE"],
  },
  { titleKey: "groups.challan", series: ["CHALLAN"] },
  { titleKey: "groups.quotation", series: ["QUOTATION"] },
];

const SEPARATOR_LABEL: Record<(typeof SEPARATOR_VALUES)[number], string> = {
  "/": "/",
  "-": "-",
  ".": ".",
  "": "None",
};

export default function InvoiceNumberingPage() {
  const t = useTranslations("numbering");
  const canEdit = useCanManage("invoices");
  const [schemes, setSchemes] = useState<NumberingScheme[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<NumberingScheme | null>(null);
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const rows = await listNumberingSchemes();
        if (!active) return;
        setSchemes(rows);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("errors.load"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, t]);

  const bySeries = useMemo(() => {
    const map = new Map<Series, NumberingScheme>();
    for (const s of schemes ?? []) map.set(s.series, s);
    return map;
  }, [schemes]);

  function onSaved(updated: NumberingScheme) {
    setSchemes((prev) => (prev ?? []).map((s) => (s.series === updated.series ? updated : s)));
    setEditing(null);
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <div className="flex items-center gap-md">
        <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-brand-soft text-brand-strong">
          <Receipt size={20} />
        </span>
        <div>
          <h1 className="text-headline-md text-ink">{t("title")}</h1>
          <p className="text-body-sm text-muted">{t("subtitle")}</p>
        </div>
      </div>

      {error ? (
        <div className="mt-lg flex max-w-content flex-col gap-sm">
          <Banner variant="error" message={error} />
          <button
            type="button"
            onClick={() => setNonce((n) => n + 1)}
            className="self-start text-label-md text-brand-strong transition-colors hover:underline"
          >
            {t("errors.retry")}
          </button>
        </div>
      ) : null}

      <div className="mt-xl flex max-w-content flex-col gap-xxl">
        {loading || !schemes
          ? null
          : GROUPS.map((group) => (
              <div key={group.titleKey}>
                <p className="mb-sm px-sm text-label-md uppercase tracking-wide text-subtle">
                  {t(group.titleKey)}
                </p>
                <div className="rounded-lg border border-hairline">
                  {group.series.map((series, i) => {
                    const scheme = bySeries.get(series);
                    if (!scheme) return null;
                    return (
                      <div key={series}>
                        {i > 0 ? <Divider inset /> : null}
                        <button
                          type="button"
                          onClick={() => canEdit && setEditing(scheme)}
                          disabled={!canEdit}
                          className="flex w-full items-center justify-between gap-md px-md py-md text-left transition-colors hover:bg-surface-tint disabled:cursor-default disabled:hover:bg-transparent"
                        >
                          <div className="min-w-0">
                            <p className="text-body-md text-ink">{SERIES_LABELS[series]}</p>
                            <p className="mt-xxs font-mono text-body-sm text-muted">
                              {scheme.nextPreview}
                            </p>
                          </div>
                          {scheme.isCustom ? (
                            <span className="shrink-0 rounded-full bg-brand-soft px-sm py-px text-label-md text-brand-strong">
                              {t("customized")}
                            </span>
                          ) : (
                            <span className="shrink-0 text-label-md text-subtle">
                              {t("default")}
                            </span>
                          )}
                        </button>
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
      </div>

      {editing ? (
        <SchemeEditorModal
          scheme={editing}
          onClose={() => setEditing(null)}
          onSaved={onSaved}
        />
      ) : null}
    </div>
  );
}

function SchemeEditorModal({
  scheme,
  onClose,
  onSaved,
}: {
  scheme: NumberingScheme;
  onClose: () => void;
  onSaved: (updated: NumberingScheme) => void;
}) {
  const t = useTranslations("numbering");
  const [prefix, setPrefix] = useState(scheme.prefix);
  const [suffix, setSuffix] = useState(scheme.suffix);
  const [separator, setSeparator] = useState<string>(scheme.separator);
  const [padding, setPadding] = useState(String(scheme.padding));
  const [resetYearly, setResetYearly] = useState(scheme.resetYearly ? "yearly" : "never");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [showStartAt, setShowStartAt] = useState(false);
  const [startAt, setStartAt] = useState("");
  const [startBusy, setStartBusy] = useState(false);
  const [startError, setStartError] = useState<string | null>(null);

  const paddingNum = Number(padding) || scheme.padding;
  const preview = formatDocNoPreview(
    { prefix, suffix, separator, padding: paddingNum, resetYearly: resetYearly === "yearly" },
    scheme.nextSeq,
    scheme.financialYear,
  );

  async function onSave() {
    setError(null);
    const parsed = updateSchemeSchema.safeParse({
      prefix,
      suffix,
      separator,
      padding: paddingNum,
      resetYearly: resetYearly === "yearly",
    });
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? t("errors.invalid"));
      return;
    }
    setBusy(true);
    try {
      const updated = await updateNumberingScheme(scheme.series, parsed.data);
      onSaved(updated);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("errors.save"));
    } finally {
      setBusy(false);
    }
  }

  async function onSetStartAt() {
    setStartError(null);
    const n = Number(startAt);
    if (!Number.isInteger(n) || n <= 0) {
      setStartError(t("errors.invalidStartAt"));
      return;
    }
    setStartBusy(true);
    try {
      const updated = await setNumberingNextNumber(scheme.series, n);
      onSaved(updated);
    } catch (e) {
      setStartError(e instanceof Error ? e.message : t("errors.save"));
    } finally {
      setStartBusy(false);
    }
  }

  return (
    <Modal title={SERIES_LABELS[scheme.series]} onClose={onClose}>
      <div className="flex flex-col gap-md">
        {error ? <Banner variant="error" message={error} /> : null}

        <div className="rounded-md border border-hairline bg-hero-panel px-md py-sm">
          <p className="text-label-md text-muted">{t("preview")}</p>
          <p className="mt-xxs font-mono text-title-sm text-ink">{preview}</p>
        </div>

        <div className="grid grid-cols-2 gap-md">
          <Field label={t("field.prefix")} value={prefix} onChange={(e) => setPrefix(e.target.value)} maxLength={10} />
          <Field label={t("field.suffix")} value={suffix} onChange={(e) => setSuffix(e.target.value)} maxLength={10} />
        </div>

        <div className="grid grid-cols-2 gap-md">
          <ComboSelect
            label={t("field.separator")}
            value={separator}
            onChange={setSeparator}
            options={SEPARATOR_VALUES.map((v) => ({ value: v, label: SEPARATOR_LABEL[v] || t("field.separatorNone") }))}
          />
          <Field
            label={t("field.padding")}
            type="number"
            inputMode="numeric"
            min={1}
            max={8}
            value={padding}
            onChange={(e) => setPadding(e.target.value)}
          />
        </div>

        <ComboSelect
          label={t("field.resetYearly")}
          value={resetYearly}
          onChange={setResetYearly}
          options={[
            { value: "yearly", label: t("field.resetYearlyOn") },
            { value: "never", label: t("field.resetYearlyOff") },
          ]}
          helper={t("field.resetYearlyHelper")}
        />

        <ModalActions
          busy={busy}
          confirmLabel={t("save")}
          onCancel={onClose}
          onConfirm={onSave}
        />

        <Divider />

        <div className="flex flex-col gap-sm">
          <button
            type="button"
            onClick={() => setShowStartAt((v) => !v)}
            className="flex items-center gap-sm text-label-md text-muted transition-colors hover:text-ink"
          >
            <RotateCcw size={16} />
            {t("startAt.toggle")}
          </button>
          {showStartAt ? (
            <div className="flex flex-col gap-sm rounded-md border border-hairline p-md">
              <p className="text-body-sm text-muted">{t("startAt.helper")}</p>
              {startError ? <Banner variant="error" message={startError} /> : null}
              <div className="flex items-end gap-sm">
                <div className="flex-1">
                  <Field
                    label={t("startAt.label")}
                    type="number"
                    inputMode="numeric"
                    min={1}
                    value={startAt}
                    onChange={(e) => setStartAt(e.target.value)}
                  />
                </div>
                <button
                  type="button"
                  onClick={onSetStartAt}
                  disabled={startBusy || !startAt}
                  className="inline-flex h-10 shrink-0 items-center rounded-button bg-ink px-md text-label-md text-white transition-colors hover:opacity-90 disabled:bg-disabled"
                >
                  {startBusy ? t("saving") : t("startAt.confirm")}
                </button>
              </div>
            </div>
          ) : null}
        </div>
      </div>
    </Modal>
  );
}
