"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  MapPin,
  Tag,
  Wallet,
  Truck,
  Store,
  Lock,
  RotateCcw,
  HeadphonesIcon,
  ChevronRight,
  Plus,
  Package,
  CreditCard,
} from "lucide-react";
import { useCart } from "@/features/cart/cart-context";
import { useAuth } from "@/features/auth/auth-context";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { formatINR } from "@/shared/format";
import {
  fetchAddresses,
  createAddress,
} from "@/features/addresses/api";
import {
  validateCoupon,
  autoApplyCoupon,
  fetchWallet,
  placeOrder,
  initiatePayment,
  syncPayment,
} from "@/features/checkout/api";
import { AddressForm } from "@/features/addresses/components/address-form";
import {
  computeCouponDiscount,
  type Coupon,
  type WalletSnapshot,
} from "@/features/checkout/types";
import type { UserAddress, AddressFormValues } from "@/features/addresses/types";
import { addressOneLine } from "@/features/addresses/types";
import { openRazorpayCheckout } from "@/shared/razorpay";
import type { PaySession } from "@/shared/razorpay";
import { BackButton } from "@/shared/ui/back-button";
import { mediaSrc } from "@/shared/media";

// ── Outcome enum (mirrors Flutter _PayAttemptOutcome) ────────────────────────

type PayAttemptOutcome = "paid" | "pendingConfirmation" | "dismissed" | "failed";

// ── Checkout page ─────────────────────────────────────────────────────────────

