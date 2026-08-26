"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Search, X, Plus, Check, FileText, Send, Download } from "@/shared/icons";
import { formatINR2 } from "@/shared/money";
import { gstFromInclusive } from "@/features/products/gst";
import { getProduct, listProducts } from "@/features/products/api";
import { ProductThumb } from "@/features/products/components/product-thumb";
import type { Product } from "@/features/products/schema";
import { PickerModal } from "@/shared/ui/picker-modal";
import {
  createQuotation,
  getQuotation,
  listQuotations,
  quotationPdfUrl,
  respondQuotation,
  type QuotationItemWrite,
} from "@/features/quotations/api";
import { QUOTATION_STATUS_LABELS, type Quotation } from "@/features/quotations/schema";
import { listParties } from "@/features/parties/api";

const num = (s: string): number => {
  const v = Number.parseFloat(s);
  return Number.isFinite(v) ? v : 0;
};
const onlyNum = (s: string) => s.replace(/[^0-9.]/g, "");
const fmtNum = (n: number, dp = 2): string =>
  new Intl.NumberFormat("en-IN", { maximumFractionDigits: dp }).format(Number.isFinite(n) ? n : 0);
const fmtPct = (n: number): string =>
  Number.isFinite(n) ? `${Number.parseFloat(n.toFixed(2))}%` : "—";
const round2 = (n: number): number => Math.round(n * 100) / 100;

type PartyRef = { id: string; name: string };

type Tone = "ink" | "success" | "error";
const toneText = (t?: Tone) =>
  t === "success" ? "text-success" : t === "error" ? "text-error" : "text-ink";

type Unit = "pct" | "amt";
type Line = { product: Product; priceStr: string; qtyStr: string; rateStr: string; discStr: string };

function lineFrom(p: Product): Line {
  return {
    product: p,
    priceStr: p.sellingPrice ? String(p.sellingPrice) : "",
    qtyStr: "1",
    rateStr: String(p.taxPercent || 0),
    discStr: "",
  };
}

function discountOf(base: number, value: string, unit: Unit): number {
  const v = Math.max(0, num(value));
  return unit === "pct" ? (base * Math.min(100, v)) / 100 : Math.min(base, v);
}

