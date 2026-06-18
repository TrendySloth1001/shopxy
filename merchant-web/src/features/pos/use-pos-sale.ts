"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { requestTicket, wsBase } from "@/features/scan-console/api";
import { posApi } from "./api";
import { saleSnapshotSchema, type ConnStatus, type SaleSnapshot, type TenderMode } from "./types";

type CheckoutResult = Awaited<ReturnType<typeof posApi.checkout>>;

/**
 * Drives one POS sale: opens (or resumes) a sale, mirrors the server-authoritative
 * cart, and keeps it live across devices over the scan-console WebSocket. Every
 * action calls the REST endpoint (which returns the fresh snapshot); the socket
 * delivers changes made on the OTHER till. The server is the source of truth.
 */
export function usePosSale() {
  const [snapshot, setSnapshot] = useState<SaleSnapshot | null>(null);
  const [status, setStatus] = useState<ConnStatus>("connecting");
  const [error, setError] = useState<string | null>(null);
  const [unknownCode, setUnknownCode] = useState<string | null>(null);
  const [checkout, setCheckout] = useState<CheckoutResult | null>(null);

  const saleIdRef = useRef<number | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const closedRef = useRef(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Indirection so the reconnect timer can call connectWs without a forward ref.
  const connectRef = useRef<() => void>(() => {});

  const scheduleReconnect = useCallback((delay: number) => {
    if (closedRef.current || timerRef.current) return;
    timerRef.current = setTimeout(() => {
      timerRef.current = null;
      connectRef.current();
    }, delay);
  }, []);

  const connectWs = useCallback(async () => {
    if (closedRef.current) return;
    try {
      const ticket = await requestTicket();
      if (closedRef.current) return;
      const ws = new WebSocket(`${wsBase()}${ticket.path}?ticket=${ticket.ticket}&role=console`);
      wsRef.current = ws;
      ws.onopen = () => setStatus("live");
      ws.onmessage = (ev) => {
        let msg: unknown;
        try {
          msg = JSON.parse(typeof ev.data === "string" ? ev.data : "");
        } catch {
          return;
        }
        if (typeof msg !== "object" || msg === null) return;
        const m = msg as { type?: string; saleId?: number };
        if (m.saleId !== saleIdRef.current) return; // only our sale
        if (m.type === "pos.sale") {
          const parsed = saleSnapshotSchema.safeParse((m as { snapshot?: unknown }).snapshot);
          if (parsed.success) setSnapshot(parsed.data);
        } else if (m.type === "pos.checkout") {
          // The other till finalised it — reflect the closed state.
          void posApi.get(saleIdRef.current).then(setSnapshot).catch(() => undefined);
        } else if (m.type === "pos.void") {
          void posApi.get(saleIdRef.current).then(setSnapshot).catch(() => undefined);
        }
      };
      ws.onerror = () => ws.close();
      ws.onclose = () => {
        if (closedRef.current) return;
        wsRef.current = null;
        setStatus("reconnecting");
        scheduleReconnect(1500);
      };
    } catch {
      if (closedRef.current) return;
      setStatus("offline");
      scheduleReconnect(2000);
    }
  }, [scheduleReconnect]);

  useEffect(() => {
    connectRef.current = () => void connectWs();
  }, [connectWs]);

  // Open a sale then connect the live channel. One sale per mounted till.
  useEffect(() => {
    closedRef.current = false;
    void (async () => {
      try {
        const s = await posApi.open();
        if (closedRef.current) return;
        saleIdRef.current = s.sale.id;
        setSnapshot(s);
        void connectWs();
      } catch (e) {
        setError(e instanceof Error ? e.message : "Could not open a sale.");
        setStatus("offline");
      }
    })();
    return () => {
      closedRef.current = true;
      if (timerRef.current) clearTimeout(timerRef.current);
      wsRef.current?.close();
    };
  }, [connectWs]);

  // Action wrapper: run a REST mutation, adopt its snapshot, surface errors.
  const run = useCallback(async (fn: (saleId: number) => Promise<SaleSnapshot>) => {
    const saleId = saleIdRef.current;
    if (saleId == null) return;
    setError(null);
    try {
      setSnapshot(await fn(saleId));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Action failed.");
    }
  }, []);

  const scan = useCallback(
    async (code: string) => {
      const saleId = saleIdRef.current;
      if (saleId == null || !code.trim()) return;
      setError(null);
      try {
        const r = await posApi.scan(saleId, code.trim());
        if ("unknown" in r) setUnknownCode(r.code);
        else setSnapshot(r);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Scan failed.");
      }
    },
    [],
  );

  const setQty = useCallback((productId: number, quantity: number) => run((id) => posApi.patchItem(id, productId, { quantity })), [run]);
  const setLineDiscount = useCallback((productId: number, lineDiscount: number) => run((id) => posApi.patchItem(id, productId, { lineDiscount })), [run]);
  const removeItem = useCallback((productId: number) => run((id) => posApi.removeItem(id, productId)), [run]);
  const setHeaderDiscount = useCallback((d: number) => run((id) => posApi.setHeaderDiscount(id, d)), [run]);

  const doCheckout = useCallback(async (mode: TenderMode, modeReference?: string) => {
    const saleId = saleIdRef.current;
    if (saleId == null) return;
    setError(null);
    try {
      const r = await posApi.checkout(saleId, { mode, modeReference });
      setCheckout(r);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Checkout failed.");
    }
  }, []);

  return {
    snapshot,
    status,
    error,
    unknownCode,
    clearUnknown: () => setUnknownCode(null),
    checkout,
    scan,
    setQty,
    setLineDiscount,
    removeItem,
    setHeaderDiscount,
    doCheckout,
  };
}
