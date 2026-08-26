"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { Minus, Package, Plus, Trash2, UserRound, X } from "@/shared/icons";
import { BackLink } from "@/shared/ui/page-header";
import { TextAreaField } from "@/shared/ui/form";
import { PickerModal } from "@/shared/ui/picker-modal";
import { Monogram } from "@/shared/ui/monogram";
import { formatINR2 } from "@/shared/money";
import { listProducts } from "@/features/products/api";
import { listParties } from "@/features/parties/api";
import { createQuotation, respondQuotation, type QuotationItemWrite } from "./api";
import type { Quotation } from "./schema";

const BACK = "/dashboard/quotations";

const loadProducts = (s: string) => listProducts({ search: s, limit: "20" }).then((r) => r.data);
const loadParties = (s: string) => listParties(s ? { search: s } : undefined);

type QuoteLine = {
  productId: string;
  name: string;
  sku: string | null;
  quantity: number;
  unitPrice: number;
  taxPercent: number;
  isPriceInclusive: boolean;
  imageUrl: string | null;
};

type PartyRef = { id: string; name: string; stateCode?: string | null };

export function QuotationEditor({ existing }: { existing?: Quotation }) {
  const t = useTranslations("quotations");
  const router = useRouter();
  const respond = existing != null;

  const [party, setParty] = useState<PartyRef | null>(
    existing?.party ? { id: existing.party.id, name: existing.party.name } : null,
  );
  const [lines, setLines] = useState<QuoteLine[]>(
    existing?.items.map((it) => ({
      productId: it.productId,
      name: it.name ?? t("line.productFallback"),
      sku: it.sku ?? null,
      quantity: it.quantity || 1,
      unitPrice: it.unitPrice,
      taxPercent: it.taxPercent,
      isPriceInclusive: it.isPriceInclusive,
      imageUrl: it.imageUrl ?? null,
    })) ?? [],
  );
  const [note, setNote] = useState("");
  const [picker, setPicker] = useState<"product" | "party" | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const totals = useMemo(() => {
    let subtotal = 0;
    let tax = 0;
    for (const l of lines) {
      const gross = l.quantity * l.unitPrice;
      if (l.isPriceInclusive) {
        const taxable = l.taxPercent > 0 ? (gross * 100) / (100 + l.taxPercent) : gross;
        subtotal += taxable;
        tax += gross - taxable;
      } else {
        subtotal += gross;
        tax += (gross * l.taxPercent) / 100;
      }
    }
    return { subtotal, tax, total: subtotal + tax };
  }, [lines]);

  function addProduct(p: Awaited<ReturnType<typeof loadProducts>>[number]) {
    setPicker(null);
    setLines((prev) => {
      const idx = prev.findIndex((l) => l.productId === p.id);
      if (idx >= 0) {
        const next = [...prev];
        next[idx] = { ...next[idx], quantity: next[idx].quantity + 1 };
        return next;
      }
      return [
        ...prev,
        {
          productId: p.id,
          name: p.name,
          sku: p.sku,
          quantity: 1,
          unitPrice: p.sellingPrice,
          taxPercent: p.pricingMode === "NO_GST" ? 0 : p.taxPercent,
          isPriceInclusive: p.pricingMode === "TAX_INCLUSIVE",
          imageUrl: p.images[0]?.url ?? null,
        },
      ];
    });
  }

  function patch(i: number, patchObj: Partial<QuoteLine>) {
    setLines((prev) => prev.map((l, idx) => (idx === i ? { ...l, ...patchObj } : l)));
  }

  function step(i: number, delta: number) {
    setLines((prev) =>
      prev.flatMap((l, idx) => {
        if (idx !== i) return [l];
        const q = l.quantity + delta;
        return q <= 0 ? [] : [{ ...l, quantity: q }];
      }),
    );
  }

  async function send() {
    setError(null);
    if (lines.length === 0) return setError(t("editor.errorNoProducts"));
    if (!respond && !party) return setError(t("editor.errorNoCustomer"));
    const items: QuotationItemWrite[] = lines.map((l) => ({
      productId: l.productId,
      name: l.name,
      sku: l.sku ?? undefined,
      quantity: l.quantity,
      unitPrice: l.unitPrice,
      taxPercent: l.taxPercent,
      isPriceInclusive: l.isPriceInclusive,
      imageUrl: l.imageUrl ?? undefined,
    }));
    const placeOfSupplyStateCode = party?.stateCode ?? existing?.placeOfSupplyStateCode ?? undefined;
    setSaving(true);
    try {
      const result = respond
        ? await respondQuotation(existing.id, { items, note: note.trim() || undefined, placeOfSupplyStateCode })
        : await createQuotation({
            partyId: party!.id,
            items,
            note: note.trim() || undefined,
            placeOfSupplyStateCode,
          });
      router.push(`/dashboard/quotations/${result.id}`);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("editor.sendError"));
      setSaving(false);
    }
  }

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label={t("list.title")} />
      <h1 className="mt-md text-headline-md text-ink">
        {respond ? t("editor.titleRespond") : t("editor.titleNew")}
      </h1>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl">
        <p className="text-label-md uppercase tracking-wide text-subtle">{t("editor.customer")}</p>
        {party ? (
          <div className="mt-sm flex items-center gap-md border-b border-hairline pb-md">
            <Monogram name={party.name} size={40} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-body-md text-ink">{party.name}</p>
              {respond ? <p className="text-body-sm text-muted">{t("editor.requestedThisQuote")}</p> : null}
            </div>
            {!respond ? (
              <button
                type="button"
                onClick={() => setParty(null)}
                aria-label={t("editor.clear")}
                className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
              >
                <X size={15} />
              </button>
            ) : null}
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setPicker("party")}
            className="mt-sm inline-flex h-10 w-fit items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <UserRound size={16} /> {t("editor.selectCustomer")}
          </button>
        )}
      </div>

      <div className="mt-xl">
        <div className="flex flex-wrap items-center justify-between gap-sm">
          <p className="text-label-md uppercase tracking-wide text-subtle">{t("editor.items")}</p>
          <button
            type="button"
            onClick={() => setPicker("product")}
            className="inline-flex h-9 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Plus size={15} /> {t("editor.addProduct")}
          </button>
        </div>

        {lines.length === 0 ? (
          <div className="mt-md flex flex-col items-center gap-sm py-xl text-center">
            <Package size={22} className="text-subtle" />
            <p className="text-body-sm text-subtle">{t("editor.itemsEmpty")}</p>
          </div>
        ) : (
          <div className="mt-md">
            {lines.map((l, i) => (
              <QuoteLineRow
                key={l.productId}
                line={l}
                onPrice={(v) => patch(i, { unitPrice: v })}
                onStep={(d) => step(i, d)}
                onToggleInclusive={() => patch(i, { isPriceInclusive: !l.isPriceInclusive })}
                onRemove={() => setLines((prev) => prev.filter((_, idx) => idx !== i))}
              />
            ))}
          </div>
        )}
      </div>

      {lines.length > 0 ? (
        <div className="mt-xl grid grid-cols-1 gap-xl lg:grid-cols-2">
          <TextAreaField label={t("editor.noteLabel")} value={note} onChange={setNote} rows={3} />
          <div className="border-t border-hairline pt-md lg:border-t-0 lg:pt-0">
            <Row label={t("totals.subtotal")} value={totals.subtotal} />
            <Row label={t("totals.gst")} value={totals.tax} />
            <div className="mt-sm flex items-center justify-between border-t border-hairline pt-sm">
              <span className="text-title-md text-ink">{t("totals.total")}</span>
              <span className="text-title-lg font-bold text-ink">{formatINR2(totals.total)}</span>
            </div>
          </div>
        </div>
      ) : null}

      <div className="mt-xxl flex flex-wrap items-center gap-sm">
        <button
          type="button"
          onClick={send}
          disabled={saving}
          className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
        >
          {saving ? t("editor.sending") : t("editor.sendCta", { amount: formatINR2(totals.total) })}
        </button>
      </div>

      {picker === "product" ? (
        <PickerModal
          title={t("productPicker.title")}
          placeholder={t("productPicker.placeholder")}
          load={loadProducts}
          rowOf={(p) => ({ title: p.name, subtitle: `${p.sku} · ${t("productPicker.stock", { count: p.stockQuantity })}`, meta: formatINR2(p.sellingPrice) })}
          onPick={addProduct}
          onClose={() => setPicker(null)}
        />
      ) : null}
      {picker === "party" ? (
        <PickerModal
          title={t("partyPicker.title")}
          placeholder={t("partyPicker.placeholder")}
          load={loadParties}
          rowOf={(p) => ({ title: p.name, subtitle: p.linkedUserId ? t("partyPicker.linked") : p.phone ?? undefined })}
          onPick={(p) => {
            setParty({ id: p.id, name: p.name, stateCode: p.stateCode });
            setPicker(null);
          }}
          onClose={() => setPicker(null)}
          emptyHint={t("partyPicker.emptyHint")}
        />
      ) : null}
    </div>
  );
}