function CheckoutInner() {
  const router = useRouter();
  const { user } = useAuth();
  const { lines, subtotal, clear } = useCart();

  // ── Address state ────────────────────────────────────────────────────────
  const [addresses, setAddresses] = useState<UserAddress[]>([]);
  const [addressesLoading, setAddressesLoading] = useState(true);
  const [addressesError, setAddressesError] = useState<string | null>(null);
  const [selectedAddressId, setSelectedAddressId] = useState<number | null>(null);
  const [showAddressSheet, setShowAddressSheet] = useState(false);
  const [showAddForm, setShowAddForm] = useState(false);

  // ── Coupon state ─────────────────────────────────────────────────────────
  const [couponCode, setCouponCode] = useState("");
  const [appliedCoupon, setAppliedCoupon] = useState<Coupon | null>(null);
  const [couponApplying, setCouponApplying] = useState(false);
  const [couponError, setCouponError] = useState<string | null>(null);
  const [autoApplied, setAutoApplied] = useState(false);

  // ── Wallet state ─────────────────────────────────────────────────────────
  const [wallet, setWallet] = useState<WalletSnapshot | null>(null);
  const [walletLoaded, setWalletLoaded] = useState(false);
  const [useWallet, setUseWallet] = useState(false);

  // ── Payment method ────────────────────────────────────────────────────────
  const [payOnline, setPayOnline] = useState(false);

  // ── Place order state ─────────────────────────────────────────────────────
  const [placing, setPlacing] = useState(false);
  const [placeError, setPlaceError] = useState<string | null>(null);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const submittingRef = useRef(false);

  // One idempotency key per visit — useState lazy initialiser runs outside render.
  const [idempotencyKeyValue] = useState<string>(() =>
    typeof crypto !== "undefined" && typeof crypto.randomUUID === "function"
      ? crypto.randomUUID()
      : `key-${performance.now().toString(36)}`,
  );
  const idempotencyKey = { current: idempotencyKeyValue };

  // ── Derived totals ────────────────────────────────────────────────────────
  const mrpTotal = lines.reduce((s, l) => s + l.product.mrp * l.quantity, 0);
  const productSavings = Math.max(0, mrpTotal - subtotal);
  const deliveryStrike = 49;
  const deliveryCharge = 0;

  const couponDiscount = appliedCoupon
    ? computeCouponDiscount(appliedCoupon, subtotal)
    : 0;
  const afterCoupon = Math.max(0, subtotal - couponDiscount);
  const walletBalance = wallet?.balance ?? 0;
  const walletApply = useWallet ? Math.min(walletBalance, afterCoupon) : 0;
  const grandTotal = Math.max(0, afterCoupon - walletApply);
  const totalSavings = productSavings + (deliveryStrike - deliveryCharge) + couponDiscount;

  const selectedAddress = addresses.find((a) => a.id === selectedAddressId) ?? null;

  // ── Unique shop ids for coupon API ────────────────────────────────────────
  const shopIds = Array.from(new Set(lines.map((l) => l.product.shop.id)));

  // ── Load addresses ────────────────────────────────────────────────────────
  useEffect(() => {
    void (async () => {
      try {
        const data = await fetchAddresses();
        setAddresses(data);
        // Auto-select default
        const def = data.find((a) => a.isDefault) ?? data[0];
        if (def) setSelectedAddressId(def.id);
      } catch (err) {
        setAddressesError(err instanceof Error ? err.message : "Could not load addresses.");
      } finally {
        setAddressesLoading(false);
      }
    })();
  }, []);

  // ── Load wallet ────────────────────────────────────────────────────────────
  useEffect(() => {
    void (async () => {
      try {
        const data = await fetchWallet();
        setWallet(data);
      } catch {
        /* non-fatal */
      } finally {
        setWalletLoaded(true);
      }
    })();
  }, []);

  // ── Auto-apply coupon on load ──────────────────────────────────────────────
  useEffect(() => {
    if (lines.length === 0 || shopIds.length === 0) return;
    void (async () => {
      try {
        const res = await autoApplyCoupon(subtotal, shopIds);
        if (res.ok) {
          setAppliedCoupon(res.coupon);
          setAutoApplied(true);
        }
      } catch {
        /* best-effort */
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // intentionally only on mount

  // ── Apply coupon ──────────────────────────────────────────────────────────
  async function handleApplyCoupon() {
    const code = couponCode.trim().toUpperCase();
    if (!code) return;
    setCouponApplying(true);
    setCouponError(null);
    try {
      const res = await validateCoupon(code, subtotal, shopIds);
      if (res.ok) {
        setAppliedCoupon(res.coupon);
        setAutoApplied(false);
        setCouponCode("");
      } else {
        setCouponError(res.message);
        setAppliedCoupon(null);
      }
    } catch (err) {
      setCouponError(err instanceof Error ? err.message : "Could not validate coupon.");
    } finally {
      setCouponApplying(false);
    }
  }

  function removeCoupon() {
    setAppliedCoupon(null);
    setAutoApplied(false);
    setCouponCode("");
    setCouponError(null);
  }

  // ── Add address ───────────────────────────────────────────────────────────
  async function handleAddAddress(values: AddressFormValues) {
    const created = await createAddress(values);
    setAddresses((prev) => [...prev, created]);
    setSelectedAddressId(created.id);
    setShowAddForm(false);
    setShowAddressSheet(false);
  }

  // ── Place order ───────────────────────────────────────────────────────────
  async function handlePlaceOrder() {
    if (submittingRef.current) return;
    if (!selectedAddressId) {
      setPlaceError("Add a delivery address to continue.");
      return;
    }
    if (lines.length === 0) {
      setPlaceError("Your cart is empty.");
      return;
    }

    // Confirm dialog for ≥ ₹500
    if (grandTotal >= 500 && !showConfirmDialog) {
      setShowConfirmDialog(true);
      return;
    }
    setShowConfirmDialog(false);

    submittingRef.current = true;
    setPlacing(true);
    setPlaceError(null);

    try {
      const orderBody = {
        items: lines.map((l) => ({
          productId: l.productId,
          quantity: l.quantity,
          expectedUnitPrice: l.product.sellingPrice,
        })),
        addressId: selectedAddressId,
        couponCode: appliedCoupon?.code,
        useWallet,
      };

      const order = await placeOrder(orderBody, idempotencyKey.current);
      await clear();

      if (payOnline) {
        const outcome = await startOnlinePayment(order.id);
        // Navigate once with the toast param so no intermediate render without it
        router.replace(`/orders/${order.id}?toast=${getToastParam(outcome)}`);
        return;
      }

      router.replace(`/orders/${order.id}`);
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : "";
      const errBody = (err as { body?: OrderErrorBody }).body;
      setPlaceError(friendlyOrderError(errMsg, errBody));
    } finally {
      setPlacing(false);
      submittingRef.current = false;
    }
  }

  async function startOnlinePayment(orderId: number): Promise<PayAttemptOutcome> {
    try {
      const session = await initiatePayment(orderId);
      const result = await openRazorpayCheckout(session as PaySession, {
        name: "ShopXY",
        description: `Order #${orderId}`,
        prefillEmail: user?.email ?? undefined,
        prefillContact: undefined,
      });
      if (result.outcome === "success") {
        try {
          const sync = await syncPayment(orderId);
          return sync.paymentStatus === "PAID" ? "paid" : "pendingConfirmation";
        } catch {
          return "pendingConfirmation";
        }
      }
      return result.outcome === "dismissed" ? "dismissed" : "failed";
    } catch {
      return "failed";
    }
  }

  function getToastParam(outcome: PayAttemptOutcome): string {
    switch (outcome) {
      case "paid": return "payment_success";
      case "pendingConfirmation": return "payment_pending";
      case "dismissed": return "payment_dismissed";
      case "failed": return "payment_failed";
    }
  }

  // ── Groups by shop ────────────────────────────────────────────────────────
  const shopGroups = lines.reduce<Map<number, { name: string; lines: typeof lines }>>(
    (map, line) => {
      const shopId = line.product.shop.id;
      if (!map.has(shopId)) {
        map.set(shopId, { name: line.product.shop.name, lines: [] });
      }
      map.get(shopId)!.lines.push(line);
      return map;
    },
    new Map(),
  );
  const shopGroupArray = Array.from(shopGroups.entries());

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <>
      <AppHeader />
      <main className="mx-auto max-w-shell px-lg py-xl">
        <BackButton fallback="/cart" className="mb-md" />
        {/* Page heading */}
        <div className="mb-xl border-b border-hairline pb-lg">
          <h1 className="text-headline-md text-ink">Checkout</h1>
          <p className="mt-xs text-body-sm text-muted">Review your order and place it</p>
        </div>

        <div className="flex flex-col gap-xl lg:flex-row lg:items-start">
          {/* Left — form sections */}
          <div className="flex flex-1 flex-col gap-xl">
            {/* ── Deliver to ──────────────────────────────────── */}
            <section>
              <SectionLabel label="DELIVER TO" icon={<MapPin size={14} />} />
              {addressesLoading ? (
                <LoadingCard />
              ) : addressesError && addresses.length === 0 ? (
                <ErrorCard
                  message={addressesError}
                  onRetry={() => {
                    setAddressesError(null);
                    setAddressesLoading(true);
                    void fetchAddresses()
                      .then((d) => {
                        setAddresses(d);
                        const def = d.find((a) => a.isDefault) ?? d[0];
                        if (def) setSelectedAddressId(def.id);
                      })
                      .catch((e: unknown) =>
                        setAddressesError(
                          e instanceof Error ? e.message : "Could not load addresses.",
                        ),
                      )
                      .finally(() => setAddressesLoading(false));
                  }}
                />
              ) : selectedAddress ? (
                <div className="flex items-start gap-md rounded-md bg-white p-md">
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-sm bg-brand-soft">
                    <MapPin className="h-5 w-5 text-brand" />
                  </div>
                  <div className="flex-1">
                    <div className="flex flex-wrap items-center gap-sm">
                      <span className="text-body-md font-extrabold text-ink">
                        {selectedAddress.fullName}
                      </span>
                      {selectedAddress.label && (
                        <span className="rounded-full bg-canvas px-sm py-xs text-label-md font-bold text-ink uppercase">
                          {selectedAddress.label}
                        </span>
                      )}
                      {selectedAddress.isDefault && (
                        <span className="rounded-full bg-success-soft px-sm py-xs text-label-md font-extrabold text-success uppercase">
                          Default
                        </span>
                      )}
                    </div>
                    <p className="mt-xs text-body-sm text-ink">{addressOneLine(selectedAddress)}</p>
                    {selectedAddress.phone && (
                      <p className="mt-xs text-label-md text-muted">{selectedAddress.phone}</p>
                    )}
                  </div>
                  <button
                    onClick={() => setShowAddressSheet(true)}
                    className="shrink-0 text-label-md font-extrabold text-brand hover:text-brand-strong focus-visible:outline-none"
                  >
                    Change
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => setShowAddressSheet(true)}
                  className="flex w-full items-center gap-md rounded-md border border-brand bg-white p-md text-left hover:bg-brand-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
                >
                  <MapPin className="h-5 w-5 text-brand" />
                  <div className="flex-1">
                    <p className="text-body-md font-extrabold text-ink">
                      Add a delivery address
                    </p>
                    <p className="text-label-md text-muted">
                      We need somewhere to send your order.
                    </p>
                  </div>
                  <ChevronRight className="h-5 w-5 text-muted" />
                </button>
              )}

              {/* Delivery estimate when address selected */}
              {selectedAddress && (
                <div className="mt-sm flex items-center gap-md rounded-md bg-white p-md">
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-sm bg-success-soft">
                    <Truck className="h-5 w-5 text-success" />
                  </div>
                  <div>
                    <p className="text-body-md font-extrabold text-ink">
                      Estimated delivery in 3–5 days
                    </p>
                    <p className="text-label-md text-muted">
                      Standard delivery · merchant confirms a final date
                    </p>
                  </div>
                </div>
              )}
            </section>

            {/* ── Order items ──────────────────────────────────── */}
            <section>
              <SectionLabel
                label={`ORDER ITEMS · ${lines.length} ${lines.length === 1 ? "item" : "items"}`}
                icon={<Package size={14} />}
              />

              {shopGroupArray.length > 1 && (
                <div className="mb-sm flex items-start gap-sm rounded-md border border-brand/20 bg-brand-soft px-md py-sm">
                  <Store className="mt-xs h-4 w-4 shrink-0 text-brand-strong" />
                  <p className="text-label-md font-bold text-brand-strong">
                    Your cart has items from {shopGroupArray.length} shops — we&apos;ll create{" "}
                    {shopGroupArray.length} separate orders, one per shop.
                  </p>
                </div>
              )}

              <div className="flex flex-col gap-sm">
                {shopGroupArray.map(([shopId, group], idx) => (
                  <div key={shopId} className="rounded-md bg-white">
                    {shopGroupArray.length > 1 && (
                      <div className="flex items-center justify-between border-b border-hairline px-md py-sm">
                        <span className="rounded-full bg-brand-soft px-sm py-xs text-label-md font-bold text-brand">
                          {group.name}
                        </span>
                        <span className="text-label-md text-muted">
                          Order {idx + 1} of {shopGroupArray.length}
                        </span>
                      </div>
                    )}
                    {group.lines.map((line, i) => (
                      <div
                        key={line.id}
                        className={`flex gap-md p-md ${i > 0 ? "border-t border-hairline" : ""}`}
                      >
                        <div className="h-14 w-14 shrink-0 overflow-hidden rounded-sm bg-canvas">
                          {line.product.images[0] ? (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img
                              src={mediaSrc(line.product.images[0].url) ?? ""}
                              alt={line.product.name}
                              className="h-full w-full object-cover"
                              onError={(e) => {
                                (e.currentTarget as HTMLImageElement).style.display = "none";
                              }}
                            />
                          ) : (
                            <div className="flex h-full w-full items-center justify-center text-muted">
                              —
                            </div>
                          )}
                        </div>
                        <div className="flex flex-1 flex-col gap-xs">
                          <p className="line-clamp-2 text-body-sm font-bold text-ink leading-snug">
                            {line.product.name}
                          </p>
                          <div className="flex flex-wrap items-center gap-xs">
                            <span className="rounded-full bg-canvas px-sm py-xs text-label-md font-bold text-ink">
                              Qty {line.quantity}
                            </span>
                            {line.product.unit && (
                              <span className="text-label-md text-muted">
                                {line.product.unit}
                              </span>
                            )}
                          </div>
                        </div>
                        <span className="shrink-0 text-body-md font-extrabold text-ink">
                          {formatINR(line.product.sellingPrice * line.quantity)}
                        </span>
                      </div>
                    ))}
                    {shopGroupArray.length > 1 && (
                      <div className="flex items-center justify-between border-t border-hairline px-md py-sm">
                        <span className="text-label-md text-muted">Shop subtotal</span>
                        <span className="text-body-sm font-extrabold text-ink">
                          {formatINR(
                            group.lines.reduce(
                              (s, l) => s + l.product.sellingPrice * l.quantity,
                              0,
                            ),
                          )}
                        </span>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </section>

            {/* ── Offers ───────────────────────────────────────── */}
            <section>
              <SectionLabel label="OFFERS" icon={<Tag size={14} />} />
              <CouponCard
                appliedCoupon={appliedCoupon}
                autoApplied={autoApplied}
                couponCode={couponCode}
                couponApplying={couponApplying}
                couponError={couponError}
                couponDiscount={couponDiscount}
                onCodeChange={(v) => {
                  setCouponCode(v.toUpperCase());
                  setCouponError(null);
                }}
                onApply={() => void handleApplyCoupon()}
                onRemove={removeCoupon}
              />

              {walletLoaded && (wallet?.balance ?? 0) > 0 && (
                <div className="mt-sm flex items-center gap-md rounded-md border border-hairline bg-white px-md py-sm">
                  <Wallet className="h-5 w-5 text-brand" />
                  <div className="flex-1">
                    <p className="text-body-md font-extrabold text-ink">
                      {useWallet && walletApply > 0
                        ? `Using ${formatINR(walletApply)} from wallet`
                        : "Use wallet balance"}
                    </p>
                    <p className="text-label-md text-muted">
                      Available · {formatINR(wallet!.balance)}
                    </p>
                  </div>
                  <button
                    role="switch"
                    aria-checked={useWallet}
                    onClick={() => setUseWallet((v) => !v)}
                    className={[
                      "relative h-6 w-10 rounded-full transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand",
                      useWallet ? "bg-brand" : "bg-disabled",
                    ].join(" ")}
                  >
                    <span
                      className={[
                        "absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform",
                        useWallet ? "translate-x-4" : "translate-x-0",
                      ].join(" ")}
                    />
                  </button>
                </div>
              )}
            </section>

            {/* ── Payment method ────────────────────────────────── */}
            <section>
              <SectionLabel label="PAYMENT METHOD" icon={<CreditCard size={14} />} />
              <div className="flex flex-col gap-sm">
                <PayOption
                  title="Cash on Delivery"
                  subtitle="Pay the shop when your order arrives."
                  selected={!payOnline}
                  onSelect={() => setPayOnline(false)}
                />
                <PayOption
                  title="Pay Online"
                  subtitle="UPI, cards & netbanking via Razorpay."
                  selected={payOnline}
                  onSelect={() => setPayOnline(true)}
                />
              </div>
            </section>

            {/* ── Price details ─────────────────────────────────── */}
            <section>
              <SectionLabel label="PRICE DETAILS" />
              <PriceCard
                itemsTotal={subtotal}
                mrpTotal={mrpTotal}
                productSavings={productSavings}
                deliveryStrike={deliveryStrike}
                grandTotal={grandTotal}
                couponDiscount={couponDiscount}
                walletApplied={walletApply}
              />
              {totalSavings > 0 && (
                <div className="mt-sm flex items-center gap-sm rounded-md bg-success-soft px-md py-sm">
                  <span className="text-body-sm font-bold text-success">
                    You&apos;ll save {formatINR(totalSavings)} on this order
                  </span>
                </div>
              )}
            </section>

            {/* ── Trust footer ────────────────────────────────────── */}
            <div className="flex flex-wrap gap-sm">
              {[
                { icon: <Lock className="h-5 w-5 text-brand" />, label: "Secure checkout" },
                { icon: <RotateCcw className="h-5 w-5 text-brand" />, label: "Easy cancel" },
                {
                  icon: <HeadphonesIcon className="h-5 w-5 text-brand" />,
                  label: "Real support",
                },
              ].map(({ icon, label }) => (
                <div
                  key={label}
                  className="flex flex-1 flex-col items-center gap-xs rounded-sm bg-white px-sm py-sm"
                >
                  {icon}
                  <span className="text-label-md font-bold text-ink text-center">{label}</span>
                </div>
              ))}
            </div>
            <p className="text-center text-label-md text-muted">
              By placing your order, you agree to our terms. Pricing and availability may be
              re-confirmed by the shop.
            </p>
          </div>

          {/* Right — sticky order summary */}
          <div className="lg:sticky lg:top-xl lg:w-72">
            <div className="rounded-lg border border-hairline bg-white p-md shadow-floating">
              <p className="mb-sm text-label-md font-extrabold uppercase tracking-wide text-muted">
                Price details
              </p>
              {/* Bill rows with divider rhythm */}
              <div className="flex flex-col gap-xs">
                <StickyBillRow label="Items total" value={formatINR(subtotal)} />
                {productSavings > 0 && (
                  <StickyBillRow
                    label="Savings"
                    value={`− ${formatINR(productSavings)}`}
                    valueClass="text-success"
                  />
                )}
                {couponDiscount > 0 && (
                  <StickyBillRow
                    label="Coupon"
                    value={`− ${formatINR(couponDiscount)}`}
                    valueClass="text-success"
                  />
                )}
                {walletApply > 0 && (
                  <StickyBillRow
                    label="Wallet"
                    value={`− ${formatINR(walletApply)}`}
                    valueClass="text-success"
                  />
                )}
                <StickyBillRow label="Delivery" value="FREE" valueClass="text-success" />
              </div>
              <div className="my-md border-t border-hairline" />
              {/* Bold total */}
              <div className="flex items-center justify-between">
                <span className="text-body-md font-extrabold text-ink">Total payable</span>
                <span className="text-title-md font-extrabold text-ink">{formatINR(grandTotal)}</span>
              </div>
              {totalSavings > 0 && (
                <p className="mt-xs text-body-sm text-success">
                  You save {formatINR(totalSavings)}
                </p>
              )}

              {placeError && (
                <p className="mt-sm rounded-sm bg-error-soft px-sm py-xs text-body-sm text-error">
                  {placeError}
                </p>
              )}

              <button
                onClick={() => void handlePlaceOrder()}
                disabled={placing || !selectedAddress || lines.length === 0}
                className="mt-md inline-flex h-11 w-full items-center justify-center rounded-button bg-brand px-lg text-label-md font-bold text-white transition-colors duration-200 hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:cursor-not-allowed disabled:opacity-50"
              >
                {placing ? "Placing order…" : "Place order"}
              </button>
            </div>
          </div>
        </div>
      </main>

      {/* Address picker sheet */}
      {showAddressSheet && (
        <div
          className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-ink/40"
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowAddressSheet(false);
          }}
        >
          <div className="w-full max-w-panel rounded-t-dialog sm:rounded-dialog bg-white max-h-[80vh] overflow-auto">
            <div className="sticky top-0 border-b border-hairline bg-white px-lg py-md">
              <h2 className="text-title-md font-extrabold text-ink">
                Choose a delivery address
              </h2>
            </div>
            <div>
              {addresses.map((a) => {
                const isSel = a.id === selectedAddressId;
                return (
                  <button
                    key={a.id}
                    role="radio"
                    aria-checked={isSel}
                    onClick={() => {
                      setSelectedAddressId(a.id);
                      setShowAddressSheet(false);
                      setShowAddForm(false);
                    }}
                    className={[
                      "flex w-full items-start gap-md border-b border-hairline px-lg py-md text-left transition-colors duration-200 focus-visible:outline-none",
                      isSel ? "bg-brand-soft" : "hover:bg-canvas",
                    ].join(" ")}
                  >
                    <span
                      className={[
                        "mt-1 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 transition-all duration-200",
                        isSel ? "border-brand bg-brand" : "border-muted bg-white",
                      ].join(" ")}
                    >
                      {isSel ? <span className="h-2 w-2 rounded-full bg-white" /> : null}
                    </span>
                    <div>
                      <p className="text-body-md font-extrabold text-ink">{a.fullName}</p>
                      <p className="text-body-sm text-muted">{addressOneLine(a)}</p>
                    </div>
                  </button>
                );
              })}

              {/* Add new address */}
              {!showAddForm && (
                <button
                  onClick={() => setShowAddForm(true)}
                  className="flex w-full items-center gap-md border-b border-hairline px-lg py-md hover:bg-canvas focus-visible:outline-none"
                >
                  <Plus className="h-5 w-5 text-brand" />
                  <span className="text-body-md font-bold text-ink">Add a new address</span>
                </button>
              )}

              {showAddForm && (
                <div className="px-lg py-md">
                  <AddressForm
                    submitLabel="Save and select"
                    onSubmit={handleAddAddress}
                    onCancel={() => setShowAddForm(false)}
                  />
                </div>
              )}
              <div className="h-lg" />
            </div>
          </div>
        </div>
      )}

      {/* Confirm dialog for ≥ ₹500 */}
      {showConfirmDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink/40 px-lg">
          <div className="w-full max-w-narrow rounded-dialog bg-white p-xl">
            <h2 className="text-title-md font-extrabold text-ink">Place this order?</h2>
            <p className="mt-sm text-body-sm text-muted">
              Total payable {formatINR(grandTotal)}. We double-check larger orders so a stray
              tap doesn&apos;t place one. You can still cancel a per-shop slice from the order
              detail page before the merchant confirms it.
            </p>
            <div className="mt-xl flex gap-sm">
              <button
                onClick={() => setShowConfirmDialog(false)}
                className="inline-flex h-10 flex-1 items-center justify-center rounded-button border border-hairline bg-white text-label-md text-ink hover:bg-canvas focus-visible:outline-none"
              >
                Review
              </button>
              <button
                onClick={() => void handlePlaceOrder()}
                className="inline-flex h-10 flex-1 items-center justify-center rounded-button bg-brand text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none"
              >
                Place order
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

export default function CheckoutPage() {
  return (
    <RequireAuth>
      <CheckoutInner />
    </RequireAuth>
  );
}

// ── Sub-components ─────────────────────────────────────────────────────────────

function SectionLabel({
  label,
  icon,
}: {
  label: string;
  icon?: React.ReactNode;
}) {
  return (
    <div className="mb-sm flex items-center gap-xs">
      {icon ? <span className="flex shrink-0 items-center text-muted">{icon}</span> : null}
      <p className="text-label-md font-extrabold uppercase tracking-wide text-muted">{label}</p>
    </div>
  );
}

function LoadingCard() {
  return (
    <div className="flex h-16 items-center justify-center rounded-md bg-white">
      <div className="h-5 w-5 animate-spin rounded-full border-2 border-hairline border-t-brand" />
    </div>
  );
}

function ErrorCard({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex items-center gap-md rounded-md bg-white p-md">
      <p className="flex-1 text-body-sm text-muted">{message}</p>
      <button
        onClick={onRetry}
        className="inline-flex h-9 items-center rounded-button border border-hairline bg-white px-md text-label-md text-ink hover:bg-canvas focus-visible:outline-none"
      >
        Retry
      </button>
    </div>
  );
}

function PayOption({
  title,
  subtitle,
  selected,
  onSelect,
}: {
  title: string;
  subtitle: string;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      role="radio"
      aria-checked={selected}
      onClick={onSelect}
      className={[
        "flex w-full items-center gap-md rounded-md p-md text-left transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand",
        selected
          ? "border-2 border-brand bg-brand-soft"
          : "border border-hairline bg-white hover:border-brand/30 hover:bg-canvas",
      ].join(" ")}
    >
      {/* Custom radio circle */}
      <span
        className={[
          "flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 transition-all duration-200",
          selected ? "border-brand bg-brand" : "border-muted bg-white",
        ].join(" ")}
      >
        {selected ? <span className="h-2 w-2 rounded-full bg-white" /> : null}
      </span>
      <div>
        <p className="text-body-md font-extrabold text-ink">{title}</p>
        <p className="text-label-md text-muted">{subtitle}</p>
      </div>
    </button>
  );
}

function CouponCard({
  appliedCoupon,
  autoApplied,
  couponCode,
  couponApplying,
  couponError,
  couponDiscount,
  onCodeChange,
  onApply,
  onRemove,
}: {
  appliedCoupon: Coupon | null;
  autoApplied: boolean;
  couponCode: string;
  couponApplying: boolean;
  couponError: string | null;
  couponDiscount: number;
  onCodeChange: (v: string) => void;
  onApply: () => void;
  onRemove: () => void;
}) {
  const applied = appliedCoupon !== null;
  return (
    <div
      className={[
        "flex items-center gap-md rounded-md bg-white p-md",
        applied ? "border border-brand" : "border border-hairline",
      ].join(" ")}
    >
      <Tag className={`h-5 w-5 shrink-0 ${applied ? "text-brand" : "text-muted"}`} />
      <div className="flex-1">
        {applied ? (
          <div>
            <p className="text-body-md font-extrabold text-brand">
              {autoApplied
                ? `Auto-applied · ${appliedCoupon.code}`
                : `${appliedCoupon.code} applied`}
              {autoApplied && (
                <span className="ml-sm rounded-sm bg-brand px-xs py-xs text-label-md font-extrabold text-white">
                  OFFER
                </span>
              )}
            </p>
            {couponDiscount > 0 && (
              <p className="text-body-sm font-bold text-success">
                {formatINR(couponDiscount)} off
              </p>
            )}
          </div>
        ) : (
          <div>
            <input
              type="text"
              value={couponCode}
              onChange={(e) => onCodeChange(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") onApply();
              }}
              placeholder="Enter coupon code"
              className="w-full border-0 bg-transparent text-body-md font-bold text-ink placeholder:text-disabled focus:outline-none"
            />
            {couponError && (
              <p className="mt-xs text-body-sm text-error">{couponError}</p>
            )}
          </div>
        )}
      </div>
      {applied ? (
        <button
          onClick={onRemove}
          className="shrink-0 text-label-md font-bold text-error hover:underline focus-visible:outline-none"
        >
          Remove
        </button>
      ) : (
        <button
          onClick={onApply}
          disabled={couponApplying || !couponCode.trim()}
          className="shrink-0 inline-flex h-9 items-center rounded-button bg-ink px-md text-label-md font-extrabold text-white hover:opacity-90 focus-visible:outline-none disabled:opacity-40"
        >
          {couponApplying ? "…" : "Apply"}
        </button>
      )}
    </div>
  );
}

function PriceCard({
  itemsTotal,
  mrpTotal,
  productSavings,
  deliveryStrike,
  grandTotal,
  couponDiscount,
  walletApplied,
}: {
  itemsTotal: number;
  mrpTotal: number;
  productSavings: number;
  deliveryStrike: number;
  grandTotal: number;
  couponDiscount: number;
  walletApplied: number;
}) {
  return (
    <div className="rounded-md bg-white p-md">
      <div className="flex flex-col gap-xs">
        {productSavings > 0 && (
          <PriceRow
            label="Items (MRP)"
            value={formatINR(mrpTotal)}
            valueClass="line-through text-muted"
          />
        )}
        <PriceRow label="Items total" value={formatINR(itemsTotal)} />
        {productSavings > 0 && (
          <PriceRow
            label="Product discount"
            value={`− ${formatINR(productSavings)}`}
            valueClass="text-success font-bold"
          />
        )}
        <PriceRow
          label="Delivery"
          value={`FREE`}
          extraValue={formatINR(deliveryStrike)}
          valueClass="text-success font-bold"
        />
        {couponDiscount > 0 && (
          <PriceRow
            label="Coupon"
            value={`− ${formatINR(couponDiscount)}`}
            valueClass="text-success font-bold"
          />
        )}
        {walletApplied > 0 && (
          <PriceRow
            label="Wallet"
            value={`− ${formatINR(walletApplied)}`}
            valueClass="text-success font-bold"
          />
        )}
        <div className="my-xs border-t border-hairline" />
        <PriceRow label="Total payable" value={formatINR(grandTotal)} bold />
      </div>
    </div>
  );
}

function PriceRow({
  label,
  value,
  bold = false,
  valueClass = "",
  extraValue,
}: {
  label: string;
  value: string;
  bold?: boolean;
  valueClass?: string;
  extraValue?: string;
}) {
  return (
    <div className="flex items-center justify-between py-xs">
      <span
        className={
          bold ? "text-body-md font-extrabold text-ink" : "text-body-sm text-muted"
        }
      >
        {label}
      </span>
      <div className="flex items-center gap-sm">
        {extraValue && (
          <span className="text-label-md text-muted line-through">{extraValue}</span>
        )}
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
    </div>
  );
}

function StickyBillRow({
  label,
  value,
  valueClass = "",
}: {
  label: string;
  value: string;
  valueClass?: string;
}) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-label-md text-muted">{label}</span>
      <span className={["text-label-md font-bold text-ink", valueClass].filter(Boolean).join(" ")}>
        {value}
      </span>
    </div>
  );
}

interface OrderErrorBody {
  error?: string;
  details?: { productId: number; name: string; oldPrice: number; newPrice: number }[];
}

function friendlyOrderError(msg: string, body?: OrderErrorBody): string {
  if (msg.includes("OWN_SHOP_ITEM")) return "You can't order from your own shop.";
  if (msg.includes("SHOP_NOT_FOUND")) return "One of the shops in your cart is no longer available.";
  if (msg.includes("CROSS_SHOP_ITEM")) return "Cart had a wrong shop attribution — please re-add the items.";
  if (msg.includes("ADDRESS_NOT_OWNED")) return "That address isn't valid for this account.";
  if (msg.includes("COUPON_INVALID")) return "That coupon is no longer valid.";
  if (msg.includes("PRICE_DRIFT")) {
    if (body?.details && body.details.length > 0) {
      const item = body.details[0];
      const more = body.details.length > 1 ? ` (+${body.details.length - 1} more)` : "";
      return `Price changed: ${item.name} is now ${formatINR(item.newPrice)}${more}. Please review and retry.`;
    }
    return "Some prices have changed. Please review and retry.";
  }
  if (msg.includes("OUT_OF_STOCK")) return "One or more items went out of stock.";
  if (!msg) return "Could not place order.";
  return msg;
}
