"use client";

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

export type CartContextValue = {
  lines: CartItem[];
  count: number;
  subtotal: number;
  savings: number;
  loading: boolean;
  mutating: boolean;
  priceProvisional: boolean;
  add: (product: CartProduct, qty?: number) => Promise<void>;
  setQty: (productId: string, qty: number) => Promise<void>;
  remove: (productId: string) => Promise<void>;
  clear: () => Promise<void>;
};

const CartContext = createContext<CartContextValue | null>(null);

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
  }
}

function guestToCartItem(g: GuestLine, idx: number): CartItem {
  return {
    id: `guest-${idx + 1}`,
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
        id: "",
        name: g.snapshot.shopName,
        slug: g.snapshot.shopSlug,
      },
    },
  };
}

function deriveCart(lines: CartItem[]): {
  count: number;
  subtotal: number;
  savings: number;
} {
  let count = 0;
  let subtotal = 0;
  let savings = 0;
  for (const line of lines) {
    const { mrp, sellingPrice } = line.product;
    count += line.quantity;
    subtotal += sellingPrice * line.quantity;
    if (mrp > sellingPrice) {
      savings += (mrp - sellingPrice) * line.quantity;
    }
  }
  return { count, subtotal, savings };
}

export function CartProvider({ children }: { children: ReactNode }) {
  const { status, user } = useAuth();

  const mounted = useSyncExternalStore(
    () => () => {},
    () => true,
    () => false,
  );
  const [lines, setLines] = useState<CartItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [pendingMutations, setPendingMutations] = useState(0);

  const mergedRef = useRef(false);
  const prevStatusRef = useRef<"loading" | "authed" | "guest">("loading");

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

  useEffect(() => {
    if (!mounted) return;
    if (status !== "authed") return;

    const justSignedIn = prevStatusRef.current !== "authed";
    prevStatusRef.current = status;

    async function loadAndMerge() {
      setLoading(true);
      try {
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
      } finally {
        setLoading(false);
      }
    }

    void loadAndMerge();
  }, [mounted, status]);

  useEffect(() => {
    if (status !== "loading") {
      prevStatusRef.current = status;
    }
  }, [status]);

  const add = useCallback(
    async (product: CartProduct, qty = 1): Promise<void> => {
      if (status === "authed") {
        const existing = lines.find((l) => l.productId === product.id);
        const newQty = Math.min(
          MAX_LINE_QTY,
          (existing?.quantity ?? 0) + qty,
          product.stockQuantity > 0 ? product.stockQuantity : MAX_LINE_QTY,
        );

        if (existing) {
          setLines((prev) =>
            prev.map((l) =>
              l.productId === product.id ? { ...l, quantity: newQty } : l,
            ),
          );
        } else {
          const optimisticLine: CartItem = {
            id: `temp-${Date.now()}`,
            productId: product.id,
            quantity: newQty,
            updatedAt: new Date().toISOString(),
            product,
          };
          setLines((prev) => [...prev, optimisticLine]);
        }

        setPendingMutations((n) => n + 1);
        try {
          const result = await setCartQty(product.id, newQty);
          if (result === null) {
            setLines((prev) => prev.filter((l) => l.productId !== product.id));
          } else {
            setLines((prev) =>
              prev.map((l) =>
                l.productId === product.id ? { ...l, quantity: result.quantity } : l,
              ),
            );
          }
        } catch {
          setLines((prev) =>
            existing
              ? prev.map((l) =>
                  l.productId === product.id ? { ...l, quantity: existing.quantity } : l,
                )
              : prev.filter((l) => l.productId !== product.id),
          );
        } finally {
          setPendingMutations((n) => n - 1);
        }
      } else {
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
    async (productId: string, qty: number): Promise<void> => {
      if (status === "authed") {
        const prev = lines.find((l) => l.productId === productId);
        if (!prev && qty > 0) return;

        if (qty <= 0) {
          setLines((ls) => ls.filter((l) => l.productId !== productId));
        } else {
          setLines((ls) =>
            ls.map((l) => (l.productId === productId ? { ...l, quantity: qty } : l)),
          );
        }

        setPendingMutations((n) => n + 1);
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
          if (prev) {
            setLines((ls) =>
              ls.some((l) => l.productId === productId)
                ? ls.map((l) => (l.productId === productId ? prev : l))
                : [...ls, prev],
            );
          }
        } finally {
          setPendingMutations((n) => n - 1);
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
    async (productId: string): Promise<void> => {
      if (status === "authed") {
        const prev = lines.find((l) => l.productId === productId);
        setLines((ls) => ls.filter((l) => l.productId !== productId));
        setPendingMutations((n) => n + 1);
        try {
          await removeCartLine(productId);
        } catch {
          if (prev) setLines((ls) => [...ls, prev]);
        } finally {
          setPendingMutations((n) => n - 1);
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
      setPendingMutations((n) => n + 1);
      try {
        await clearServerCart();
      } catch {
        setLines(prev);
      } finally {
        setPendingMutations((n) => n - 1);
      }
    } else {
      if (!mounted) return;
      writeGuestCart([]);
      setLines([]);
    }
  }, [status, lines, mounted]);

  const { count, subtotal, savings } = useMemo(() => deriveCart(lines), [lines]);

  const priceProvisional = status === "guest";
  const mutating = pendingMutations > 0;

  const value = useMemo<CartContextValue>(
    () => ({ lines, count, subtotal, savings, loading, mutating, priceProvisional, add, setQty, remove, clear }),
    [lines, count, subtotal, savings, loading, mutating, priceProvisional, add, setQty, remove, clear],
  );

  const safeValue = useMemo<CartContextValue>(
    () => ({ ...value, lines: mounted ? value.lines : [] }),
    [mounted, value],
  );

  void user;

  return <CartContext.Provider value={safeValue}>{children}</CartContext.Provider>;
}

export function useCart(): CartContextValue {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error("useCart must be used within <CartProvider>");
  return ctx;
}
