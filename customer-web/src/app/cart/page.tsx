"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { Minus, Plus, ShoppingCart, Trash2, ShieldCheck } from "lucide-react";
import { useCart } from "@/features/cart/cart-context";
import { useAuth } from "@/features/auth/auth-context";
import { AppHeader } from "@/features/auth/components/app-header";
import { BackButton } from "@/shared/ui/back-button";
import { formatINR } from "@/shared/format";
import { useState } from "react";
import { mediaSrc } from "@/shared/media";

// ── Undo toast (simple transient overlay) ─────────────────────────────────────

interface UndoToast {
  message: string;
  onUndo: () => void;
}

// ── Main page ─────────────────────────────────────────────────────────────────

export default function CartPage() {
  const { lines, count, subtotal, savings, loading, setQty, remove, add } = useCart();
  const { status } = useAuth();
  const router = useRouter();
  const [toast, setToast] = useState<UndoToast | null>(null);
  const [cappedIds, setCappedIds] = useState<Set<number>>(new Set());

  const mrpTotal = lines.reduce((s, l) => s + l.product.mrp * l.quantity, 0);

  function showCapped(productId: number) {
    setCappedIds((prev) => new Set(prev).add(productId));
    setTimeout(() => {
      setCappedIds((prev) => {
        const next = new Set(prev);
        next.delete(productId);
        return next;
      });
    }, 3000);
  }

  function showToast(message: string, onUndo: () => void) {
    setToast({ message, onUndo });
    setTimeout(() => setToast(null), 4000);
  }

  async function handleSetQty(productId: number, qty: number, maxQty: number) {
    if (qty > maxQty && maxQty > 0) {
      showCapped(productId);
      return;
    }
    await setQty(productId, qty);
  }

  async function handleRemove(productId: number) {
    const line = lines.find((l) => l.productId === productId);
    if (!line) return;
    const removed = { ...line };
    await remove(productId);
    showToast(`Removed ${removed.product.name}`, () => {
      void add(removed.product, removed.quantity);
    });
  }

  function goToCheckout() {
    if (status !== "authed") {
      router.push(`/login?next=/checkout`);
      return;
    }
    router.push("/checkout");
  }

  if (loading) {
    return (
      <>
        <AppHeader />
        <CartSkeleton />
      </>
    );
  }

  return (
    <>
      <AppHeader />
      <main className="mx-auto max-w-shell px-lg py-xl">
        <BackButton fallback="/" className="mb-md" />
        {/* Header */}
        <div className="mb-xl border-b border-hairline pb-lg">
          <h1 className="text-headline-md text-ink">My Cart</h1>
          <p className="mt-xs text-body-sm text-muted">
            {count === 0
              ? "Empty for now"
              : `${count} ${count === 1 ? "item" : "items"} in your bag`}
          </p>
        </div>

        {lines.length === 0 ? (
          <EmptyCart />
        ) : (
          <div className="flex flex-col gap-xl lg:flex-row lg:items-start">
            {/* Left column — items */}
            <div className="flex flex-1 flex-col gap-lg">
              {/* Savings banner */}
              {savings > 0 && (
                <div className="flex items-center gap-sm rounded-md bg-success-soft px-md py-sm">
                  <span className="text-body-sm font-bold text-success">
                    You are saving {formatINR(savings)} on this order
                  </span>
                </div>
              )}

              {/* Item list */}
              <div className="divide-y divide-hairline rounded-md bg-white">
                {lines.map((line) => {
                  const { product } = line;
                  const hasDiscount = product.mrp > product.sellingPrice;
                  const discountPct = hasDiscount
                    ? Math.round(((product.mrp - product.sellingPrice) / product.mrp) * 100)
                    : 0;
                  const maxQty = product.stockQuantity > 0 ? product.stockQuantity : 999;
                  const isCapped = cappedIds.has(product.id);

                  return (
                    <div key={line.id} className="flex gap-md p-md">
                      {/* Image */}
                      <Link href={`/p/${product.id}`} className="shrink-0">
                        <div className="h-20 w-20 overflow-hidden rounded-sm bg-canvas">
                          {product.images[0] ? (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img
                              src={mediaSrc(product.images[0].url) ?? ""}
                              alt={product.name}
                              className="h-full w-full object-cover"
                              onError={(e) => {
                                (e.currentTarget as HTMLImageElement).style.display = "none";
                              }}
                            />
                          ) : (
                            <div className="flex h-full w-full items-center justify-center">
                              <ShoppingCart className="h-6 w-6 text-muted" />
                            </div>
                          )}
                        </div>
                      </Link>

                      {/* Details */}
                      <div className="flex flex-1 flex-col gap-xs">
                        <Link href={`/p/${product.id}`}>
                          <p className="line-clamp-2 text-body-sm font-bold text-ink leading-snug">
                            {product.name}
                          </p>
                        </Link>
                        {product.shop?.name && (
                          <span className="inline-flex w-fit rounded-full bg-brand-soft px-sm py-xs text-label-md text-brand">
                            {product.shop.name}
                          </span>
                        )}

                        {/* Price row */}
                        <div className="flex flex-wrap items-center gap-sm">
                          <span className="text-title-sm font-extrabold text-ink">
                            {formatINR(product.sellingPrice)}
                          </span>
                          {hasDiscount && (
                            <span className="text-body-sm text-muted line-through">
                              {formatINR(product.mrp)}
                            </span>
                          )}
                          {discountPct > 0 && (
                            <span className="rounded-full bg-success-soft px-sm py-xs text-label-md font-extrabold text-success">
                              {discountPct}% off
                            </span>
                          )}
                        </div>

                        {isCapped && (
                          <p className="text-body-sm text-warning">
                            Only {maxQty} left in stock
                          </p>
                        )}

                        {/* Stepper + remove */}
                        <div className="flex items-center justify-between">
                          <QuantityStepper
                            qty={line.quantity}
                            maxQty={maxQty}
                            onDecrement={() =>
                              void handleSetQty(product.id, line.quantity - 1, maxQty)
                            }
                            onIncrement={() =>
                              void handleSetQty(product.id, line.quantity + 1, maxQty)
                            }
                          />
                          <button
                            onClick={() => void handleRemove(product.id)}
                            className="flex items-center gap-xs text-body-sm font-bold text-error hover:text-error focus-visible:outline-none"
                          >
                            <Trash2 className="h-4 w-4" />
                            Remove
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>

              {/* Bill summary */}
              <BillCard subtotal={subtotal} mrpTotal={mrpTotal} savings={savings} />

              {/* Reassurance */}
              <div className="flex items-center gap-md rounded-md bg-white px-md py-sm">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-sm bg-brand-soft">
                  <ShieldCheck className="h-5 w-5 text-brand" />
                </div>
                <div>
                  <p className="text-body-sm font-extrabold text-ink">Safe and secure</p>
                  <p className="text-label-md text-muted">
                    Cancel any time before the shop confirms.
                  </p>
                </div>
              </div>
            </div>

            {/* Right column — checkout CTA (sticky on desktop) */}
            <div className="lg:sticky lg:top-xl lg:w-72">
              <div className="rounded-md bg-white p-md shadow-floating">
                <div className="mb-md">
                  <p className="text-label-md text-muted">Cart total</p>
                  <p className="text-title-lg font-extrabold text-ink">
                    {formatINR(subtotal)}
                  </p>
                  {savings > 0 && (
                    <p className="text-body-sm text-success">
                      You save {formatINR(savings)}
                    </p>
                  )}
                </div>
                <button
                  onClick={goToCheckout}
                  className="inline-flex h-11 w-full items-center justify-center rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
                >
                  Proceed to checkout
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Undo toast */}
        {toast && (
          <div className="fixed bottom-xl left-1/2 z-50 flex -translate-x-1/2 items-center gap-md rounded-button bg-ink px-md py-sm shadow-snackbar">
            <span className="text-body-sm text-white">{toast.message}</span>
            <button
              onClick={() => {
                toast.onUndo();
                setToast(null);
              }}
              className="text-label-md font-bold text-brand-soft hover:text-brand focus-visible:outline-none"
            >
              UNDO
            </button>
          </div>
        )}
      </main>
    </>
  );
}

// ── Sub-components ─────────────────────────────────────────────────────────────

function QuantityStepper({
  qty,
  maxQty,
  onDecrement,
  onIncrement,
}: {
  qty: number;
  maxQty: number;
  onDecrement: () => void;
  onIncrement: () => void;
}) {
  return (
    <div className="flex items-center rounded-sm border border-hairline bg-white">
      <button
        onClick={onDecrement}
        className="flex h-8 w-8 items-center justify-center text-ink hover:bg-canvas focus-visible:outline-none disabled:opacity-40"
        aria-label="Decrease quantity"
      >
        <Minus className="h-3 w-3" />
      </button>
      <span className="min-w-8 px-sm text-center text-body-sm font-bold text-ink">
        {qty}
      </span>
      <button
        onClick={onIncrement}
        disabled={maxQty > 0 && qty >= maxQty}
        className="flex h-8 w-8 items-center justify-center text-ink hover:bg-canvas focus-visible:outline-none disabled:opacity-40"
        aria-label="Increase quantity"
      >
        <Plus className="h-3 w-3" />
      </button>
    </div>
  );
}

function BillCard({
  subtotal,
  mrpTotal,
  savings,
}: {
  subtotal: number;
  mrpTotal: number;
  savings: number;
}) {
  return (
    <div className="rounded-md bg-white p-md">
      <p className="mb-sm text-label-md font-extrabold uppercase tracking-wide text-muted">
        Bill Summary
      </p>
      <div className="flex flex-col gap-xs">
        {savings > 0 && (
          <BillRow
            label="Items (MRP)"
            value={formatINR(mrpTotal)}
            valueClass="text-muted line-through"
          />
        )}
        <BillRow label="Items total" value={formatINR(subtotal)} />
        {savings > 0 && (
          <BillRow
            label="Product discount"
            value={`− ${formatINR(savings)}`}
            valueClass="text-success font-bold"
          />
        )}
        <BillRow label="Delivery" value="FREE" valueClass="text-success font-bold" />
        <div className="my-xs border-t border-hairline" />
        <BillRow
          label="Cart total"
          value={formatINR(subtotal)}
          bold
        />
      </div>
    </div>
  );
}

function BillRow({
  label,
  value,
  bold = false,
  valueClass = "",
}: {
  label: string;
  value: string;
  bold?: boolean;
  valueClass?: string;
}) {
  return (
    <div className="flex items-center justify-between py-xs">
      <span
        className={
          bold
            ? "text-body-md font-extrabold text-ink"
            : "text-body-sm text-muted"
        }
      >
        {label}
      </span>
      <span
        className={[
          bold ? "text-body-md font-extrabold text-ink" : "text-body-sm font-bold text-ink",
          valueClass,
        ]
          .filter(Boolean)
          .join(" ")}
      >
        {value}
      </span>
    </div>
  );
}

function EmptyCart() {
  return (
    <div className="flex flex-col items-center py-xxxl text-center">
      <div className="mb-lg flex h-24 w-24 items-center justify-center rounded-xl bg-canvas">
        <ShoppingCart className="h-12 w-12 text-muted" />
      </div>
      <h2 className="text-title-md font-extrabold text-ink">Your cart is empty</h2>
      <p className="mt-xs max-w-snug text-body-sm text-muted">
        Browse the marketplace and add items to start checkout.
      </p>
      <Link
        href="/"
        className="mt-lg inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
      >
        Continue shopping
      </Link>
    </div>
  );
}

function CartSkeleton() {
  return (
    <div className="mx-auto max-w-shell animate-pulse px-lg py-xl">
      <div className="mb-xl h-8 w-32 rounded-sm bg-canvas" />
      <div className="flex gap-xl">
        <div className="flex flex-1 flex-col gap-md">
          {[1, 2, 3].map((i) => (
            <div key={i} className="flex gap-md rounded-md bg-white p-md">
              <div className="h-20 w-20 rounded-sm bg-canvas" />
              <div className="flex flex-1 flex-col gap-sm">
                <div className="h-4 w-3/4 rounded-xs bg-canvas" />
                <div className="h-4 w-1/3 rounded-xs bg-canvas" />
                <div className="h-4 w-1/4 rounded-xs bg-canvas" />
              </div>
            </div>
          ))}
        </div>
        <div className="hidden h-40 w-72 rounded-md bg-white lg:block" />
      </div>
    </div>
  );
}
