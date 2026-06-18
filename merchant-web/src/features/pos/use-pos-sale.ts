"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { wsBase } from "@/features/scan-console/api";
import { requestPosTicket } from "./api";
import {
  saleSnapshotSchema,
  unknownScanSchema,
  checkoutResultSchema,
  type CheckoutResult,
  type ConnStatus,
  type SaleSnapshot,
  type TenderMode,
} from "./types";

/** Opaque op-id; falls back when crypto.randomUUID is unavailable (non-secure LAN). */
function opId(): string {
  try {
    if (typeof crypto !== "undefined" && crypto.randomUUID) return crypto.randomUUID();
  } catch {
    /* not a secure context */
  }
  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

type CmdResult = { ok: true; data: unknown } | { ok: false; error: string; detail?: unknown };
type Pending = { resolve: (r: CmdResult) => void; timer: ReturnType<typeof setTimeout> };

const CMD_TIMEOUT_MS = 12_000;

/**
 * Drives one POS sale ENTIRELY over the WebSocket: every op is a `{t:'cmd',
 * reqId, op, …}` frame answered with `{t:'res', reqId, ok, data|error}`; the
 * other till's changes arrive as version-nudge events and we re-fetch via a
 * `snapshot` command. Server is the source of truth.
 */
export function usePosSale() {
  const [snapshot, setSnapshot] = useState<SaleSnapshot | null>(null);
  const [status, setStatus] = useState<ConnStatus>("connecting");
  const [error, setError] = useState<string | null>(null);
  const [unknownCode, setUnknownCode] = useState<string | null>(null);
  const [checkout, setCheckout] = useState<CheckoutResult | null>(null);
  const [pending, setPending] = useState(0);

  const wsRef = useRef<WebSocket | null>(null);
  const closedRef = useRef(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const connectRef = useRef<() => void>(() => {});
  const startedRef = useRef(false);
  const saleIdRef = useRef<number | null>(null);
  const versionRef = useRef(-1);
  const pendingCmds = useRef<Map<string, Pending>>(new Map());
  // Scans that failed while disconnected — replayed on reconnect (opId-deduped).
  const outboxRef = useRef<Array<{ code: string; id: string }>>([]);
  const flushingRef = useRef(false);

  // ── command send / response correlation ──
  const sendCmd = useCallback((op: string, args: Record<string, unknown> = {}): Promise<CmdResult> => {
    return new Promise((resolve) => {
      const ws = wsRef.current;
      const reqId = opId();
      if (!ws || ws.readyState !== WebSocket.OPEN) {
        resolve({ ok: false, error: "offline" });
        return;
      }
      const timer = setTimeout(() => {
        pendingCmds.current.delete(reqId);
        resolve({ ok: false, error: "timeout" });
      }, CMD_TIMEOUT_MS);
      pendingCmds.current.set(reqId, { resolve, timer });
      ws.send(JSON.stringify({ t: "cmd", reqId, op, ...args }));
    });
  }, []);

  const applySnapshot = useCallback((raw: unknown) => {
    const parsed = saleSnapshotSchema.safeParse(raw);
    if (!parsed.success) return;
    if (parsed.data.sale.version < versionRef.current) return; // drop stale
    versionRef.current = parsed.data.sale.version;
    saleIdRef.current = parsed.data.sale.id;
    setSnapshot(parsed.data);
  }, []);

  const refresh = useCallback(async () => {
    const saleId = saleIdRef.current;
    if (saleId == null) return;
    const r = await sendCmd("snapshot", { saleId });
    if (r.ok) applySnapshot(r.data);
  }, [sendCmd, applySnapshot]);

  const flushOutbox = useCallback(async () => {
    const saleId = saleIdRef.current;
    if (saleId == null || flushingRef.current) return;
    flushingRef.current = true;
    try {
      const q = outboxRef.current;
      while (q.length > 0) {
        const next = q[0];
        const r = await sendCmd("scan", { saleId, code: next.code, opId: next.id });
        if (!r.ok) break; // still offline; retry next reconnect
        if (!unknownScanSchema.safeParse(r.data).success) applySnapshot(r.data);
        q.shift();
        setPending(q.length);
      }
    } finally {
      flushingRef.current = false;
    }
  }, [sendCmd, applySnapshot]);

  const scheduleReconnect = useCallback((delay: number) => {
    if (closedRef.current || timerRef.current) return;
    timerRef.current = setTimeout(() => {
      timerRef.current = null;
      connectRef.current();
    }, delay);
  }, []);

  const connect = useCallback(async () => {
    if (closedRef.current) return;
    try {
      const ticket = await requestPosTicket();
      if (closedRef.current) return;
      const ws = new WebSocket(`${wsBase()}${ticket.path}?ticket=${ticket.ticket}&role=console`);
      wsRef.current = ws;

      ws.onopen = async () => {
        setStatus("live");
        // First connect → open (reuses an empty sale); reconnect → resume the same sale.
        const r = saleIdRef.current == null
          ? await sendCmd("open")
          : await sendCmd("snapshot", { saleId: saleIdRef.current });
        if (r.ok) applySnapshot(r.data);
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
        const m = msg as { t?: string; reqId?: string; type?: string; saleId?: number };
        if (m.t === "res" && typeof m.reqId === "string") {
          const p = pendingCmds.current.get(m.reqId);
          if (p) {
            clearTimeout(p.timer);
            pendingCmds.current.delete(m.reqId);
            p.resolve(m as unknown as CmdResult);
          }
          return;
        }
        // Version-nudge events for our sale → re-fetch.
        if ((m.type === "pos.sale" || m.type === "pos.checkout" || m.type === "pos.void") && m.saleId === saleIdRef.current) {
          void refresh();
        }
      };

      ws.onerror = () => ws.close();
      ws.onclose = () => {
        if (closedRef.current) return;
        wsRef.current = null;
        // Fail any in-flight commands so callers don't hang.
        for (const [id, p] of pendingCmds.current) {
          clearTimeout(p.timer);
          p.resolve({ ok: false, error: "disconnected" });
          pendingCmds.current.delete(id);
        }
        setStatus("reconnecting");
        scheduleReconnect(1500);
      };
    } catch {
      if (closedRef.current) return;
      setStatus("offline");
      scheduleReconnect(2000);
    }
  }, [sendCmd, applySnapshot, flushOutbox, refresh, scheduleReconnect]);

  useEffect(() => {
    connectRef.current = () => void connect();
  }, [connect]);

  useEffect(() => {
    closedRef.current = false;
    if (!startedRef.current) {
      startedRef.current = true;
      void connect();
    }
    return () => {
      closedRef.current = true;
      if (timerRef.current) clearTimeout(timerRef.current);
      wsRef.current?.close();
    };
  }, [connect]);

  // ── actions (all over WS) ──
  const runSnap = useCallback(
    async (op: string, args: Record<string, unknown>) => {
      const saleId = saleIdRef.current;
      if (saleId == null) return;
      setError(null);
      const r = await sendCmd(op, { saleId, ...args });
      if (r.ok) applySnapshot(r.data);
      else setError(r.error === "offline" || r.error === "timeout" || r.error === "disconnected" ? "Reconnecting…" : r.error);
    },
    [sendCmd, applySnapshot],
  );

  const scan = useCallback(
    async (code: string) => {
      const saleId = saleIdRef.current;
      const c = code.trim();
      if (saleId == null || !c) return;
      setError(null);
      const id = opId();
      const r = await sendCmd("scan", { saleId, code: c, opId: id });
      if (!r.ok) {
        outboxRef.current.push({ code: c, id });
        setPending(outboxRef.current.length);
        setError("Offline — scan queued, will sync on reconnect.");
        return;
      }
      if (unknownScanSchema.safeParse(r.data).success) {
        setUnknownCode(unknownScanSchema.parse(r.data).code);
      } else {
        applySnapshot(r.data);
      }
    },
    [sendCmd, applySnapshot],
  );

  const setQty = useCallback((productId: number, quantity: number) => runSnap("setQty", { productId, quantity }), [runSnap]);
  const setLineDiscount = useCallback((productId: number, discount: number) => runSnap("setLineDiscount", { productId, discount }), [runSnap]);
  const removeItem = useCallback((productId: number) => runSnap("removeLine", { productId }), [runSnap]);
  const setHeaderDiscount = useCallback((discount: number) => runSnap("setHeaderDiscount", { discount }), [runSnap]);

  const quickAdd = useCallback(
    async (input: { code: string; name: string; sellingPrice: number; taxPercent?: number; openingStock?: number }) => {
      const saleId = saleIdRef.current;
      if (saleId == null) return;
      setError(null);
      const r = await sendCmd("quickAdd", { saleId, ...input });
      if (r.ok) {
        applySnapshot(r.data);
        setUnknownCode(null);
      } else {
        setError(r.error);
      }
    },
    [sendCmd, applySnapshot],
  );

  const doCheckout = useCallback(
    async (mode: TenderMode, modeReference?: string) => {
      const saleId = saleIdRef.current;
      if (saleId == null) return;
      setError(null);
      const r = await sendCmd("checkout", { saleId, tender: { mode, modeReference } });
      if (r.ok) {
        const parsed = checkoutResultSchema.safeParse(r.data);
        if (parsed.success) setCheckout(parsed.data);
      } else {
        setError(r.error === "offline" || r.error === "timeout" ? "Couldn't reach the till — please retry." : r.error);
      }
    },
    [sendCmd],
  );

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
