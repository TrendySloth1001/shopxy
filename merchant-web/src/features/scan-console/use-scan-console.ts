"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { clearConsole, requestTicket, wsBase } from "./api";
import {
  scanEventSchema,
  type ConsoleRow,
  type ConsoleStatus,
  type Presence,
  type ScanItem,
} from "./types";

const MAX_BACKOFF_MS = 8_000;

/**
 * Live scan-console connection. Mints a ticket, opens the backend WebSocket,
 * and folds incoming scans into a quantity-aggregated row list (scanning the
 * same code again bumps its qty, POS-style). Reconnects with a fresh ticket on
 * drop, with capped exponential backoff.
 */
export function useScanConsole() {
  const t = useTranslations("scanConsole");
  const [rows, setRows] = useState<ConsoleRow[]>([]);
  const [status, setStatus] = useState<ConsoleStatus>("connecting");
  const [presence, setPresence] = useState<Presence>({ consoles: 0, scanners: 0 });
  const [error, setError] = useState<string | null>(null);

  const wsRef = useRef<WebSocket | null>(null);
  const closedRef = useRef(false);
  const attemptRef = useRef(0);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Indirection so `connect` and the reconnect scheduler can reference each
  // other without a forward declaration.
  const connectRef = useRef<() => void>(() => {});

  const upsert = useCallback((scan: ScanItem) => {
    setRows((prev) => {
      const existing = prev.find((r) => r.productId === scan.productId);
      if (existing) {
        // Bump qty and float the just-scanned row to the top.
        const bumped: ConsoleRow = {
          ...existing,
          qty: existing.qty + 1,
          lastScannedAt: scan.scannedAt,
        };
        return [bumped, ...prev.filter((r) => r.productId !== scan.productId)];
      }
      const row: ConsoleRow = {
        productId: scan.productId,
        name: scan.name,
        sku: scan.sku,
        barcode: scan.barcode,
        unitPrice: Number(scan.sellingPrice) || 0,
        mrp: scan.mrp != null ? Number(scan.mrp) : null,
        imageUrl: scan.imageUrl,
        qty: 1,
        lastScannedAt: scan.scannedAt,
      };
      return [row, ...prev];
    });
  }, []);

  const scheduleReconnect = useCallback(() => {
    if (closedRef.current || timerRef.current) return;
    const delay = Math.min(MAX_BACKOFF_MS, 1_000 * 2 ** attemptRef.current);
    attemptRef.current += 1;
    timerRef.current = setTimeout(() => {
      timerRef.current = null;
      connectRef.current();
    }, delay);
  }, []);

  const connect = useCallback(async () => {
    if (closedRef.current) return;
    try {
      const ticket = await requestTicket();
      if (closedRef.current) return;

      const ws = new WebSocket(`${wsBase()}${ticket.path}?ticket=${ticket.ticket}&role=console`);
      wsRef.current = ws;

      ws.onopen = () => {
        attemptRef.current = 0;
        setError(null);
      };

      ws.onmessage = (ev) => {
        let parsed: unknown;
        try {
          parsed = JSON.parse(typeof ev.data === "string" ? ev.data : "");
        } catch {
          return;
        }
        const result = scanEventSchema.safeParse(parsed);
        if (!result.success) return;
        const event = result.data;
        if (event.type === "connected") {
          setStatus("live");
          setPresence(event.presence);
        } else if (event.type === "presence") setPresence(event.presence);
        else if (event.type === "scan") upsert(event.scan);
        else if (event.type === "clear") setRows([]);
      };

      ws.onerror = () => {
        // Let onclose drive the reconnect; closing here makes that deterministic.
        ws.close();
      };

      ws.onclose = () => {
        if (closedRef.current) return;
        wsRef.current = null;
        setStatus("reconnecting");
        setPresence({ consoles: 0, scanners: 0 });
        scheduleReconnect();
      };
    } catch (e) {
      if (closedRef.current) return;
      setError(e instanceof Error ? e.message : t("errors.connectionFailed"));
      setStatus("reconnecting");
      scheduleReconnect();
    }
  }, [upsert, scheduleReconnect, t]);

  useEffect(() => {
    connectRef.current = () => void connect();
  }, [connect]);

  useEffect(() => {
    closedRef.current = false;
    attemptRef.current = 0;
    void connect();
    return () => {
      closedRef.current = true;
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
      wsRef.current?.close();
      wsRef.current = null;
    };
  }, [connect]);

  const clear = useCallback(async () => {
    setRows([]); // optimistic; the backend 'clear' broadcast confirms for all consoles
    try {
      await clearConsole();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("errors.clearFailed"));
    }
  }, [t]);

  const totals = useMemo(() => {
    let qty = 0;
    let value = 0;
    for (const r of rows) {
      qty += r.qty;
      value += r.unitPrice * r.qty;
    }
    return { qty, value, distinct: rows.length };
  }, [rows]);

  return { rows, status, error, clear, totals, presence };
}