const priceInput =
  "h-9 w-24 rounded-input border border-hairline bg-field px-sm text-right text-body-sm text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

function QuoteLineRow({
  line,
  onPrice,
  onStep,
  onToggleInclusive,
  onRemove,
}: {
  line: QuoteLine;
  onPrice: (v: number) => void;
  onStep: (delta: number) => void;
  onToggleInclusive: () => void;
  onRemove: () => void;
}) {
  const t = useTranslations("quotations");
  const gross = line.quantity * line.unitPrice;
  const lineTotal = line.isPriceInclusive ? gross : gross * (1 + line.taxPercent / 100);
  return (
    <div className="flex flex-wrap items-end gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{line.name}</p>
        <p className="truncate text-body-sm text-muted">
          {line.taxPercent > 0 ? `${line.taxPercent}% GST` : t("line.noGst")}
          {line.sku ? ` · ${line.sku}` : ""}
        </p>
      </div>
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-subtle">{t("line.rate")}</span>
        <input
          inputMode="decimal"
          value={line.unitPrice}
          onChange={(e) => onPrice(Number(e.target.value) || 0)}
          className={priceInput}
        />
      </label>
      <button
        type="button"
        onClick={onToggleInclusive}
        title={t(line.isPriceInclusive ? "line.priceInclusiveHint" : "line.priceExclusiveHint")}
        className="mb-0.5 inline-flex h-6 items-center rounded-full border border-hairline px-sm text-body-sm text-muted transition-colors hover:bg-surface-tint"
      >
        {t(line.isPriceInclusive ? "line.priceInclusive" : "line.priceExclusive")}
      </button>
      <div className="flex items-center gap-xs">
        <button
          type="button"
          onClick={() => onStep(-1)}
          aria-label={t("line.decrease")}
          className="inline-flex size-8 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint"
        >
          <Minus size={14} />
        </button>
        <span className="min-w-8 text-center text-body-md tabular-nums text-ink">{line.quantity}</span>
        <button
          type="button"
          onClick={() => onStep(1)}
          aria-label={t("line.increase")}
          className="inline-flex size-8 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint"
        >
          <Plus size={14} />
        </button>
      </div>
      <span className="min-w-24 text-right text-body-md font-semibold text-ink">{formatINR2(lineTotal)}</span>
      <button
        type="button"
        onClick={onRemove}
        aria-label={t("line.remove")}
        className="inline-flex size-9 items-center justify-center rounded-button text-muted transition-colors hover:bg-error-soft hover:text-error"
      >
        <Trash2 size={16} />
      </button>
    </div>
  );
}

function Row({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex items-center justify-between py-xs">
      <span className="text-body-md text-muted">{label}</span>
      <span className="text-body-md tabular-nums text-ink">{formatINR2(value)}</span>
    </div>
  );
}
