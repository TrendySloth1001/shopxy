"use client";

import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Check, ChevronRight, Search, Star } from "@/shared/icons";
import { inputClass } from "./form-controls";
import {
  normalizeCode,
  resolveHsn,
  saveShortcut,
  searchHsn,
  suggestHsn,
  type HsnMatch,
  type HsnResolution,
  type HsnSuggestion,
} from "../hsn";

/**
 * HSN/SAC classification field.
 *
 * The merchant answers one question — *what is this product?* — and the GST
 * rate follows. There is no rate input here at all; the tax field elsewhere in
 * the form is a readout of what this resolves to.
 *
 * Three ways in, in the order a merchant actually reaches for them:
 *
 *  1. **Suggested from the product name.** Nothing typed here at all — they
 *     name the product, we propose codes, they confirm.
 *  2. **Search**, by code or by word, including their own saved shortcuts and
 *     the Hindi/transliterated aliases ("kameez", "chappal", "sariya").
 *  3. **Typing a code directly**, for merchants who know theirs by heart.
 *
 * Every candidate shows its **chapter → heading breadcrumb** and definition,
 * because a four-digit code alone can't tell anyone that 62 is woven and 61 is
 * knitted — which is the single most common apparel misclassification.
 *
 * `onResolved(null)` means the code has no rate on file. The caller must leave
 * the tax alone rather than zeroing it: a silent 0% is an under-charged
 * invoice, the exact failure this feature exists to prevent.
 */