export function CalculatorSuite({ quotationId }: { quotationId?: string } = {}) {
  const t = useTranslations("reports");
  const topRef = useRef<HTMLDivElement>(null);
  const autoLoaded = useRef(false);

  const [search, setSearch] = useState("");
  const [products, setProducts] = useState<Product[]>([]);
  const [listLoading, setListLoading] = useState(true);
  const [lines, setLines] = useState<Line[]>([]);
  const [interState, setInterState] = useState(false);
  const [discUnit, setDiscUnit] = useState<Unit>("pct");
  const [overallStr, setOverallStr] = useState("");

  const [quote, setQuote] = useState<Quotation | null>(null);
  const [party, setParty] = useState<PartyRef | null>(null);
  const [note, setNote] = useState("");
  const [picker, setPicker] = useState<"quotation" | "party" | null>(null);
  const [sending, setSending] = useState(false);
  const [sendMsg, setSendMsg] = useState<{ ok?: string; err?: string } | null>(null);

  useEffect(() => {
    let active = true;
    const id = setTimeout(() => {
      setListLoading(true);
      const q = search.trim();
      listProducts({ limit: "40", ...(q ? { search: q } : {}) })
        .then((page) => active && setProducts(page.data))
        .catch(() => active && setProducts([]))
        .finally(() => active && setListLoading(false));
    }, 200);
    return () => {
      active = false;
      clearTimeout(id);
    };
  }, [search]);

  const has = (id: string) => lines.some((l) => l.product.id === id);

  async function toggleLine(p: Product) {
    if (has(p.id)) {
      setLines((ls) => ls.filter((l) => l.product.id !== p.id));
      return;
    }
    try {
      const full = await getProduct(p.id);
      setLines((ls) => (ls.some((l) => l.product.id === full.id) ? ls : [...ls, lineFrom(full)]));
    } catch {
    }
  }

  function patch(id: string, key: "priceStr" | "qtyStr" | "rateStr" | "discStr", v: string) {
    setLines((ls) => ls.map((l) => (l.product.id === id ? { ...l, [key]: onlyNum(v) } : l)));
  }

  useEffect(() => {
    if (autoLoaded.current || products.length === 0) return;
    autoLoaded.current = true;
    void getProduct(products[0].id)
      .then((full) => setLines((ls) => (ls.length ? ls : [lineFrom(full)])))
      .catch(() => {});
  }, [products]);

  async function importQuotation(q: Quotation) {
    const built = await Promise.all(
      q.items.map(async (it) => {
        try {
          const full = await getProduct(it.productId);
          const incl = 1 + (it.taxPercent || 0) / 100;
          return {
            product: full,
            priceStr: String(round2(it.unitPrice * incl)),
            qtyStr: String(it.quantity || 1),
            rateStr: String(it.taxPercent || 0),
            discStr: it.discount ? String(round2(it.discount * incl)) : "",
          } as Line;
        } catch {
          return null;
        }
      }),
    );
    setDiscUnit("amt");
    setOverallStr("");
    setLines(built.filter((l): l is Line => l != null));
    setQuote(q);
    setParty(q.party ? { id: q.party.id, name: q.party.name } : null);
    setNote(q.note ?? "");
    setSendMsg(null);
  }

  async function loadQuotationById(id: string) {
    try {
      await importQuotation(await getQuotation(id));
    } catch (e) {
      setSendMsg({ err: e instanceof Error ? e.message : t("calc.loadQuoteError") });
    }
  }

  useEffect(() => {
    if (!quotationId) return;
    autoLoaded.current = true;
    void (async () => {
      await loadQuotationById(quotationId);
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [quotationId]);

  function resetQuote() {
    setQuote(null);
    setParty(null);
    setNote("");
    setSendMsg(null);
  }

  function buildItems(): QuotationItemWrite[] {
    const computed = lines.map((l) => {
      const price = Math.max(0, num(l.priceStr));
      const qty = Math.max(0, num(l.qtyStr));
      const rate = Math.min(100, Math.max(0, num(l.rateStr)));
      const grossInclLine = price * qty;
      const lineDiscIncl = discountOf(grossInclLine, l.discStr, discUnit);
      return { l, price, qty, rate, grossInclLine, lineDiscIncl, netIncl: grossInclLine - lineDiscIncl };
    });
    const after = computed.reduce((s, c) => s + c.netIncl, 0);
    const overallIncl = discountOf(after, overallStr, discUnit);
    return computed
      .filter((c) => c.qty > 0 && c.price > 0)
      .map((c) => {
        const share = after > 0 ? overallIncl * (c.netIncl / after) : 0;
        const totalDiscIncl = Math.min(c.grossInclLine, c.lineDiscIncl + share);
        const factor = 100 / (100 + c.rate);
        return {
          productId: c.l.product.id,
          name: c.l.product.name,
          sku: c.l.product.sku || undefined,
          quantity: c.qty,
          unitPrice: round2(c.price * factor),
          taxPercent: c.rate,
          discount: round2(totalDiscIncl * factor),
          imageUrl: c.l.product.images[0]?.url || undefined,
        };
      });
  }

  async function persistQuote(): Promise<Quotation | null> {
    const items = buildItems();
    if (items.length === 0) {
      setSendMsg({ err: t("calc.needProduct") });
      return null;
    }
    const requested = quote?.status === "REQUESTED";
    if (!requested && !party) {
      setSendMsg({ err: t("calc.chooseCustomerFirst") });
      return null;
    }
    setSending(true);
    setSendMsg(null);
    try {
      const trimmedNote = note.trim() || undefined;
      const saved =
        requested && quote
          ? await respondQuotation(quote.id, {
              items,
              note: trimmedNote,
              placeOfSupplyStateCode: quote.placeOfSupplyStateCode ?? undefined,
            })
          : await createQuotation({ partyId: party!.id, items, note: trimmedNote });
      setQuote(saved);
      return saved;
    } catch (e) {
      setSendMsg({ err: e instanceof Error ? e.message : t("calc.saveError") });
      return null;
    } finally {
      setSending(false);
    }
  }

  async function send() {
    const saved = await persistQuote();
    if (saved) {
      setSendMsg({ ok: t("calc.sentMsg", { no: saved.quotationNo, name: saved.party?.name ?? t("calc.theCustomer") }) });
    }
  }

  async function download() {
    const saved = quote ?? (await persistQuote());
    if (saved) window.open(quotationPdfUrl(saved.id), "_blank", "noopener,noreferrer");
  }

  let grossIncl = 0;
  let lineDiscTotal = 0;
  let taxAfterLines = 0;
  let gstAfterLines = 0;
  let totalCost = 0;
  let totalQty = 0;
  for (const l of lines) {
    const p = l.product;
    const price = Math.max(0, num(l.priceStr));
    const q = Math.max(0, num(l.qtyStr));
    const rate = Math.min(100, Math.max(0, num(l.rateStr)));
    const bk = gstFromInclusive(price, rate);
    const grossLine = price * q;
    const lineDisc = discountOf(grossLine, l.discStr, discUnit);
    const net = grossLine - lineDisc;
    const f = grossLine > 0 ? net / grossLine : 0;
    grossIncl += grossLine;
    lineDiscTotal += lineDisc;
    taxAfterLines += bk.taxable * q * f;
    gstAfterLines += bk.gst * q * f;
    totalCost += p.purchasePrice * q;
    totalQty += q;
  }
  const afterLines = grossIncl - lineDiscTotal;
  const overallDisc = discountOf(afterLines, overallStr, discUnit);
  const grandTotal = afterLines - overallDisc;
  const g = afterLines > 0 ? grandTotal / afterLines : 0;
  const finalTaxable = taxAfterLines * g;
  const finalGst = gstAfterLines * g;
  const cgst = interState ? 0 : finalGst / 2;
  const igst = interState ? finalGst : 0;
  const totalProfit = grandTotal - totalCost;
  const margin = grandTotal > 0 ? (totalProfit / grandTotal) * 100 : 0;
  const markup = totalCost > 0 ? (totalProfit / totalCost) * 100 : 0;
  const profitTone: Tone = totalProfit < 0 ? "error" : totalProfit > 0 ? "success" : "ink";
  const totalDisc = lineDiscTotal + overallDisc;

  return (
    <div ref={topRef} className="flex flex-col gap-xl lg:flex-row lg:items-start lg:gap-xxl">
      <section className="min-w-0 lg:flex-1">
        <h2 className="text-headline-sm text-ink">{t("calc.title")}</h2>
        <p className="mt-xs text-body-md text-muted">
          {t("calc.blurb")}
        </p>

        <div className="mt-lg">
          {lines.length === 0 ? (
            <p className="rounded-md border border-dashed border-hairline px-md py-xl text-center text-body-sm text-muted">
              {t("calc.noProductsYet")}
            </p>
          ) : (
            <div>
              <div className="hidden items-center gap-sm border-b border-hairline pb-sm text-label-md uppercase tracking-wide text-subtle md:flex">
                <span className="flex-1">{t("calc.colProduct")}</span>
                <span className="w-16 text-center">{t("calc.colGst")}</span>
                <span className="w-16 text-center">{t("calc.colQty")}</span>
                <span className="w-20 text-center">{t("calc.colDisc")}</span>
                <span className="w-24 text-right">{t("calc.colLineTotal")}</span>
                <span className="w-6" />
              </div>
              {lines.map((l) => (
                <LineRow
                  key={l.product.id}
                  line={l}
                  unit={discUnit}
                  onPrice={(v) => patch(l.product.id, "priceStr", v)}
                  onQty={(v) => patch(l.product.id, "qtyStr", v)}
                  onRate={(v) => patch(l.product.id, "rateStr", v)}
                  onDisc={(v) => patch(l.product.id, "discStr", v)}
                  onRemove={() => toggleLine(l.product)}
                />
              ))}
            </div>
          )}
        </div>

        <div className="mt-lg flex flex-wrap items-end gap-x-xl gap-y-md">
          <div className="flex flex-col gap-xs">
            <span className="text-label-md text-muted">{t("calc.supply")}</span>
            <Choice
              value={interState ? "inter" : "intra"}
              onChange={(v) => setInterState(v === "inter")}
              options={[
                { value: "intra", label: t("calc.withinState") },
                { value: "inter", label: t("calc.interState") },
              ]}
            />
          </div>
          <div className="flex flex-col gap-xs">
            <span className="text-label-md text-muted">{t("calc.discountIn")}</span>
            <Choice
              value={discUnit}
              onChange={(v) => setDiscUnit(v as Unit)}
              options={[
                { value: "pct", label: "%" },
                { value: "amt", label: "₹" },
              ]}
            />
          </div>
          <div className="flex flex-col gap-xs">
            <span className="text-label-md text-muted">{t("calc.overallDiscount")}</span>
            <DiscInput value={overallStr} onChange={setOverallStr} unit={discUnit} ariaLabel={t("calc.overallDiscount")} className="w-28" />
          </div>
        </div>

        <div className="mt-xl border-t border-hairline pt-xl">
          <div className="flex flex-wrap items-end justify-between gap-lg">
            <div className="min-w-0">
              <p className="text-label-md uppercase tracking-wide text-subtle">{t("calc.grandTotalLabel")}</p>
              <p className="mt-xs text-headline-md tabular-nums text-ink">{formatINR2(grandTotal)}</p>
              <p className="mt-xs text-body-sm text-subtle">
                {t("calc.productsQty", { count: lines.length, qty: fmtNum(totalQty) })}
                {totalDisc > 0 ? t("calc.offSuffix", { amount: formatINR2(totalDisc) }) : ""}
              </p>
            </div>
            <div className="flex flex-wrap gap-x-xl gap-y-md">
              <Kpi label={t("calc.profit")} value={formatINR2(totalProfit)} tone={profitTone} />
              <Kpi label={t("calc.margin")} value={fmtPct(margin)} tone={profitTone} />
              <Kpi label={t("calc.gst")} value={formatINR2(finalGst)} />
            </div>
          </div>

          <div className="mt-xl grid grid-cols-1 gap-x-xxl gap-y-xl sm:grid-cols-2">
            <Block label={t("calc.blockTotal")}>
              <R label={t("calc.grossSubtotal")} hint={t("calc.inclGst")} value={formatINR2(grossIncl)} />
              {lineDiscTotal > 0 ? (
                <R label={t("calc.lineDiscounts")} value={`− ${formatINR2(lineDiscTotal)}`} tone="success" />
              ) : null}
              {overallDisc > 0 ? (
                <R label={t("calc.overallDiscount")} value={`− ${formatINR2(overallDisc)}`} tone="success" />
              ) : null}
              <Total label={t("calc.grandTotalInclGst")} value={formatINR2(grandTotal)} />
            </Block>

            <Block label={interState ? t("calc.blockGstInter") : t("calc.blockGstIntra")}>
              <R label={t("calc.subtotal")} hint={t("calc.taxableExGst")} value={formatINR2(finalTaxable)} />
              {interState ? (
                <R label={t("gst.igst")} value={formatINR2(igst)} />
              ) : (
                <>
                  <R label={t("gst.cgst")} value={formatINR2(cgst)} />
                  <R label={t("gst.sgst")} value={formatINR2(cgst)} />
                </>
              )}
              <Total label={t("calc.gstTotal")} value={formatINR2(finalGst)} />
            </Block>

            <Block label={t("calc.profit")}>
              <R label={t("calc.costOfGoods")} value={formatINR2(totalCost)} />
              <R label={t("calc.revenue")} hint={t("calc.inclGst")} value={formatINR2(grandTotal)} />
              <R label={t("calc.profit")} value={formatINR2(totalProfit)} strong tone={profitTone} />
              <R label={t("calc.markup")} hint={t("calc.returnOnCost")} value={fmtPct(markup)} />
              <Total label={t("calc.profitMargin")} value={fmtPct(margin)} tone={profitTone} />
            </Block>
          </div>
        </div>

        <div className="mt-xxl border-t border-hairline pt-lg">
          <div className="flex flex-wrap items-baseline justify-between gap-md">
            <p className="text-label-md uppercase tracking-wide text-subtle">{t("calc.quotation")}</p>
            {quote ? (
              <span className="text-body-sm text-muted">
                {quote.quotationNo} · {QUOTATION_STATUS_LABELS[quote.status] ?? quote.status}
                {quote.party ? ` · ${quote.party.name}` : ""}
              </span>
            ) : null}
          </div>

          <div className="mt-sm flex flex-wrap items-center gap-sm">
            <button
              type="button"
              onClick={() => setPicker("quotation")}
              className="inline-flex h-10 items-center gap-sm rounded-full border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
            >
              <FileText size={16} /> {t("calc.loadQuotation")}
            </button>

            {quote?.status === "REQUESTED" ? null : (
              <button
                type="button"
                onClick={() => setPicker("party")}
                className={`inline-flex h-10 items-center gap-sm rounded-full border px-md text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
                  party
                    ? "border-hairline text-ink hover:bg-surface-tint"
                    : "border-dashed border-hairline text-muted hover:bg-surface-tint"
                }`}
              >
                <Plus size={15} /> {party ? party.name : t("calc.chooseCustomer")}
              </button>
            )}

            <span className="ml-auto flex items-center gap-sm">
              <button
                type="button"
                onClick={download}
                disabled={sending || lines.length === 0}
                className="inline-flex h-10 items-center gap-sm rounded-full border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled disabled:hover:bg-transparent"
              >
                <Download size={16} /> {t("calc.download")}
              </button>

              <button
                type="button"
                onClick={send}
                disabled={sending || lines.length === 0}
                className="group inline-flex h-10 items-center gap-sm rounded-full bg-brand pl-lg pr-md text-label-md font-semibold text-white shadow-floating transition-all hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft focus-visible:ring-offset-2 focus-visible:ring-offset-canvas disabled:bg-disabled disabled:shadow-none"
              >
                {sending ? t("calc.sending") : quote?.status === "REQUESTED" ? t("calc.priceAndSend") : t("calc.sendQuotation")}
                <span className="flex size-6 items-center justify-center rounded-full bg-white/20 transition-transform group-hover:translate-x-px">
                  <Send size={14} />
                </span>
              </button>

              {quote ? (
                <button
                  type="button"
                  onClick={resetQuote}
                  className="inline-flex h-10 items-center rounded-full px-md text-label-md text-muted transition-colors hover:text-ink"
                >
                  {t("calc.new")}
                </button>
              ) : null}
            </span>
          </div>

          <label className="mt-md flex max-w-content flex-col gap-xs">
            <span className="text-label-md text-muted">{t("calc.noteLabel")}</span>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              rows={2}
              placeholder={t("calc.notePlaceholder")}
              className="w-full rounded-input border border-hairline bg-field px-md py-sm text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
            />
          </label>

          {sendMsg ? (
            <p className={`mt-sm text-body-sm ${sendMsg.err ? "text-error" : "text-success"}`}>
              {sendMsg.err ?? sendMsg.ok}
            </p>
          ) : null}
          <p className="mt-sm text-body-sm text-subtle">
            {t("calc.quotationHelp")}
          </p>
        </div>
      </section>

      <aside className="min-w-0 lg:w-96 lg:shrink-0 lg:border-l lg:border-hairline lg:pl-xl">
        <div className="flex items-baseline justify-between gap-md">
          <p className="text-label-md uppercase tracking-wide text-subtle">{t("calc.yourProducts")}</p>
          {lines.length > 0 ? (
            <span className="text-body-sm tabular-nums text-subtle">{t("calc.addedCount", { count: lines.length })}</span>
          ) : null}
        </div>
        <div className="mt-sm flex items-center gap-sm rounded-input border border-hairline bg-field px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
          <Search size={16} className="shrink-0 text-subtle" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t("calc.searchByNameSku")}
            aria-label={t("calc.searchProducts")}
            className="h-11 flex-1 bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
          />
          {search ? (
            <button
              type="button"
              onClick={() => setSearch("")}
              aria-label={t("calc.clear")}
              className="shrink-0 text-subtle transition-colors hover:text-ink"
            >
              <X size={16} />
            </button>
          ) : null}
        </div>

        <div className="mt-md">
          {listLoading && products.length === 0 ? (
            <p className="py-lg text-center text-body-sm text-subtle">{t("calc.loadingProducts")}</p>
          ) : products.length === 0 ? (
            <p className="py-lg text-center text-body-sm text-muted">{t("calc.noProductsFound")}</p>
          ) : (
            <ul className="grid grid-cols-1 gap-xs">
              {products.map((p) => (
                <li key={p.id}>
                  <ProductTile p={p} added={has(p.id)} onToggle={() => toggleLine(p)} />
                </li>
              ))}
            </ul>
          )}
        </div>
      </aside>

      {picker === "quotation" ? (
        <PickerModal
          title={t("calc.loadQuotation")}
          placeholder={t("calc.searchNumberOrCustomer")}
          load={(s) =>
            listQuotations().then((qs) =>
              s
                ? qs.filter(
                    (q) =>
                      q.quotationNo.toLowerCase().includes(s.toLowerCase()) ||
                      (q.party?.name ?? "").toLowerCase().includes(s.toLowerCase()),
                  )
                : qs,
            )
          }
          rowOf={(q) => ({
            title: q.quotationNo,
            subtitle: `${QUOTATION_STATUS_LABELS[q.status] ?? q.status}${q.party ? ` · ${q.party.name}` : ""}`,
            meta: formatINR2(q.total),
          })}
          onPick={(q) => {
            setPicker(null);
            void loadQuotationById(q.id);
          }}
          onClose={() => setPicker(null)}
          emptyHint={t("calc.noQuotations")}
        />
      ) : null}

      {picker === "party" ? (
        <PickerModal
          title={t("calc.chooseCustomer")}
          placeholder={t("calc.searchCustomers")}
          load={(s) => listParties(s ? { search: s } : undefined)}
          rowOf={(pt) => ({ title: pt.name, subtitle: pt.phone ?? undefined })}
          onPick={(pt) => {
            setParty({ id: pt.id, name: pt.name });
            setPicker(null);
          }}
          onClose={() => setPicker(null)}
        />
      ) : null}
    </div>
  );
}

function LineRow({
  line,
  unit,
  onPrice,
  onQty,
  onRate,
  onDisc,
  onRemove,
}: {
  line: Line;
  unit: Unit;
  onPrice: (v: string) => void;
  onQty: (v: string) => void;
  onRate: (v: string) => void;
  onDisc: (v: string) => void;
  onRemove: () => void;
}) {
  const t = useTranslations("reports");
  const p = line.product;
  const price = Math.max(0, num(line.priceStr));
  const qty = Math.max(0, num(line.qtyStr));
  const gross = price * qty;
  const net = gross - discountOf(gross, line.discStr, unit);
  const qtyInput = (
    <input
      type="text"
      inputMode="numeric"
      value={line.qtyStr}
      onChange={(e) => onQty(onlyNum(e.target.value))}
      aria-label={t("calc.qtyFor", { name: p.name })}
      className="h-9 w-16 rounded-button border border-hairline bg-field px-sm text-center text-body-md tabular-nums text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
    />
  );
  return (
    <div className="border-b border-hairline py-sm last:border-b-0">
      <div className="flex items-center gap-sm">
        <ProductThumb url={p.images[0]?.url ?? null} alt={p.name} size={40} />
        <div className="min-w-0 flex-1">
          <span className="block truncate text-body-md text-ink">{p.name}</span>
          <span className="mt-xs flex items-center gap-xs text-body-sm text-subtle">
            <span className="relative">
              <span className="pointer-events-none absolute left-sm top-1/2 -translate-y-1/2 text-body-sm text-subtle">
                ₹
              </span>
              <input
                type="text"
                inputMode="decimal"
                value={line.priceStr}
                onChange={(e) => onPrice(onlyNum(e.target.value))}
                aria-label={t("calc.priceFor", { name: p.name })}
                className="h-8 w-24 rounded-button border border-hairline bg-field pl-lg pr-sm text-body-sm tabular-nums text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
              />
            </span>
            {t("calc.each")}
          </span>
        </div>
        <div className="hidden items-center gap-sm md:flex">
          <Suffixed value={line.rateStr} onChange={onRate} suffix="%" ariaLabel={t("calc.gstFor", { name: p.name })} className="w-16" />
          {qtyInput}
          <DiscInput value={line.discStr} onChange={onDisc} unit={unit} ariaLabel={t("calc.discFor", { name: p.name })} className="w-20" />
          <span className="w-24 text-right text-body-md font-semibold tabular-nums text-ink">
            {formatINR2(net)}
          </span>
        </div>
        <button
          type="button"
          onClick={onRemove}
          aria-label={t("calc.removeName", { name: p.name })}
          className="flex w-6 shrink-0 justify-center text-subtle transition-colors hover:text-error"
        >
          <X size={16} />
        </button>
      </div>

      <div className="mt-sm flex items-end gap-md md:hidden">
        <FieldCol label={t("calc.colGst")}>
          <Suffixed value={line.rateStr} onChange={onRate} suffix="%" ariaLabel={t("calc.gstFor", { name: p.name })} className="w-16" />
        </FieldCol>
        <FieldCol label={t("calc.colQty")}>{qtyInput}</FieldCol>
        <FieldCol label={t("calc.colDisc")}>
          <DiscInput value={line.discStr} onChange={onDisc} unit={unit} ariaLabel={t("calc.discFor", { name: p.name })} className="w-20" />
        </FieldCol>
        <span className="ml-auto text-body-md font-semibold tabular-nums text-ink">{formatINR2(net)}</span>
      </div>
    </div>
  );
}

function FieldCol({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-xs">
      <span className="text-label-md uppercase tracking-wide text-subtle">{label}</span>
      {children}
    </div>
  );
}

function Suffixed({
  value,
  onChange,
  suffix,
  ariaLabel,
  className,
}: {
  value: string;
  onChange: (v: string) => void;
  suffix: string;
  ariaLabel: string;
  className?: string;
}) {
  return (
    <div className={`relative ${className ?? "w-20"}`}>
      <input
        type="text"
        inputMode="decimal"
        value={value}
        onChange={(e) => onChange(onlyNum(e.target.value))}
        aria-label={ariaLabel}
        className="h-9 w-full rounded-button border border-hairline bg-field pl-sm pr-lg text-center text-body-md tabular-nums text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
      />
      <span className="pointer-events-none absolute right-sm top-1/2 -translate-y-1/2 text-body-sm text-subtle">
        {suffix}
      </span>
    </div>
  );
}

function DiscInput({
  value,
  onChange,
  unit,
  ariaLabel,
  className,
}: {
  value: string;
  onChange: (v: string) => void;
  unit: Unit;
  ariaLabel: string;
  className?: string;
}) {
  return (
    <div className={`relative ${className ?? "w-20"}`}>
      {unit === "amt" ? (
        <span className="pointer-events-none absolute left-sm top-1/2 -translate-y-1/2 text-body-sm text-subtle">
          ₹
        </span>
      ) : null}
      <input
        type="text"
        inputMode="decimal"
        value={value}
        onChange={(e) => onChange(onlyNum(e.target.value))}
        placeholder="0"
        aria-label={ariaLabel}
        className={`h-9 w-full rounded-button border border-hairline bg-field text-right text-body-md tabular-nums text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft ${
          unit === "amt" ? "pl-lg" : "pl-sm"
        } ${unit === "pct" ? "pr-lg" : "pr-sm"}`}
      />
      {unit === "pct" ? (
        <span className="pointer-events-none absolute right-sm top-1/2 -translate-y-1/2 text-body-sm text-subtle">
          %
        </span>
      ) : null}
    </div>
  );
}

function ProductTile({ p, added, onToggle }: { p: Product; added: boolean; onToggle: () => void }) {
  const low = p.stockQuantity > 0 && p.stockQuantity <= p.lowStockThreshold;
  return (
    <button
      type="button"
      onClick={onToggle}
      aria-pressed={added}
      className={`flex w-full items-center gap-md rounded-md border px-sm py-sm text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
        added ? "border-brand-soft bg-brand-soft" : "border-hairline hover:bg-surface-tint"
      }`}
    >
      <ProductThumb url={p.images[0]?.url ?? null} alt={p.name} size={40} />
      <div className="min-w-0 flex-1">
        <span className="block truncate text-body-md text-ink">{p.name}</span>
        <span className="block truncate text-body-sm text-subtle">{p.sku}</span>
      </div>
      <div className="shrink-0 text-right">
        <span className="block text-body-sm font-semibold tabular-nums text-ink">
          {formatINR2(p.sellingPrice)}
        </span>
        <span className={`block text-body-sm ${low ? "text-warning" : "text-subtle"}`}>
          {fmtNum(p.stockQuantity)} {p.unit}
        </span>
      </div>
      <span
        className={`flex size-7 shrink-0 items-center justify-center rounded-full ${
          added ? "bg-brand text-white" : "border border-hairline text-subtle"
        }`}
      >
        {added ? <Check size={14} /> : <Plus size={14} />}
      </span>
    </button>
  );
}

function Kpi({ label, value, tone }: { label: string; value: string; tone?: Tone }) {
  return (
    <div>
      <p className="text-label-md uppercase tracking-wide text-subtle">{label}</p>
      <p className={`mt-xs text-title-lg font-semibold tabular-nums ${toneText(tone)}`}>{value}</p>
    </div>
  );
}

function Pill({ on, onClick, children }: { on: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={on}
      className={`inline-flex h-9 items-center rounded-button px-md text-label-md tabular-nums transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
        on ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
      }`}
    >
      {children}
    </button>
  );
}

function Choice({
  value,
  onChange,
  options,
}: {
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <div role="group" className="flex flex-wrap gap-xs">
      {options.map((o) => (
        <Pill key={o.value} on={value === o.value} onClick={() => onChange(o.value)}>
          {o.label}
        </Pill>
      ))}
    </div>
  );
}

function Block({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-sm">
      <p className="text-label-md uppercase tracking-wide text-subtle">{label}</p>
      <dl className="flex flex-col gap-sm">{children}</dl>
    </div>
  );
}

function R({
  label,
  hint,
  value,
  strong,
  tone,
}: {
  label: string;
  hint?: string;
  value: string;
  strong?: boolean;
  tone?: Tone;
}) {
  return (
    <div className="flex items-baseline justify-between gap-md">
      <dt className={`text-body-sm ${strong ? "text-ink" : "text-muted"}`}>
        {label}
        {hint ? <span className="text-subtle"> · {hint}</span> : null}
      </dt>
      <dd className={`tabular-nums ${strong ? "text-body-md font-semibold" : "text-body-sm"} ${toneText(tone)}`}>
        {value}
      </dd>
    </div>
  );
}

function Total({ label, value, tone }: { label: string; value: string; tone?: Tone }) {
  return (
    <div className="mt-xs flex items-baseline justify-between gap-md border-t border-hairline pt-sm">
      <dt className="text-body-md text-ink">{label}</dt>
      <dd className={`text-title-md font-semibold tabular-nums ${toneText(tone)}`}>{value}</dd>
    </div>
  );
}
