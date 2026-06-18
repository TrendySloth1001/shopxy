"use client";

import Image from "next/image";
import {
  ImageOff,
  ScanLine,
  Smartphone,
  Trash2,
  Wifi,
  WifiOff,
  Loader2,
} from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { formatINR2 } from "@/shared/money";
import { formatRelativeTime } from "@/shared/datetime";
import { useScanConsole } from "./use-scan-console";
import type { ConsoleRow, ConsoleStatus } from "./types";

export function ScanConsoleView() {
  const { rows, status, error, clear, totals, presence } = useScanConsole();
  const scannerConnected = status === "live" && presence.scanners > 0;

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={ScanLine}
        tone="indigo"
        title="Scan console"
        subtitle="Open the scanner on the ShopXY app and scan products — they appear here live."
      >
        <StatusBadge status={status} />
        {status === "live" ? (
          <span
            className={`inline-flex h-10 items-center gap-xs rounded-button px-md text-label-md ${
              scannerConnected ? "bg-success-soft text-success" : "bg-surface-tint text-muted"
            }`}
          >
            <Smartphone size={15} />
            {scannerConnected
              ? `Scanner connected${presence.scanners > 1 ? ` ×${presence.scanners}` : ""}`
              : "Waiting for scanner"}
          </span>
        ) : null}
        <button
          type="button"
          onClick={() => void clear()}
          disabled={rows.length === 0}
          className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <Trash2 size={16} /> Clear
        </button>
      </PageHeader>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <Divider className="my-xl" />

      {rows.length === 0 ? (
        <EmptyState status={status} scannerConnected={scannerConnected} />
      ) : (
        <>
          <SummaryBar
            distinct={totals.distinct}
            qty={totals.qty}
            value={totals.value}
          />
          <ul className="mt-lg flex flex-col gap-px overflow-hidden rounded-lg border border-hairline">
            {rows.map((row) => (
              <ScanRow key={row.productId} row={row} />
            ))}
          </ul>
        </>
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: ConsoleStatus }) {
  const map: Record<ConsoleStatus, { label: string; cls: string; icon: typeof Wifi }> = {
    live: { label: "Live", cls: "bg-success-soft text-success", icon: Wifi },
    connecting: { label: "Connecting", cls: "bg-surface-tint text-muted", icon: Loader2 },
    reconnecting: { label: "Reconnecting", cls: "bg-warning-soft text-warning", icon: Loader2 },
    error: { label: "Offline", cls: "bg-error-soft text-error", icon: WifiOff },
  };
  const { label, cls, icon: Icon } = map[status];
  const spin = status === "connecting" || status === "reconnecting";
  return (
    <span className={`inline-flex h-10 items-center gap-xs rounded-button px-md text-label-md ${cls}`}>
      <Icon size={15} className={spin ? "animate-spin" : ""} />
      {label}
    </span>
  );
}

function SummaryBar({ distinct, qty, value }: { distinct: number; qty: number; value: number }) {
  return (
    <div className="flex flex-wrap items-center gap-x-xxl gap-y-sm rounded-lg bg-surface-tint px-lg py-md">
      <Stat label="Products" value={String(distinct)} />
      <Stat label="Items scanned" value={String(qty)} />
      <Stat label="Total value" value={formatINR2(value)} />
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-0">
      <p className="text-body-sm text-muted">{label}</p>
      <p className="text-title-md font-bold text-ink">{value}</p>
    </div>
  );
}

function ScanRow({ row }: { row: ConsoleRow }) {
  const src = mediaSrc(row.imageUrl);
  return (
    <li className="flex items-center gap-md bg-canvas px-md py-sm">
      <div className="relative size-12 shrink-0 overflow-hidden rounded-md bg-hero-panel">
        {src ? (
          <Image src={src} alt="" fill unoptimized className="object-cover" sizes="48px" />
        ) : (
          <div className="flex size-full items-center justify-center text-subtle">
            <ImageOff size={18} />
          </div>
        )}
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-title-sm font-semibold text-ink">{row.name}</p>
        <p className="truncate text-body-sm text-muted">
          {row.sku}
          {row.barcode ? ` · ${row.barcode}` : ""} · {formatRelativeTime(row.lastScannedAt)}
        </p>
      </div>
      <div className="shrink-0 text-right">
        <p className="text-title-sm font-bold text-ink">{formatINR2(row.unitPrice * row.qty)}</p>
        <p className="text-body-sm text-muted">
          {row.qty} × {formatINR2(row.unitPrice)}
        </p>
      </div>
      <span className="ml-xs inline-flex size-7 shrink-0 items-center justify-center rounded-full bg-brand-soft text-label-md font-bold text-brand">
        {row.qty}
      </span>
    </li>
  );
}

function EmptyState({
  status,
  scannerConnected,
}: {
  status: ConsoleStatus;
  scannerConnected: boolean;
}) {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <span className="flex size-12 items-center justify-center rounded-full bg-accent-indigo-soft text-accent-indigo">
        <ScanLine size={22} />
      </span>
      <p className="text-body-md text-muted">
        {status !== "live"
          ? "Connecting to the scan feed…"
          : scannerConnected
            ? "Scanner connected — waiting for the first scan."
            : "Connected — open the scanner on the app to begin."}
      </p>
      <p className="max-w-content text-body-sm text-subtle">
        On the ShopXY app, open the scanner and point it at a product’s barcode or QR.
        Each scan shows up here instantly.
      </p>
    </div>
  );
}
