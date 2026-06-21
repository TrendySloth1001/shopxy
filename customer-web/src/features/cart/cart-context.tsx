"use client";

/**
 * CartProvider + useCart()
 *
 * Dual-mode cart:
 *   - Guest (not authed): lines live in localStorage as GuestLine[], keyed by
 *     GUEST_CART_KEY. Prices come from the product snapshot stored at add-time.
 *   - Authed: lines come from the server via GET /api/me/cart. Mutations hit
 *     PUT/DELETE /api/me/cart/* with optimistic local updates.
 *   - On login: the guest cart (if any) is merged into the server cart via
 *     POST /api/me/cart/merge, then the local store is cleared.
 *
 * Hydration safety: all localStorage access is gated on a `mounted` flag so
 * there's never a server/client HTML mismatch during SSR.
 *
 * The context exposes:
 *   lines         CartItem[]    — server lines when authed; synthesised CartItem[]
 *                                 from GuestLine[] when guest.
 *   count         number        — total item quantity across all lines.
 *   subtotal      number        — sum of sellingPrice × qty.
 *   savings       number        — sum of (mrp − sellingPrice) × qty, clamped ≥ 0.
 *   loading       boolean       — true while the first server fetch is in flight.
 *   add(product, qty)           — add/increment a product (guest or server).
 *   setQty(productId, qty)      — set exact qty; 0 removes the line.
 *   remove(productId)           — remove a line.
 *   clear()                     — remove all lines.
 */

import {
  createContext,
  startTransition,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
  type ReactNode,
} from "react";
import { useAuth } from "@/features/auth/auth-context";
import {
  fetchCart,
  setCartQty,
  removeCartLine,
  clearServerCart,
  mergeGuestCart,
} from "./api";
import {
  GUEST_CART_KEY,
  MAX_LINE_QTY,
  type CartItem,
  type CartProduct,
  type GuestLine,
} from "./types";

// ── Context shape ─────────────────────────────────────────────────────────────

export type CartContextValue = {
  lines: CartItem[];
  count: number;
  subtotal: number;
  savings: number;
  loading: boolean;
  /**
   * True when the cart is a guest (localStorage) cart, whose prices/MRP are a
   * snapshot taken at add-time rather than a live server figure. The UI must
   * label these as "price when added" — they're re-fetched/validated only once
   * the guest signs in and the cart is server-merged, and the backend blocks a
   * stale price at place-order with PRICE_DRIFT. (CP E-Commerce Rules r.5;
   * Legal Metrology — displayed MRP must be current.)
   */
  priceProvisional: boolean;
  /**
   * Add `qty` units of `product` to the cart. If the line already exists the
   * quantities are summed (capped at MAX_LINE_QTY and available stock).
   */
  add: (product: CartProduct, qty?: number) => Promise<void>;
  /** Set the exact quantity for a line. qty=0 removes the line. */
  setQty: (productId: number, qty: number) => Promise<void>;
  /** Remove a line entirely. */
  remove: (productId: number) => Promise<void>;
  /** Clear all lines. */
  clear: () => Promise<void>;
};

const CartContext = createContext<CartContextValue | null>(null);

// ── localStorage helpers ──────────────────────────────────────────────────────

