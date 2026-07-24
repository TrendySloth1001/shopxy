"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { wsBase } from "@/features/scan-console/api";
import { requestPosTicket } from "./api";
import { openRazorpayCheckout } from "@/shared/razorpay";
import {
  saleSnapshotSchema,
  unknownScanSchema,
  checkoutResultSchema,
  posPaySessionSchema,
  openSaleSummarySchema,
  productSearchResultSchema,
  type CheckoutResult,
  type ConnStatus,
  type OpenSaleSummary,
  type ProductSearchResult,
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
  const t = useTranslations("pos");
  const [snapshot, setSnapshot] = useState<SaleSnapshot | null>(null);
  const [status, setStatus] = useState<ConnStatus>("connecting");
  const [error, setError] = useState<string | null>(null);
  const [unknownCode, setUnknownCode] = useState<string | null>(null);
  const [checkout, setCheckout] = useState<CheckoutResult | null>(null);
  const [onlinePaid, setOnlinePaid] = useState<{ amount: number; invoiceId: string | null } | null>(null);
  const [paying, setPaying] = useState(false);
  const [pending, setPending] = useState(0);
  // Amount of an in-flight online payment (set while Razorpay Checkout is open).
  const onlineRef = useRef<number | null>(null);

  const wsRef = useRef<WebSocket | null>(null);
  const closedRef = useRef(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const connectRef = useRef<() => void>(() => {});
  const startedRef = useRef(false);
  const saleIdRef = useRef<string | null>(null);
  const versionRef = useRef(-1);
  const pendingCmds = useRef<Map<string, Pending>>(new Map());
  // Scans that failed while disconnected — replayed on reconnect (opId-deduped).
  const outboxRef = useRef<Array<{ code: string; id: string; quantity: number }>>([]);
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
        const r = await sendCmd("scan", { saleId, code: next.code, opId: next.id, quantity: next.quantity });
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
        // SaleBus events (pos.sale/checkout/void) travel over the WS raw — they
        // bypass the res.json opaque-id tokeniser — so saleId/invoiceId arrive as
        // NUMBERS, while saleIdRef holds the coerced string id. Type + compare
        // them as strings (mirrors the Flutter till's `.toString()`), otherwise
        // `42 === "42"` is false and the till never re-fetches on a peer's scan.
        const m = msg as { t?: string; reqId?: string; type?: string; saleId?: string | number; invoiceId?: string | number };
        if (m.t === "res" && typeof m.reqId === "string") {
          const p = pendingCmds.current.get(m.reqId);
          if (p) {
            clearTimeout(p.timer);
            pendingCmds.current.delete(m.reqId);
            p.resolve(m as unknown as CmdResult);
          }
          return;
        }
        const evSaleId = m.saleId != null ? String(m.saleId) : null;
        // An online payment settled (webhook → pos.checkout) → flip to paid.
        if (m.type === "pos.checkout" && evSaleId === saleIdRef.current && onlineRef.current != null) {
          setOnlinePaid({ amount: onlineRef.current, invoiceId: m.invoiceId != null ? String(m.invoiceId) : null });
          onlineRef.current = null;
        }
        // Version-nudge events for our sale → re-fetch.
        if ((m.type === "pos.sale" || m.type === "pos.checkout" || m.type === "pos.void") && evSaleId === saleIdRef.current) {
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
      else setError(r.error === "offline" || r.error === "timeout" || r.error === "disconnected" ? t("errors.reconnecting") : r.error);
    },
    [sendCmd, applySnapshot, t],
  );

  const scan = useCallback(
    async (code: string, quantity = 1) => {
      const saleId = saleIdRef.current;
      const c = code.trim();
      const q = quantity > 0 ? quantity : 1;
      if (saleId == null || !c) return;
      setError(null);
      const id = opId();
      const r = await sendCmd("scan", { saleId, code: c, opId: id, quantity: q });
      if (!r.ok) {
        outboxRef.current.push({ code: c, id, quantity: q });
        setPending(outboxRef.current.length);
        setError(t("errors.offlineScanQueued"));
        return;
      }
      if (unknownScanSchema.safeParse(r.data).success) {
        setUnknownCode(unknownScanSchema.parse(r.data).code);
      } else {
        applySnapshot(r.data);
      }
    },
    [sendCmd, applySnapshot, t],
  );

  const addItem = useCallback((productId: string, quantity = 1) => runSnap("addItem", { productId, quantity }), [runSnap]);
  const searchProducts = useCallback(
    async (term: string): Promise<ProductSearchResult[]> => {
      const r = await sendCmd("search", { term });
      if (!r.ok) return [];
      const parsed = productSearchResultSchema.array().safeParse(r.data);
      return parsed.success ? parsed.data : [];
    },
    [sendCmd],
  );

  const setQty = useCallback((productId: string, quantity: number) => runSnap("setQty", { productId, quantity }), [runSnap]);
  const removeItem = useCallback((productId: string) => runSnap("removeLine", { productId }), [runSnap]);

  // Privileged actions (discounts) — return overrideRequired so the till can
  // prompt for a manager grant and retry with the `override` token.
  const runPrivileged = useCallback(
    async (op: string, args: Record<string, unknown>): Promise<{ ok: boolean; overrideRequired: boolean }> => {
      const saleId = saleIdRef.current;
      if (saleId == null) return { ok: false, overrideRequired: false };
      setError(null);
      const r = await sendCmd(op, { saleId, ...args });
      if (r.ok) {
        applySnapshot(r.data);
        return { ok: true, overrideRequired: false };
      }
      if ((r.detail as { code?: string } | undefined)?.code === "OVERRIDE_REQUIRED") {
        return { ok: false, overrideRequired: true };
      }
      setError(r.error === "offline" || r.error === "timeout" || r.error === "disconnected" ? t("errors.reconnecting") : r.error);
      return { ok: false, overrideRequired: false };
    },
    [sendCmd, applySnapshot, t],
  );
  const setLineDiscount = useCallback((productId: string, discount: number, override?: string) => runPrivileged("setLineDiscount", { productId, discount, override }), [runPrivileged]);
  const setHeaderDiscount = useCallback((discount: number, override?: string) => runPrivileged("setHeaderDiscount", { discount, override }), [runPrivileged]);

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
    async (mode: TenderMode, modeReference?: string, customer?: { name?: string; phone?: string }) => {
      const saleId = saleIdRef.current;
      if (saleId == null) return;
      setError(null);
      const r = await sendCmd("checkout", { saleId, tender: { mode, modeReference }, customer });
      if (r.ok) {
        const parsed = checkoutResultSchema.safeParse(r.data);
        if (parsed.success) setCheckout(parsed.data);
      } else {
        setError(r.error === "offline" || r.error === "timeout" ? t("errors.couldNotReachTill") : r.error);
      }
    },
    [sendCmd, t],
  );

  // Online tender: create an order, open Razorpay Checkout (UPI QR + cards), then
  // settle. The pos.checkout bus event flips the till to paid; syncOnline is the
  // backstop when the webhook can't reach the server (localhost / delayed).
  const payOnline = useCallback(async () => {
    const saleId = saleIdRef.current;
    if (saleId == null) return;
    setError(null);
    const r = await sendCmd("payOnline", { saleId });
    if (!r.ok) {
      setError(r.error === "offline" || r.error === "timeout" ? t("errors.couldNotReachTill") : r.error);
      return;
    }
    const parsed = posPaySessionSchema.safeParse(r.data);
    if (!parsed.success) {
      setError(t("errors.couldNotStartOnline"));
      return;
    }
    onlineRef.current = parsed.data.amount;
    void refresh(); // sale is now AWAITING_PAYMENT
    setPaying(true);
    try {
      const result = await openRazorpayCheckout(parsed.data);
      if (result.outcome === "success") {
        // Settle (webhook backstop). The pos.checkout event flips onlinePaid.
        await sendCmd("syncOnline", { saleId });
        void refresh();
      } else {
        // Dismissed or failed → unlock the cart for another attempt/tender.
        onlineRef.current = null;
        await sendCmd("cancelOnline", { saleId });
        void refresh();
        if (result.outcome === "failed") setError(result.message ?? t("errors.paymentFailed"));
      }
    } catch {
      onlineRef.current = null;
      await sendCmd("cancelOnline", { saleId });
      void refresh();
      setError(t("errors.couldNotOpenRazorpay"));
    } finally {
      setPaying(false);
    }
  }, [sendCmd, refresh, t]);

  // Hold the current bill (park it) and start a fresh empty cart. The parked
  // sale stays OPEN and is recallable from `listOpen`.
  const holdAndNew = useCallback(async () => {
    setError(null);
    versionRef.current = -1; // switching sales — accept the new (lower-version) snapshot
    const r = await sendCmd("open");
    if (r.ok) applySnapshot(r.data);
  }, [sendCmd, applySnapshot]);

  // Recall a parked bill by id (make it the active cart).
  const recall = useCallback(
    async (saleId: string) => {
      setError(null);
      versionRef.current = -1;
      const r = await sendCmd("snapshot", { saleId });
      if (r.ok) applySnapshot(r.data);
    },
    [sendCmd, applySnapshot],
  );

  // The parked (held) bills with items.
  const listOpen = useCallback(async (): Promise<OpenSaleSummary[]> => {
    const r = await sendCmd("listOpen");
    if (!r.ok) return [];
    const parsed = openSaleSummarySchema.array().safeParse(r.data);
    return parsed.success ? parsed.data : [];
  }, [sendCmd]);

  return {
    snapshot,
    status,
    error,
    unknownCode,
    clearUnknown: () => setUnknownCode(null),
    checkout,
    onlinePaid,
    paying,
    payOnline,
    scan,
    addItem,
    searchProducts,
    setQty,
    setLineDiscount,
    removeItem,
    setHeaderDiscount,
    quickAdd,
    doCheckout,
    holdAndNew,
    recall,
    listOpen,
    pending,
  };
}
