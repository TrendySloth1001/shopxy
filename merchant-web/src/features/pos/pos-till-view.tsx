"use client";

import { useState } from "react";
import Image from "next/image";
import { ImageOff, Minus, Plus, ScanBarcode, Trash2, Wifi, WifiOff, Loader2, CheckCircle2 } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { formatINR2 } from "@/shared/money";
import { usePosSale } from "./use-pos-sale";
import { TENDER_MODES, type ConnStatus, type SaleLine, type TenderMode } from "./types";

export function PosTillView() {
  const pos = usePosSale();
  const [code, setCode] = useState("");

  if (pos.checkout) {
    return <CheckoutDone invoiceNo={pos.checkout.invoice.invoiceNo} total={pos.checkout.invoice.total} />;
  }

  const lines = pos.snapshot?.lines ?? [];
  const totals = pos.snapshot?.totals;

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={ScanBarcode}
        tone="indigo"
        title="Point of sale"
        subtitle="Scan items here or from the app — the cart is shared live. Check out to bill."
      >
        <ConnBadge status={pos.status} />
      </PageHeader>

      {pos.error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{pos.error}</p>
      ) : null}
      {pos.unknownCode ? (
        <QuickAddForm
          code={pos.unknownCode}
          onAdd={(v) => void pos.quickAdd(v)}
          onCancel={pos.clearUnknown}
        />
      ) : null}

      <form
        className="mt-lg flex gap-sm"
        onSubmit={(e) => {
          e.preventDefault();
          void pos.scan(code);
          setCode("");
        }}
      >
        <input
          value={code}
          onChange={(e) => setCode(e.target.value)}
          autoFocus
          placeholder="Scan or type a barcode / SKU, then Enter"
          className="h-11 flex-1 rounded-input border border-hairline bg-canvas px-md text-body-md text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
        <button type="submit" className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong">
          <Plus size={16} /> Add
        </button>
      </form>

      <Divider className="my-xl" />

      <div className="grid grid-cols-1 gap-xl lg:grid-cols-[1fr_320px]">
        <div>
          {lines.length === 0 ? (
            <p className="py-xxxl text-center text-body-md text-muted">Cart is empty — scan the first item.</p>
          ) : (
            <ul className="flex flex-col gap-px overflow-hidden rounded-lg border border-hairline">
              {lines.map((l) => (
                <CartRow
                  key={l.productId}
                  line={l}
                  onInc={() => pos.setQty(l.productId, l.quantity + 1)}
                  onDec={() => pos.setQty(l.productId, Math.max(0, l.quantity - 1))}
                  onRemove={() => pos.removeItem(l.productId)}
                />
              ))}
            </ul>
          )}
        </div>

        {totals ? (
          <CheckoutPanel
            totals={totals}
            disabled={lines.length === 0}
            onCheckout={(mode) => void pos.doCheckout(mode)}
          />
        ) : null}
      </div>
    </div>
  );
}

function CartRow({ line, onInc, onDec, onRemove }: { line: SaleLine; onInc: () => void; onDec: () => void; onRemove: () => void }) {
  const src = mediaSrc(line.imageUrl);
  return (
    <li className="flex items-center gap-md bg-canvas px-md py-sm">
      <div className="relative size-12 shrink-0 overflow-hidden rounded-md bg-hero-panel">
        {src ? <Image src={src} alt="" fill unoptimized className="object-cover" sizes="48px" /> : <div className="flex size-full items-center justify-center text-subtle"><ImageOff size={18} /></div>}
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-title-sm font-semibold text-ink">{line.name}</p>
        <p className="truncate text-body-sm text-muted">{line.sku} · {formatINR2(line.unitPrice)}</p>
      </div>
      <div className="flex shrink-0 items-center gap-xs">
        <button type="button" onClick={onDec} aria-label="Decrease" className="inline-flex size-8 items-center justify-center rounded-button border border-hairline text-ink hover:bg-surface-tint"><Minus size={14} /></button>
        <span className="w-6 text-center text-label-md font-bold text-ink">{line.quantity}</span>
        <button type="button" onClick={onInc} aria-label="Increase" className="inline-flex size-8 items-center justify-center rounded-button border border-hairline text-ink hover:bg-surface-tint"><Plus size={14} /></button>
      </div>
      <div className="w-20 shrink-0 text-right text-title-sm font-bold text-ink">{formatINR2(line.total)}</div>
      <button type="button" onClick={onRemove} aria-label="Remove" className="inline-flex size-8 shrink-0 items-center justify-center rounded-button border border-hairline text-muted hover:text-error"><Trash2 size={14} /></button>
    </li>
  );
}

