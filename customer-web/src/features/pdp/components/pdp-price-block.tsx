"use client";

import { useEffect, useRef, useState } from "react";
import { Zap, Truck, RotateCcw, ShieldCheck } from "lucide-react";
import { formatINR } from "@/shared/format";
import { type ProductDetail, type Variant, type FlashSale, getActiveFlashSale } from "../types";

interface Props {
  product: ProductDetail;
  selectedVariant: Variant | null;
}

// ── Assurance block (delivery / returns / authentic) ──────────────────────────

function AssuranceBlock() {
  // Shop returns info is not on the PDP payload — show generic trust copy
  const rows: { icon: React.ReactNode; text: React.ReactNode }[] = [
    {
      icon: <Truck size={14} className="text-brand" aria-hidden />,
      text: (
        <span>
          Free delivery{" "}
          <span className="font-normal text-muted">· 3–5 days · merchant confirms</span>
        </span>
      ),
    },
    {
      icon: <RotateCcw size={14} className="text-brand" aria-hidden />,
      text: <span>7-day returns</span>,
    },
    {
      icon: <ShieldCheck size={14} className="text-brand" aria-hidden />,
      text: <span>100% authentic</span>,
    },
  ];

  return (
    <div className="mx-0 mt-sm rounded-md border border-hairline bg-white">
      {rows.map((row, i) => (
        <div key={i}>
          {i > 0 ? <div className="mx-md border-t border-hairline" /> : null}
          <div className="flex items-center gap-sm px-md py-sm">
            <span className="flex w-5 shrink-0 items-center justify-center">{row.icon}</span>
            <span className="text-body-sm font-semibold text-ink">{row.text}</span>
          </div>
        </div>
      ))}
    </div>
  );
}


function fmtCountdown(ms: number): string {
  if (ms <= 0) return "00:00:00";
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

function FlashChip({ sale }: { sale: FlashSale }) {
  // Initialise to a positive sentinel so the chip shows on first render.
  // The effect immediately schedules an update via setTimeout(0) to set the real value.
  const [remaining, setRemaining] = useState(1);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    const tick = () => {
      const ms = new Date(sale.endAt).getTime() - Date.now();
      setRemaining(ms);
      if (ms <= 0 && timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
    };
    // First tick asynchronously to avoid setState-in-effect body
    const init = setTimeout(tick, 0);
    timerRef.current = setInterval(tick, 1000);
    return () => {
      clearTimeout(init);
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [sale.endAt]);

  if (remaining <= 0) return null;

  const remaining2 = sale.stockLimit > 0 ? sale.stockLimit - sale.soldCount : null;

  return (
    <div className="mt-sm flex items-center gap-sm rounded-sm bg-[#FFE3D2] px-md py-xs">
      <Zap size={14} className="text-[#E05A2A]" aria-hidden />
      <span className="text-label-md font-extrabold text-warning">
        Flash deal · ends in {fmtCountdown(remaining)}
      </span>
      {remaining2 != null && remaining2 > 0 ? (
        <span className="text-label-md text-warning">{remaining2} left</span>
      ) : null}
    </div>
  );
}

export function PdpPriceBlock({ product, selectedVariant }: Props) {
  const flash = getActiveFlashSale(product);
  // FlashPriceDisplay renders with flash awareness; it's a client component that
  // reads "now" from state (not during render) to avoid the purity violation.
  return (
    <PdpPriceBlockInner
      product={product}
      selectedVariant={selectedVariant}
      flash={flash}
    />
  );
}

interface InnerProps {
  product: Props["product"];
  selectedVariant: Props["selectedVariant"];
  flash: FlashSale | null;
}

function PdpPriceBlockInner({ product, selectedVariant, flash }: InnerProps) {
  // Track whether the flash sale is still live. We initialise from an effect
  // rather than directly calling Date.now() during render.
  const [isFlashActive, setIsFlashActive] = useState(false);

  useEffect(() => {
    if (!flash) {
      const id = setTimeout(() => setIsFlashActive(false), 0);
      return () => clearTimeout(id);
    }
    const update = () => {
      const active = new Date(flash.endAt).getTime() > Date.now();
      setIsFlashActive(active);
    };
    const id = setInterval(update, 1000);
    // schedule first check asynchronously
    const init = setTimeout(update, 0);
    return () => { clearInterval(id); clearTimeout(init); };
  }, [flash]);

  const basePrice = selectedVariant?.sellingPrice ?? product.sellingPrice;
  const baseMrp = selectedVariant?.mrp ?? product.mrp;
  const displayPrice = isFlashActive && flash ? flash.flashPrice : basePrice;

  const isDiscounted = baseMrp > 0 && baseMrp > displayPrice;
  const pct = isDiscounted ? Math.round(((baseMrp - displayPrice) / baseMrp) * 100) : 0;

  const savedAmount = isDiscounted ? baseMrp - displayPrice : 0;

  return (
    <div className="px-lg pb-sm pt-xs">
      <div className="flex flex-wrap items-end gap-sm">
        <span className="text-[26px] font-black leading-none tracking-tight text-ink">
          {formatINR(displayPrice)}
        </span>
        {isDiscounted ? (
          <>
            <span className="mb-[2px] text-body-md text-muted line-through">
              M.R.P. {formatINR(baseMrp)}
            </span>
            <span className="mb-[2px] rounded-xs bg-success-soft px-sm py-xs text-label-md font-extrabold text-success">
              {pct}% off
            </span>
          </>
        ) : null}
      </div>
      {isDiscounted && savedAmount > 0 ? (
        <div className="mt-sm inline-flex items-center gap-xs rounded-full bg-success-soft px-md py-xs">
          <span className="text-label-md font-extrabold text-success">
            You save {formatINR(savedAmount)} ({pct}%)
          </span>
        </div>
      ) : null}
      {product.taxPercent > 0 ? (
        <p className="mt-xs text-label-md text-muted">Inclusive of all taxes</p>
      ) : null}
      {isFlashActive && flash ? <FlashChip sale={flash} /> : null}

      {/* Assurance rows: free delivery · returns · authentic */}
      <AssuranceBlock />
    </div>
  );
}