export function HsnField({
  label,
  value,
  onChange,
  onResolved,
  productName,
  price,
  error,
  helper,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  onResolved: (hit: HsnResolution | null) => void;
  /// Drives the "suggested for this product" row. Empty disables it.
  productName: string;
  /// Selling price, so a threshold slab (apparel over ₹2,500) resolves to the
  /// rate this product will actually bill at rather than the headline one.
  price?: number;
  error?: string;
  helper?: string;
}) {
  const t = useTranslations("products.form");
  const id = useId();
  const [open, setOpen] = useState(false);
  const [options, setOptions] = useState<HsnMatch[]>([]);
  const [suggestions, setSuggestions] = useState<HsnSuggestion[]>([]);
  const [loading, setLoading] = useState(false);
  const [chosen, setChosen] = useState<HsnMatch | HsnSuggestion | null>(null);
  const [saved, setSaved] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  // Latest-wins: a slow response for "620" must not overwrite the list for
  // "62052", nor a stale rate overwrite a newer one.
  const seq = useRef(0);
  // Which code we last resolved from, so a rerender can't re-fire the fill and
  // clobber a manual rate the merchant just set.
  const filledFor = useRef<string | null>(null);
  // The callback is a fresh closure each render; holding it in a ref keeps the
  // search effect from re-running on every keystroke elsewhere in the form.
  const onResolvedRef = useRef(onResolved);
  useEffect(() => {
    onResolvedRef.current = onResolved;
  }, [onResolved]);
  const priceRef = useRef(price);
  useEffect(() => {
    priceRef.current = price;
  }, [price]);

  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, [open]);

  // Suggestions from the product name. Debounced longer than search — the name
  // is typed in full, not probed character by character, and each call may cost
  // a semantic lookup on the server.
  useEffect(() => {
    const name = productName.trim();
    const mine = ++seq.current;
    const timer = setTimeout(async () => {
      if (name.length < 3) {
        if (mine === seq.current) setSuggestions([]);
        return;
      }
      const hits = await suggestHsn(name);
      if (mine === seq.current) setSuggestions(hits);
    }, 600);
    return () => clearTimeout(timer);
  }, [productName]);

  // Search + resolve on what's typed in this field.
  useEffect(() => {
    const q = value.trim();
    const digits = normalizeCode(q);
    const mine = ++seq.current;
    if (!q) filledFor.current = null;
    const timer = setTimeout(async () => {
      if (!q) {
        if (mine === seq.current) {
          setOptions([]);
          setLoading(false);
          setChosen(null);
        }
        return;
      }
      setLoading(true);
      // 4 digits is the shortest real heading; below that a resolve is noise.
      const [matches, hit] = await Promise.all([
        searchHsn(q),
        digits.length >= 4 ? resolveHsn(digits, priceRef.current) : Promise.resolve(null),
      ]);
      if (mine !== seq.current) return;
      setOptions(matches);
      setLoading(false);
      if (digits.length >= 4 && filledFor.current !== digits) {
        filledFor.current = digits;
        setSaved(false);
        setChosen(matches.find((m) => m.code === digits) ?? null);
        onResolvedRef.current(hit);
      }
    }, 250);
    return () => clearTimeout(timer);
  }, [value]);

  // Re-resolve when the price crosses a threshold the chosen code cares about.
  // Without this, editing the price of a ₹2,400 shirt up to ₹2,600 would leave
  // it billing at 5% — the rule would have been evaluated once and forgotten.
  useEffect(() => {
    const code = normalizeCode(value);
    if (code.length < 4 || !chosen?.rule) return;
    const timer = setTimeout(async () => {
      const hit = await resolveHsn(code, price);
      if (hit) onResolvedRef.current(hit);
    }, 400);
    return () => clearTimeout(timer);
  }, [price, value, chosen?.rule]);

  const pick = useCallback(
    async (match: HsnMatch | HsnSuggestion) => {
      onChange(match.code);
      setOpen(false);
      setChosen(match);
      setSaved(false);
      filledFor.current = match.code;
      onResolvedRef.current(await resolveHsn(match.code, priceRef.current));
    },
    [onChange],
  );

  const onSave = useCallback(async () => {
    const name = productName.trim();
    const code = normalizeCode(value);
    if (!name || code.length < 4) return;
    if (await saveShortcut(name, code)) setSaved(true);
  }, [productName, value]);

  const selectedCode = normalizeCode(value);
  const showSuggestions =
    suggestions.length > 0 && selectedCode.length < 4 && !open;

  return (
    <div ref={rootRef} className="relative flex flex-col gap-xs">
      <label htmlFor={id} className="text-label-md text-muted">
        {label}
      </label>
      <div className="relative">
        <input
          id={id}
          value={value}
          onChange={(e) => {
            onChange(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          placeholder={t("hsnPlaceholder")}
          autoComplete="off"
          aria-invalid={error ? true : undefined}
          className={`${inputClass} pr-10 ${error ? "border-error" : "border-hairline"}`}
        />
        <Search
          className="pointer-events-none absolute right-md top-1/2 size-4 -translate-y-1/2 text-subtle"
          aria-hidden
        />
      </div>

      {/* Suggested from the product name — the path where the merchant never
          touches this field at all. */}
      {showSuggestions ? (
        <div className="flex flex-col gap-xs">
          <span className="text-body-sm text-subtle">{t("hsnSuggestedFor")}</span>
          <div className="flex flex-wrap gap-sm">
            {suggestions.slice(0, 4).map((s) => (
              <button
                key={s.code}
                type="button"
                onClick={() => pick(s)}
                className="flex items-center gap-xs rounded-full border border-hairline px-md py-xs text-body-sm text-ink hover:bg-field"
              >
                {s.via === "SHORTCUT" ? (
                  <Star className="size-3 text-brand" aria-hidden />
                ) : null}
                <span>{s.name}</span>
                <span className="text-subtle">{s.code}</span>
                <span className="text-muted">{s.gstRate}%</span>
              </button>
            ))}
          </div>
        </div>
      ) : null}

      {open && (loading || options.length > 0) ? (
        <div className="absolute left-0 right-0 top-full z-20 mt-xs max-h-96 overflow-y-auto rounded-input border border-hairline bg-surface shadow-sm">
          {loading && options.length === 0 ? (
            <p className="px-md py-sm text-body-sm text-subtle">{t("hsnSearching")}</p>
          ) : null}
          {options.map((o) => (
            <button
              key={o.code}
              type="button"
              onClick={() => pick(o)}
              className="flex w-full flex-col gap-xs border-b border-hairline px-md py-sm text-left last:border-b-0 hover:bg-field"
            >
              {/* Chapter → heading. The line that prevents woven/knitted
                  mix-ups, so it sits above the name, not below it. */}
              {o.breadcrumb.length > 0 ? (
                <span className="flex flex-wrap items-center gap-xs text-body-sm text-subtle">
                  {o.breadcrumb.map((b, i) => (
                    <span key={b.code} className="flex items-center gap-xs">
                      {i > 0 ? <ChevronRight className="size-3" aria-hidden /> : null}
                      <span>
                        {b.code} · {b.name}
                      </span>
                    </span>
                  ))}
                </span>
              ) : null}
              <span className="flex items-center gap-sm">
                {o.fromShortcut ? <Star className="size-3.5 text-brand" aria-hidden /> : null}
                <span className="text-body-md text-ink">{o.name}</span>
                <span className="text-body-sm text-subtle">{o.code}</span>
                <span className="ml-auto text-body-md text-ink">{o.gstRate}%</span>
                {selectedCode === o.code ? (
                  <Check className="size-4 text-brand" aria-hidden />
                ) : null}
              </span>
              {o.definition ? (
                <span className="text-body-sm text-muted">{o.definition}</span>
              ) : null}
              {o.rule ? (
                <span className="text-body-sm text-muted">
                  {t("hsnRuleSummary", {
                    threshold: o.rule.threshold,
                    low: o.rule.atOrBelow,
                    high: o.rule.above,
                  })}
                </span>
              ) : null}
            </button>
          ))}
        </div>
      ) : null}

      {/* What was chosen, with its cross-references and a one-tap save. */}
      {chosen && !open ? (
        <div className="flex flex-col gap-xs rounded-input border border-hairline bg-field px-md py-sm">
          {chosen.breadcrumb.length > 0 ? (
            <span className="text-body-sm text-subtle">
              {chosen.breadcrumb.map((b) => `${b.code} · ${b.name}`).join("  →  ")}
            </span>
          ) : null}
          {chosen.definition ? (
            <span className="text-body-sm text-muted">{chosen.definition}</span>
          ) : null}
          {chosen.notHere.length > 0 ? (
            <span className="flex flex-wrap items-center gap-xs text-body-sm text-subtle">
              {t("hsnNotThis")}
              {chosen.notHere.map((n) => (
                <button
                  key={n.code}
                  type="button"
                  onClick={() => onChange(n.code)}
                  className="rounded-full border border-hairline px-sm text-ink hover:bg-surface"
                >
                  {n.name} · {n.code}
                </button>
              ))}
            </span>
          ) : null}
          {productName.trim() ? (
            <button
              type="button"
              onClick={onSave}
              disabled={saved}
              className="flex w-fit items-center gap-xs text-body-sm text-brand disabled:text-subtle"
            >
              <Star className="size-3.5" aria-hidden />
              {saved ? t("hsnSaved") : t("hsnSaveShortcut", { name: productName.trim() })}
            </button>
          ) : null}
        </div>
      ) : null}

      {error ? (
        <p className="text-body-sm text-error">{error}</p>
      ) : helper ? (
        <p className="text-body-sm text-subtle">{helper}</p>
      ) : null}
    </div>
  );
}