function CheckoutPanel({ totals, disabled, onCheckout }: { totals: NonNullable<ReturnType<typeof usePosSale>["snapshot"]>["totals"]; disabled: boolean; onCheckout: (m: TenderMode) => void }) {
  return (
    <div className="flex h-fit flex-col gap-sm rounded-lg border border-hairline p-lg">
      <Row label="Taxable" value={formatINR2(totals.taxableValue)} />
      {totals.cgst > 0 ? <Row label="CGST" value={formatINR2(totals.cgst)} /> : null}
      {totals.sgst > 0 ? <Row label="SGST" value={formatINR2(totals.sgst)} /> : null}
      {totals.igst > 0 ? <Row label="IGST" value={formatINR2(totals.igst)} /> : null}
      {totals.cess > 0 ? <Row label="Cess" value={formatINR2(totals.cess)} /> : null}
      {totals.roundOff !== 0 ? <Row label="Round off" value={formatINR2(totals.roundOff)} /> : null}
      <Divider className="my-xs" />
      <div className="flex items-center justify-between">
        <span className="text-title-sm font-bold text-ink">Total</span>
        <span className="text-headline-sm font-bold text-ink">{formatINR2(totals.total)}</span>
      </div>
      <p className="mt-sm text-body-sm text-muted">Tender</p>
      <div className="flex flex-wrap gap-sm">
        {TENDER_MODES.map((m) => (
          <button
            key={m}
            type="button"
            disabled={disabled}
            onClick={() => onCheckout(m)}
            className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled"
          >
            {m}
          </button>
        ))}
      </div>
    </div>
  );
}

function QuickAddForm({
  code,
  onAdd,
  onCancel,
}: {
  code: string;
  onAdd: (v: { code: string; name: string; sellingPrice: number; taxPercent?: number; openingStock?: number }) => void;
  onCancel: () => void;
}) {
  const [name, setName] = useState("");
  const [price, setPrice] = useState("");
  const [tax, setTax] = useState("");
  const [stock, setStock] = useState("1");

  const sellingPrice = Number(price);
  const valid = name.trim().length > 0 && sellingPrice > 0;

  return (
    <form
      className="mt-md rounded-lg border border-hairline bg-surface-tint p-md"
      onSubmit={(e) => {
        e.preventDefault();
        if (!valid) return;
        onAdd({
          code,
          name: name.trim(),
          sellingPrice,
          taxPercent: tax ? Number(tax) : undefined,
          openingStock: stock ? Number(stock) : undefined,
        });
      }}
    >
      <p className="text-body-sm text-muted">
        New item for code <span className="font-semibold text-ink">{code}</span> — add it to the catalogue and the cart.
      </p>
      <div className="mt-sm grid grid-cols-2 gap-sm sm:grid-cols-4">
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Name" className="col-span-2 h-10 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft sm:col-span-1" />
        <input value={price} onChange={(e) => setPrice(e.target.value)} inputMode="decimal" placeholder="Price ₹" className="h-10 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
        <input value={tax} onChange={(e) => setTax(e.target.value)} inputMode="decimal" placeholder="GST %" className="h-10 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
        <input value={stock} onChange={(e) => setStock(e.target.value)} inputMode="decimal" placeholder="On hand" className="h-10 rounded-input border border-hairline bg-canvas px-md text-body-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-brand-soft" />
      </div>
      <div className="mt-sm flex items-center gap-sm">
        <button type="submit" disabled={!valid} className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong disabled:bg-disabled">Add to cart</button>
        <button type="button" onClick={onCancel} className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint">Cancel</button>
      </div>
    </form>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between text-body-sm">
      <span className="text-muted">{label}</span>
      <span className="text-ink">{value}</span>
    </div>
  );
}

function ConnBadge({ status }: { status: ConnStatus }) {
  const map: Record<ConnStatus, { label: string; cls: string; icon: typeof Wifi; spin?: boolean }> = {
    live: { label: "Live", cls: "bg-success-soft text-success", icon: Wifi },
    connecting: { label: "Connecting", cls: "bg-surface-tint text-muted", icon: Loader2, spin: true },
    reconnecting: { label: "Reconnecting", cls: "bg-warning-soft text-warning", icon: Loader2, spin: true },
    offline: { label: "Offline", cls: "bg-error-soft text-error", icon: WifiOff },
  };
  const { label, cls, icon: Icon, spin } = map[status];
  return (
    <span className={`inline-flex h-10 items-center gap-xs rounded-button px-md text-label-md ${cls}`}>
      <Icon size={15} className={spin ? "animate-spin" : ""} /> {label}
    </span>
  );
}

function CheckoutDone({ invoiceNo, total }: { invoiceNo: string; total: string }) {
  return (
    <div className="flex min-h-[60vh] w-full flex-col items-center justify-center px-lg py-xxxl text-center">
      <span className="flex size-14 items-center justify-center rounded-full bg-success-soft text-success"><CheckCircle2 size={28} /></span>
      <h1 className="mt-lg text-title-md text-ink">Sale complete</h1>
      <p className="mt-xs text-body-md text-muted">Invoice {invoiceNo} · {formatINR2(Number(total))}</p>
      <button
        type="button"
        onClick={() => window.location.reload()}
        className="mt-xl inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white hover:bg-brand-strong"
      >
        New sale
      </button>
    </div>
  );
}