function readGuestCart(): GuestLine[] {
  try {
    const raw = localStorage.getItem(GUEST_CART_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as GuestLine[];
  } catch {
    return [];
  }
}

function writeGuestCart(lines: GuestLine[]): void {
  try {
    if (lines.length === 0) {
      localStorage.removeItem(GUEST_CART_KEY);
    } else {
      localStorage.setItem(GUEST_CART_KEY, JSON.stringify(lines));
    }
  } catch {
    /* quota exceeded — swallow */
  }
}

// ── Guest ↔ CartItem bridge ───────────────────────────────────────────────────

/** Synthesise a CartItem from a GuestLine so the rest of the UI is uniform. */
function guestToCartItem(g: GuestLine, idx: number): CartItem {
  return {
    id: -(idx + 1), // synthetic negative id — never sent to the server
    productId: g.productId,
    quantity: g.quantity,
    updatedAt: new Date().toISOString(),
    product: {
      id: g.productId,
      name: g.snapshot.name,
      sku: null,
      unit: g.snapshot.unit ?? null,
      mrp: g.snapshot.mrp,
      sellingPrice: g.snapshot.sellingPrice,
      taxPercent: 0,
      stockQuantity: g.snapshot.stockQuantity,
      isActive: true,
      isPublished: true,
      categoryId: null,
      category: null,
      images: g.snapshot.imageUrl
        ? [{ url: g.snapshot.imageUrl, sortOrder: 0 }]
        : [],
      shop: {
        id: 0,
        name: g.snapshot.shopName,
        slug: g.snapshot.shopSlug,
      },
    },
  };
}

// ── Derived totals ────────────────────────────────────────────────────────────

function deriveCart(lines: CartItem[]): {
  count: number;
  subtotal: number;
  savings: number;
} {
  let count = 0;
  let subtotal = 0;
  let mrpTotal = 0;
  for (const line of lines) {
    count += line.quantity;
    subtotal += line.product.sellingPrice * line.quantity;
    mrpTotal += line.product.mrp * line.quantity;
  }
  return { count, subtotal, savings: Math.max(0, mrpTotal - subtotal) };
}

// ── Provider ──────────────────────────────────────────────────────────────────

export function CartProvider({ children }: { children: ReactNode }) {
  const { status, user } = useAuth();

  // Gate all localStorage access on this flag to avoid SSR/client mismatch.
  // useSyncExternalStore is the React-canonical hydration-safe mounting pattern:
  // the server snapshot returns false; the client snapshot returns true after
  // the first commit without any setState-in-effect.
  const mounted = useSyncExternalStore(
    () => () => {},      // no subscription needed — value never changes
    () => true,          // client snapshot: always true after hydration
    () => false,         // server snapshot: false so SSR emits empty cart
  );
  const [lines, setLines] = useState<CartItem[]>([]);
  const [loading, setLoading] = useState(false);

  // Track whether we've already merged the guest cart into the server for this
  // sign-in session so we don't do it twice on fast re-renders.
  const mergedRef = useRef(false);
  // Track the last auth status so we can detect the guest→authed transition.
  const prevStatusRef = useRef<"loading" | "authed" | "guest">("loading");

  // ── Guest cart hydration ──────────────────────────────────────────────────

  useEffect(() => {
    if (!mounted) return;
    if (status === "guest") {
      const guestLines = readGuestCart();
      mergedRef.current = false;
      startTransition(() => {
        setLines(guestLines.map(guestToCartItem));
      });
    }
  }, [mounted, status]);

  // ── Server cart fetch + merge on sign-in ─────────────────────────────────

  useEffect(() => {
    if (!mounted) return;
    if (status !== "authed") return;

    const justSignedIn = prevStatusRef.current !== "authed";
    prevStatusRef.current = status;

    async function loadAndMerge() {
      setLoading(true);
      try {
        // If the user just signed in, merge the guest cart first.
        if (justSignedIn && !mergedRef.current) {
          mergedRef.current = true;
          const guestLines = readGuestCart();
          if (guestLines.length > 0) {
            const merged = await mergeGuestCart(
              guestLines.map((g) => ({
                productId: g.productId,
                quantity: g.quantity,
              })),
            );
            writeGuestCart([]);
            setLines(merged);
            return;
          }
        }
        const serverLines = await fetchCart();
        setLines(serverLines);
      } catch {
        // Keep whatever was there on a transient error.
      } finally {
        setLoading(false);
      }
    }

    void loadAndMerge();
  }, [mounted, status]);

  // Track status transitions.
  useEffect(() => {
    if (status !== "loading") {
      prevStatusRef.current = status;
    }
  }, [status]);

  // ── Mutations ─────────────────────────────────────────────────────────────

  const add = useCallback(
    async (product: CartProduct, qty = 1): Promise<void> => {
      if (status === "authed") {
        // Find existing line and optimistically add.
        const existing = lines.find((l) => l.productId === product.id);
        const newQty = Math.min(
          MAX_LINE_QTY,
          (existing?.quantity ?? 0) + qty,
          product.stockQuantity > 0 ? product.stockQuantity : MAX_LINE_QTY,
        );

        // Optimistic update.
        if (existing) {
          setLines((prev) =>
            prev.map((l) =>
              l.productId === product.id ? { ...l, quantity: newQty } : l,
            ),
          );
        } else {
          const optimisticLine: CartItem = {
            id: -Date.now(),
            productId: product.id,
            quantity: newQty,
            updatedAt: new Date().toISOString(),
            product,
          };
          setLines((prev) => [...prev, optimisticLine]);
        }

        try {
          const result = await setCartQty(product.id, newQty);
          if (result === null) {
            // Server removed the line (qty ≤ 0).
            setLines((prev) => prev.filter((l) => l.productId !== product.id));
          } else {
            setLines((prev) =>
              prev.map((l) =>
                l.productId === product.id ? { ...l, quantity: result.quantity } : l,
              ),
            );
          }
        } catch {
          // Rollback optimistic update on failure.
          setLines((prev) =>
            existing
              ? prev.map((l) =>
                  l.productId === product.id ? { ...l, quantity: existing.quantity } : l,
                )
              : prev.filter((l) => l.productId !== product.id),
          );
        }
      } else {
        // Guest cart — localStorage.
        if (!mounted) return;
        const guestLines = readGuestCart();
        const existingIdx = guestLines.findIndex((g) => g.productId === product.id);
        const cap = product.stockQuantity > 0 ? product.stockQuantity : MAX_LINE_QTY;
        if (existingIdx >= 0) {
          guestLines[existingIdx].quantity = Math.min(
            MAX_LINE_QTY,
            cap,
            guestLines[existingIdx].quantity + qty,
          );
        } else {
          guestLines.push({
            productId: product.id,
            quantity: Math.min(MAX_LINE_QTY, cap, qty),
            snapshot: {
              name: product.name,
              imageUrl: product.images[0]?.url ?? "",
              sellingPrice: product.sellingPrice,
              mrp: product.mrp,
              shopName: product.shop.name,
              shopSlug: product.shop.slug,
              unit: product.unit,
              stockQuantity: product.stockQuantity,
            },
          });
        }
        writeGuestCart(guestLines);
        setLines(guestLines.map(guestToCartItem));
      }
    },
    [status, lines, mounted],
  );

  const setQty = useCallback(
    async (productId: number, qty: number): Promise<void> => {
      if (status === "authed") {
        const prev = lines.find((l) => l.productId === productId);
        if (!prev && qty > 0) return; // line doesn't exist

        // Optimistic.
        if (qty <= 0) {
          setLines((ls) => ls.filter((l) => l.productId !== productId));
        } else {
          setLines((ls) =>
            ls.map((l) => (l.productId === productId ? { ...l, quantity: qty } : l)),
          );
        }

        try {
          const result = await setCartQty(productId, qty);
          if (result === null) {
            setLines((ls) => ls.filter((l) => l.productId !== productId));
          } else {
            setLines((ls) =>
              ls.map((l) =>
                l.productId === productId ? { ...l, quantity: result.quantity } : l,
              ),
            );
          }
        } catch {
          // Rollback.
          if (prev) {
            setLines((ls) =>
              ls.some((l) => l.productId === productId)
                ? ls.map((l) => (l.productId === productId ? prev : l))
                : [...ls, prev],
            );
          }
        }
      } else {
        if (!mounted) return;
        const guestLines = readGuestCart();
        if (qty <= 0) {
          const updated = guestLines.filter((g) => g.productId !== productId);
          writeGuestCart(updated);
          setLines(updated.map(guestToCartItem));
        } else {
          const idx = guestLines.findIndex((g) => g.productId === productId);
          if (idx >= 0) {
            guestLines[idx].quantity = Math.min(MAX_LINE_QTY, qty);
            writeGuestCart(guestLines);
            setLines(guestLines.map(guestToCartItem));
          }
        }
      }
    },
    [status, lines, mounted],
  );

  const remove = useCallback(
    async (productId: number): Promise<void> => {
      if (status === "authed") {
        const prev = lines.find((l) => l.productId === productId);
        setLines((ls) => ls.filter((l) => l.productId !== productId));
        try {
          await removeCartLine(productId);
        } catch {
          if (prev) setLines((ls) => [...ls, prev]);
        }
      } else {
        if (!mounted) return;
        const updated = readGuestCart().filter((g) => g.productId !== productId);
        writeGuestCart(updated);
        setLines(updated.map(guestToCartItem));
      }
    },
    [status, lines, mounted],
  );

  const clear = useCallback(async (): Promise<void> => {
    if (status === "authed") {
      const prev = lines;
      setLines([]);
      try {
        await clearServerCart();
      } catch {
        setLines(prev);
      }
    } else {
      if (!mounted) return;
      writeGuestCart([]);
      setLines([]);
    }
  }, [status, lines, mounted]);

  // ── Derived values ────────────────────────────────────────────────────────

  const { count, subtotal, savings } = useMemo(() => deriveCart(lines), [lines]);

  // Guest carts render snapshot prices; everything else is server-authoritative.
  const priceProvisional = status === "guest";

  const value = useMemo<CartContextValue>(
    () => ({ lines, count, subtotal, savings, loading, priceProvisional, add, setQty, remove, clear }),
    [lines, count, subtotal, savings, loading, priceProvisional, add, setQty, remove, clear],
  );

  // Suppress rendering guest-cart content during SSR to avoid hydration mismatch.
  // The conditional lives inside the memo so the dependency array is stable.
  const safeValue = useMemo<CartContextValue>(
    () => ({ ...value, lines: mounted ? value.lines : [] }),
    [mounted, value],
  );

  // Avoid unused variable warning for `user` (it's read by auth-context below
  // but not needed here directly — suppressed via void).
  void user;

  return <CartContext.Provider value={safeValue}>{children}</CartContext.Provider>;
}

export function useCart(): CartContextValue {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error("useCart must be used within <CartProvider>");
  return ctx;
}
