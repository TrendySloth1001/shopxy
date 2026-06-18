"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { wsBase } from "@/features/scan-console/api";
import { posApi } from "./api";
import { type CheckoutResult, type ConnStatus, type SaleSnapshot, type TenderMode } from "./types";

/** Opaque op-id. `crypto.randomUUID` only exists in secure contexts (HTTPS or
 * localhost); a till reached by bare LAN IP over http would otherwise throw and
 * silently lose the scan — so fall back. (review M4) */
function opId(): string {
  try {
    if (typeof crypto !== "undefined" && crypto.randomUUID) return crypto.randomUUID();
  } catch {
    /* not a secure context */
  }
  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

/**
 * Drives one POS sale: opens (or resumes) a sale, mirrors the server-authoritative
 * cart, and keeps it live across devices over the scan-console WebSocket. Every
 * action calls the REST endpoint (which returns the fresh snapshot); the socket
 * sends a version nudge for changes made on the OTHER till and we re-fetch the
 * shop-gated snapshot. The server is the source of truth.
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
  const connectRef = useRef<() => void>(() => {});
  const openStartedRef = useRef(false);
  const flushingRef = useRef(false);
  // Highest sale.version applied — drops stale out-of-order responses.
  const versionRef = useRef(-1);
  const outboxRef = useRef<Array<{ opId: string; code: string }>>([]);
  const [pending, setPending] = useState(0);

  // Apply a snapshot only if it's at least as new as what we've shown — a
  // late/stale response (e.g. an outbox replay) can't clobber a newer cart.
  const applySnapshot = useCallback((s: SaleSnapshot) => {
    if (s.sale.version < versionRef.current) return;
    versionRef.current = s.sale.version;
    setSnapshot(s);
  }, []);

  const refreshSnapshot = useCallback(async () => {
    const saleId = saleIdRef.current;
    if (saleId == null) return;
    try {
      applySnapshot(await posApi.get(saleId));
    } catch {
      /* transient; the next event/action re-syncs */
    }
  }, [applySnapshot]);

  const flushOutbox = useCallback(async () => {
    const saleId = saleIdRef.current;
    if (saleId == null || flushingRef.current) return;
    flushingRef.current = true;
    try {
      const queue = outboxRef.current;
      while (queue.length > 0) {
        const next = queue[0];
        try {
          const r = await posApi.scan(saleId, next.code, next.opId);
          if (!("unknown" in r)) applySnapshot(r);
          queue.shift();
          setPending(queue.length);
        } catch {
          break; // still offline; retry on next reconnect
        }
      }
    } finally {
      flushingRef.current = false;
    }
  }, [applySnapshot]);

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
      const ticket = await posApi.ticket();
      if (closedRef.current) return;
      const ws = new WebSocket(`${wsBase()}${ticket.path}?ticket=${ticket.ticket}&role=console`);
      wsRef.current = ws;
      ws.onopen = () => {
        setStatus("live");
        // Self-heal on (re)connect: re-fetch the snapshot, then replay queued scans.
        void refreshSnapshot();
        void flushOutbox();
      };
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
        // All POS events are version nudges — re-fetch the authoritative snapshot
        // (events deliberately carry no cart contents). review M3.
        if (m.type === "pos.sale" || m.type === "pos.checkout" || m.type === "pos.void") {
          void refreshSnapshot();
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
  }, [scheduleReconnect, flushOutbox, refreshSnapshot]);

  useEffect(() => {
    connectRef.current = () => void connectWs();
  }, [connectWs]);

  // Open a sale then connect the live channel. Guarded so a fast remount /
  // StrictMode double-invoke doesn't fire two opens (review H4).
  useEffect(() => {
    closedRef.current = false;
    if (!openStartedRef.current) {
      openStartedRef.current = true;
      void (async () => {
        try {
          const s = await posApi.open();
          saleIdRef.current = s.sale.id;
          applySnapshot(s);
          void connectWs();
        } catch (e) {
          setError(e instanceof Error ? e.message : "Could not open a sale.");
          setStatus("offline");
        }
      })();
    }
    return () => {
      closedRef.current = true;
      if (timerRef.current) clearTimeout(timerRef.current);
      wsRef.current?.close();
    };
  }, [connectWs, applySnapshot]);

  const run = useCallback(
    async (fn: (saleId: number) => Promise<SaleSnapshot>) => {
      const saleId = saleIdRef.current;
      if (saleId == null) return;
      setError(null);
      try {
        applySnapshot(await fn(saleId));
      } catch (e) {
        setError(e instanceof Error ? e.message : "Action failed.");
      }
    },
    [applySnapshot],
  );

  const scan = useCallback(
    async (code: string) => {
      const saleId = saleIdRef.current;
      const c = code.trim();
      if (saleId == null || !c) return;
      setError(null);
      const id = opId();
      try {
        const r = await posApi.scan(saleId, c, id);
        if ("unknown" in r) setUnknownCode(r.code);
        else applySnapshot(r);
      } catch {
        outboxRef.current.push({ opId: id, code: c });
        setPending(outboxRef.current.length);
        setError("Offline — scan queued, will sync on reconnect.");
      }
    },
    [applySnapshot],
  );

  const setQty = useCallback((productId: number, quantity: number) => run((id) => posApi.patchItem(id, productId, { quantity })), [run]);
  const setLineDiscount = useCallback((productId: number, lineDiscount: number) => run((id) => posApi.patchItem(id, productId, { lineDiscount })), [run]);
  const removeItem = useCallback((productId: number) => run((id) => posApi.removeItem(id, productId)), [run]);
  const setHeaderDiscount = useCallback((d: number) => run((id) => posApi.setHeaderDiscount(id, d)), [run]);

  const quickAdd = useCallback(
    async (input: { code: string; name: string; sellingPrice: number; taxPercent?: number; openingStock?: number }) => {
      const saleId = saleIdRef.current;
      if (saleId == null) return;
      setError(null);
      try {
        applySnapshot(await posApi.quickAdd(saleId, input));
        setUnknownCode(null);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Quick add failed.");
      }
    },
    [applySnapshot],
  );

  const doCheckout = useCallback(async (mode: TenderMode, modeReference?: string) => {
    const saleId = saleIdRef.current;
    if (saleId == null) return;
    setError(null);
    try {
      setCheckout(await posApi.checkout(saleId, { mode, modeReference }));
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
    quickAdd,
    doCheckout,
    pending,
  };
}
