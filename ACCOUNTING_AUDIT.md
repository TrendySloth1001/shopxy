# ShopXY Accounting & GST Audit — Final Reviewer Report

**Prepared for:** Founder (merchant `nkumawat8956@gmail.com`, customer `nkumawat1010@gmail.com`)
**Scope:** Backend money path — invoices, caution deposits, quotations, payments, returns/wallet, cart/coupons/promos, reports/dashboard, GST mechanics, invoice format, TDS/TCS, accounting integrity
**Date:** 2026-05-30

---

## 1. Executive Summary

The codebase has **systemic, money-incorrect behavior on the primary customer-checkout-to-invoice path** (GST silently dropped to zero, coupons/promos mis-applied), **unbounded discount inputs that mint negative tax invoices**, **a multi-tenant data leak in reports**, and an **uncapped return path that allows unlimited re-refund of the same line**. Several findings are direct GST under/over-collection with quantifiable rupee impact per transaction; others are statutory invoice-format and TDS gaps.

### Severity counts

| Severity | Count |
|---|---|
| Critical | 4 |
| High | 24 |
| Medium | 14 |
| Low | 16 |
| **Total** | **58** |

### Category distribution

| Category | Count |
|---|---|
| GST | 28 |
| Accounting | 7 |
| Rounding | 9 |
| Calculation | 4 |
| Data-integrity | 5 |
| TDS/TCS | 4 |
| Other | 1 |

### The four Critical findings

| # | Title | Path | Rupee impact (per occurrence) |
|---|---|---|---|
| C1 | PR→invoice conversion drops product GST entirely (taxPercent never passed) | cart-coupons-promos | ₹180 GST on a ₹1,000 @18% order, uncollected on **every** customer order |
| C2 | Returns/refunds invisible to all reports — returned sales still counted | reports-dashboard | ₹10,000 net sales + ₹1,800 GST + ₹7,000 COGS overstated per full return |
| C3 | Reports aggregate across ALL shops — no shopId scope | reports-dashboard | Cross-tenant leak; foreign ₹50,000 folds into ₹11,800 own revenue |
| C4 | No cumulative-quantity cap across returns — same line refundable repeatedly | returns-wallet | ₹6,000 wallet credit for ₹3,000 of goods (unbounded) |

---

## 2. Most Dangerous Money-Correctness Bugs (ranked)

### C1 — Customer checkout invoices charge ₹0 GST
**`src/modules/purchase-requests/purchase-requests.service.ts:1148-1155`** (with `invoices.service.ts:329,304`)
`confirmRequest` maps PR items to `createInvoice` as `{productId, quantity, unitPrice}` only. `createInvoice` then computes `taxPct = item.taxPercent ?? 0`, and its product `select` does not even fetch `product.taxPercent`. **Every** invoice minted from a customer purchase-request carries CGST/SGST/IGST = 0.
- **Impact:** ₹1,000 taxable @18% → invoice GST **₹0** instead of ₹180. Systematic GSTR-1 output-tax understatement; buyer gets an invalid tax invoice with no ITC.
- **Fix:** Pass `taxPercent` (and `cessRate`/HSN) from the product snapshot into `createInvoice`, and add `product.taxPercent` to the `productMap` select; or default `item.taxPercent` from `product.taxPercent` when undefined.

### C4 — Same line can be returned-and-refunded repeatedly (unbounded wallet inflation)
**`src/modules/returns/returns.service.ts:203,221-228`**
`BAD_QTY` only rejects when requested qty exceeds the **original** purchased qty; `ALREADY_REQUESTED` only blocks while a prior return is open. Once a return hits `REFUNDED` (or `REJECTED`/`CANCELLED`), a brand-new full-qty return for the same `purchaseRequestItem` is accepted. There is no `SUM` of previously-returned quantity.
- **Impact:** qty 3 @₹1,000 returned+refunded, then returned+refunded again → **₹6,000 wallet credit for ₹3,000 of goods**. Unbounded.
- **Fix:** Aggregate `SUM(ReturnRequestItem.quantity)` for the same `purchaseRequestItemId` across all refunded/open returns and require `requested + alreadyReturned <= original.quantity`.

### C2 — Returns are invisible to every report
**`src/modules/returns/returns.service.ts:406-525`** + **`src/modules/reports/reports.service.ts:30-355`**
`returns.refund()` only flips `ReturnRequest.status` and credits the wallet. It never cancels the source invoice, never issues a CREDIT_NOTE, never posts a `RETURN_IN` stock txn, never reverses cost layers. All reports filter `status='CONFIRMED'` with no `ReturnRequest` awareness.
- **Impact:** Full return of a ₹10,000-taxable / ₹7,000-COGS sale → reported net sales overstated ₹10,000, output GST ₹1,800, COGS ₹7,000, gross profit ₹3,000; the ₹10,000 wallet refund is an unrecorded expense.
- **Standard:** AS 9 / Ind AS 115 (revenue reversal on returns); CGST Sec 34 (credit note adjusts output tax).
- **Fix:** On refund, cancel/credit-note the invoice line, post a `RETURN_IN` reversing FIFO consumption, and/or have reports `LEFT JOIN ReturnRequest` (REFUNDED/RECEIVED) to net out refunded qty/amounts from revenue, GST and COGS.

### C3 — Reports leak across tenants and are numerically wrong
**`src/modules/reports/reports.service.ts:30-367`** + **`src/infra/http/app.ts:345`**
Every query (Prisma aggregate and all `$queryRaw`) filters only by type/status/date — **never** `shop_id`. The `/reports` router is mounted `ownerOnly` but **without** `resolveShop` (contrast `/dashboard` at `app.ts:337`), so `req.shopId` is never resolved.
- **Impact:** Merchant viewing `/reports/sales` with own ₹11,800 and a foreign shop's ₹50,000 sees **₹61,800**; GST netPayable, top customers (PII), top products and profit all leak and are wrong by the size of every other tenant.
- **Fix:** Mount `/reports` with `resolveShop`, thread `req.shopId` into the service, and add `WHERE shop_id = ${shopId}` (and `i.shop_id` on joins) to every query.

### H1 — Carousel promo applied twice on customer orders
**`purchase-requests.service.ts:416-423,530`** + **`invoices.service.ts:317,331-339`**
The cart/PR path sets `unitPrice = round2(sellingPrice - promo.perUnit)` (promo already baked in). `confirmRequest` then calls `createInvoice` with **no** explicit per-item discount, so the auto-fill branch (`item.discount === undefined`) re-resolves the same promo and subtracts `lineDiscount(promo)` a second time.
- **Impact:** sellingPrice 100, qty 10, 10% promo → customer charged ₹900, but invoice `taxableValue = round2(10*90 - 90) = 810.00`. ~₹90 double-discount per such line; under-bills customer and understates revenue/GST base.
- **Fix:** When converting a PR, pass an explicit per-item `discount` (even `0`) so the auto-fill never fires; or pass raw `sellingPrice` + the promo as the line discount — never both.

### H2 — Explicit per-line discount is unbounded → negative taxable value and negative output GST
**`invoices.service.ts:332-353`** + controller **`invoices.controller.ts:14`** (`z.number().nonnegative()`, no upper bound)
The explicit `item.discount` is used verbatim with no clamp against `qty*unitPrice`. The promo branch IS clamped via `lineDiscount()`; the explicit branch bypasses that defense.
- **Impact:** qty 2 × ₹50, discount ₹200 → `taxableValue -100.00`, CGST −9.00, SGST −9.00, lineTotal −118.00, all persisted to `Decimal(12,2)`. A negative-output-tax invoice — invalid for GSTR-1 and usable to net down real tax on other lines.
- **Fix:** Clamp like promos: `itemDiscount = min(item.discount, round2(qty*unitPrice - 0.01))`; and/or reject `discount >= quantity*unitPrice` in `itemSchema`.

### H3 — Header discount can drive the invoice total negative
**`invoices.service.ts:325,388-392`** + controller line 35
`grandTotalRaw = round2(taxableValueTotal + taxAmount - headerDiscount)` with no bound on `headerDiscount`.
- **Impact:** Header discount ₹5,000 on a ₹1,180 invoice → total **−3,820.00**, persisted and rendered (amount-in-words emits "Minus Rupees … only").
- **Fix:** Reject `headerDiscount > taxableValueTotal + taxAmount` (or clamp), and route true value reductions through the CREDIT_NOTE document type.

### H4 — Coupon discount recorded on the order but never applied to the tax invoice
**`purchase-requests.service.ts:583-594, 1141-1155`**
`couponsService.redeem` reduces wallet payable (`CustomerOrder.couponDiscount`), but `confirmRequest`'s `createInvoice` call passes no `discount`/`headerDiscount`. The invoice bills the full pre-coupon amount.
- **Impact:** ₹2,000 order, 20% coupon → customer charged ₹1,600, invoice/ledger says ₹2,000 — a **₹400 discrepancy per order**; revenue overstated, cash won't reconcile to invoice.
- **Standard:** CGST Sec 15(3); Ind AS 115 / AS 9.
- **Fix:** Thread the coupon discount into `createInvoice` as a header discount (or pro-rated per line so the taxable value and GST base drop correctly).

### H5 — Header discount deducted *after* GST (Sec 15(3) ignored)
**`invoices.service.ts:388-390`**
`grandTotalRaw = round2(taxableValueTotal + taxAmount - headerDiscount)` subtracts the invoice-level discount **after** tax was computed on the full `taxableValueTotal`. GST is charged on the pre-discount value while the customer is billed the post-discount amount.
- **Impact:** ₹1,000 line @18% with ₹200 header discount → stores taxableValue=1000.00, GST=180.00, bills total=980.00. Merchant remits ₹180 on goods effectively sold for ₹800 (~₹36 overpaid output tax); GSTR-1 taxable (1000) won't reconcile with value transacted (800). Mirror error understates buyer ITC.
- **Standard:** CGST Sec 15(3)(a); Rule 46.
- **Fix:** Apportion the header discount across lines and recompute each line's taxableValue/GST **before** tax, or forbid post-tax header discount and force line-level discounts.

### H6 — Negative-discount quote line: quote clamps to 0, invoice does not → accepting a ₹0 quote yields a negative tax invoice
**`quotations.service.ts:76`** vs **`invoices.service.ts:340`**
`priceItems` floors with `Math.max(0, qty*unitPrice - discount)`; the invoice engine does not clamp raw item discounts.
- **Impact:** qty 1 × ₹100, discount ₹150, 18% → quote total ₹0.00 (customer accepts a "free" line); `accept()` issues a confirmed TAX_INVOICE with taxableValue −₹50.00, CGST −₹4.50, SGST −₹4.50, total **−₹59.00**.
- **Fix:** Validate `discount <= qty*unitPrice` at quote create/respond time, and clamp raw item discounts on the invoice engine so the two agree.

### H7 — Payments can be recorded against CANCELLED invoices → phantom credits
**`payments.service.ts:140-170`**
The transactional invoice lookup selects `status` but never validates it; a cancelled invoice's `total` is still nonzero so outstanding is positive. Ledgers include only CONFIRMED invoices as debits but **all** payments as credits.
- **Impact:** ₹5,900 receipt against a cancelled ₹5,900 invoice → party balance **−5,900** (phantom refund liability). Void-then-pay fabricates a credit.
- **Fix:** Reject allocation when `invoice.status !== 'CONFIRMED'` (and ideally require SALE for RECEIPT / PURCHASE for PAYMENT). Mirror in `caution.service.adjust`.

### M1 — Quotation total ≠ spawned-invoice total (whole-rupee round-off)
**`quotations.service.ts:96`** vs **`invoices.service.ts:388-392`**
`priceItems` computes `total = round2(subtotal + taxAmount)` with **no** invoice-level round-off; `accept()` bills the round-off-adjusted figure.
- **Impact:** Customer accepts ₹119.77 (qty 7 × ₹14.50 @18%) and is issued a TAX_INVOICE for **₹120.00** — a ₹0.23 silent up-charge on every fractional quote; contract-vs-document mismatch.
- **Fix:** Apply the same whole-invoice round-off inside `priceItems`, or have `accept()` re-price through `invoicesService` and persist that authoritative total before notifying/displaying.

### H8 — Quotations drop GST cess entirely
**`quotations.service.ts:19-28, 277-283`**
`QuotationItemInput` has no `cessRate`; `accept()` omits `cessRate`, so `invoices.service.ts:330` defaults cess to 0.
- **Impact:** qty 10 × ₹100 @28% + 12% cess → correct ₹1,400 (₹120 cess); code issues an invoice for **₹1,280**, under-collecting ₹120 statutory cess per cess-bearing quote.
- **Standard:** GST (Compensation to States) Act 2017.
- **Fix:** Add `cessRate` to the input, snapshot it in `priceItems`, and forward it in the `accept()` mapping.

### M2 — Invoice outstanding / ledger running balances never rounded
**`payments.service.ts:164,386-427,520-561`**
`round2` is imported nowhere in this service; `outstanding` and the party/vendor `running` accumulators are pure float and returned unrounded.
- **Impact:** Balances render binary-float fuzz (e.g. `11111.039999999995` for the true ₹11,111.04); merchant/customer ledgers don't tie to a client re-sum.
- **Fix:** `round2()` outstanding before compare/message, and after each `+=`/`-=` in both ledgers; return `round2(running)`.

### M3 — Hard-delete of a payment silently reopens outstanding, no audit trail
**`payments.service.ts:257-282`**
`deletePayment` hard-deletes. Because due is derived as `total − SUM(payments)`, deleting a receipt instantly increases computed outstanding with no reversal entry. (CAUTION mode correctly reverses its ADJUSTMENT; ordinary receipts do not.)
- **Impact:** A fully-paid ₹11,800 invoice silently becomes ₹11,800 due again; prior-period cash disappears with no trace. Enables undetectable tampering; breaks period-close.
- **Fix:** Replace hard delete with a soft-void / reversing entry preserving the original row + `deletedBy`/reason.

### Lower-severity money/rounding items (latent but real)
- **Over-allocation tolerance** (`payments.service.ts:165`; mirrored `caution.service.ts:283,298`): `amount - outstanding > 0.001` lets a receipt overshoot outstanding by up to ₹0.001, always upward. *Fix:* compare on rounded paise, strict `>`. (Low)
- **One-sided 0.001 caution slack** (`caution.service.ts:166,224,283`): refund 0.001 against a 0.00 balance drives the liability ledger to −0.001. *Fix:* paise-integer compare with strict `> 0`. (Low)
- **Caution amounts persisted without `round2()`** (`caution.service.ts:182,237,317`; `caution-requests.service.ts:109`): un-validated sub-paisa input is DB-rounded; the float in-memory balance can disagree with a re-summed SUM by a paisa. *Fix:* `round2()` before `Prisma.Decimal`, add a 2dp Zod refinement, return DB-derived balance. (Low)
- **Three+ divergent `round2` implementations on the money path** (`coupons.service.ts:75-77` no-EPSILON vs `promo-pricing.ts:19-21` and `invoices.service.ts:866-868` with EPSILON; `purchase-requests.service.ts:1559` no-EPSILON): off-by-0.01 at half-paise boundaries — **latent** today (coupon/order path is internally self-consistent; not cross-wired to the invoice path). *Fix:* extract one shared `round2`. (Low)
- **Header tax float-accumulated before a single `round2`** (`invoices.service.ts:362-365,387`): correct today only because EPSILON absorbs the drift; not provably exact at the 200-line cap. *Fix:* accumulate in integer paise. (Low)
- **`round2` EPSILON nudge** (`invoices.service.ts:866-867`): not a correct general half-up rounder for negatives/large magnitudes; matters only once negatives are allowed upstream. *Fix:* round magnitude then reapply sign. (Low)

---

## 3. Indian Compliance Gaps (grouped, with citations)

### 3.1 GST — output tax computation & valuation
| Finding | File:line | Section/Rule/Circular |
|---|---|---|
| Header discount deducted after tax (Sec 15(3) ignored) | `invoices.service.ts:388-390` | CGST Sec 15(3)(a); Rule 46 |
| `isInterstateSupply` defaults to intrastate when a state code is unknown | `indian.ts:93-99` | IGST Sec 7/8; Sec 10/12; CGST Sec 16 (ITC) |
| Place-of-supply persisted NULL while tax is still split; POS not validated | `invoices.service.ts:294-298` | IGST Sec 10-12; CGST Rule 46(m); GSTR-1 schema |
| No tax-inclusive (MRP) pricing mode | `invoices.service.ts:340-358` | CGST Sec 15 r/w Rule 35 |
| Forfeit with `gstTreatment='SUPPLY'` accrues no output GST | `caution.service.ts:232-243` | Circular 178/11/2022-GST ¶11.3; CGST Sec 7 + Sch II |
| Forfeit amount has no gross/net (inclusive vs exclusive) semantics | `caution.service.ts:236-242` | Circular 178/2022; CGST Sec 15 |
| Quote-spawned invoices under-charge cess to zero | `quotations.service.ts:19-28,277-283` | GST (Compensation to States) Act 2017 |
| Quotation preview hides IGST vs CGST/SGST split / POS | `quotations.service.ts:71-98` | CGST/IGST Act — tax head by POS |
| Round-off applied to grand total, not consolidated tax | `invoices.service.ts:387-392` | CGST Sec 170 |
| `cessRate` never derived from product; no per-unit/specific cess | `invoices.service.ts:330,355`; `schema.prisma:259-277` | Compensation Cess Act 2017 Sec 8 |

### 3.2 GST — engine/schema capability gaps
| Finding | File:line | Section/Rule |
|---|---|---|
| No HSN/SAC capture or mandatory-threshold enforcement | `invoices.service.ts:371`; `invoices.controller.ts:6-15` | Notification 78/2020-CT; Rule 46(g); (8-digit export per Notification 90/2020-CT) |
| Challan→invoice produces a tax invoice with no CGST/SGST/IGST split or POS | `challans.service.ts:235-285` | Rule 46 |
| No reverse-charge (RCM) support in schema or engine | `schema.prisma:802-951`; `invoices.service.ts:327-385` | CGST Sec 9(3)/9(4); IGST Sec 5(3)/5(4); Sec 31(3)(f); Rule 46(p) |
| No composition-scheme modeling/enforcement (composition dealer can issue tax invoice & charge GST) | `schema.prisma:1803-1882`; `invoices.service.ts:214` | CGST Sec 10; Rule 5(1)(f), Rule 49 |
| No exempt / nil-rated / zero-rated (export/SEZ, LUT) modeling | `schema.prisma:925-951`; `invoices.service.ts:327-385` | IGST Sec 16; CGST Sec 2(47); Rule 46/GSTR-1 supply-type |
| No e-invoice (IRN/QR) or e-way-bill threshold handling | `schema.prisma:802-884`; `invoice-pdf-renderer.ts:160-481` | Rule 48(4)/(5); Rule 138 |

### 3.3 GST — invoice format (Rule 46/49/50/53)
| Finding | File:line | Rule |
|---|---|---|
| No "whether tax payable on reverse charge" declaration | `invoice-pdf-renderer.ts:244-267` | Rule 46(p) |
| No supplier signature / authorised-signatory block (and "computer generated" without a DSC) | `invoice-pdf-renderer.ts:455-481` | Rule 46(q) + proviso |
| Bill of Supply still renders GST tax columns/totals; no composition declaration | `invoice-pdf-renderer.ts:270-427` | Rule 49; Rule 5(g); Sec 10(5) |
| Credit/Debit notes carry no reference to the original invoice | `schema.prisma:802-883`; `invoice-pdf-renderer.ts:244-267` | CGST Sec 34; Rule 53(1A) |
| No GST receipt voucher (or refund voucher) for advances | `sequences.ts:90-95` | Rule 50 (and Rule 51) |
| HSN optional, no turnover-based digit-count validation | `schema.prisma:933`; `invoice-pdf-renderer.ts:324,348` | Rule 46(g); Notification 78/2020-CT |
| No recipient-GSTIN / state-of-supply enforcement for B2B; POS can be unset | `invoices.service.ts:294-297`; `invoice-pdf-renderer.ts:249-252` | CGST Rule 46(d),(m); IGST Sec 10 (goods) — *note: recipient-GSTIN is Rule 46(d), not (e); 46(e) is the unregistered ≥₹50k case* |
| Estimate→invoice re-dates/re-numbers; **no serial breach** but no EST↔INV audit linkage | `invoices.service.ts:788-821` | Sec 31; Rule 46(b) (traceability gap, not a consecutiveness violation) |
| Quotation PDF computes taxable in float (display-only, latent) | `quotation-pdf-renderer.ts:75-77,233` | n/a |

### 3.4 TDS / TCS (Income-tax Act)
| Finding | File:line | Section |
|---|---|---|
| No Sec 194Q TDS on purchases despite per-vendor aggregation being available | `invoices.service.ts:387-392`; `reports.service.ts:190-210` | Sec 194Q; 206AA (no-PAN); CBDT Circular 13/2021 (GST-exclusion); ₹50L/seller, ₹10cr buyer-turnover gate |
| No TDS-receivable tracking when merchant is SELLER and buyer deducts 194Q | `reports.service.ts:296-312`; `payments.service.ts` | Sec 194Q r/w Sec 199 / Rule 37BA; reconciled via 26AS/AIS |
| Merchant has no turnover / 194Q-liability flag → applicability undeterminable | `schema.prisma:35-42` | Sec 194Q & 206C(1H) provisos (₹10cr gate); 206AA/206CC (no-PAN) |
| Sec 206C(1H) TCS absent — **correct** for FY2025-26 (omitted by FA2025) but undocumented and unguarded for backdated invoices | `invoices.service.ts:340-392` | Sec 206C(1H) (omitted w.e.f. 01-Apr-2025) |

### 3.5 Accounting integrity & reporting
| Finding | File:line | Standard |
|---|---|---|
| Reports "revenue" sums tax-, cess-, round-off-inclusive `invoice.total` | `reports.service.ts:41,51,75,95,113,119,126,131` | Ind AS 18 / AS 9; CGST Sec 15 |
| GST headline `outputTax` includes cess but by-rate `tax` excludes it (figures disagree) | `reports.service.ts:255-257,285` | Compensation Cess Act; GSTR-1 |
| GST taxable ignores header discount and re-derives instead of using stored tax columns; no IGST vs CGST/SGST split | `reports.service.ts:254-257,269-273` | GSTR-1 Tables 6/7; CGST Sec 15 |
| `netPayable` treats all input tax as fully creditable ITC (no Sec 17(5)/RCM/cess logic) | `reports.service.ts:286,294,300` | CGST Sec 16; Sec 17(5) |
| Dashboard `draftInvoices.count` not shop-scoped (cross-tenant) | `dashboard.service.ts:41,42-56` | tenant isolation |
| P&L vs sales-report use two different "revenue" definitions; writeoffs keyed to `created_at` while revenue+COGS use `invoice_date` | `reports.service.ts:320-348` | AS 1 / matching principle |
| `walletBalance` denorm trusted with no reconciliation vs `SUM(WalletEntry.amount)` | `wallet.service.ts:75-84,120-136,152-157` | data-integrity (not AS-1; reframe) |
| Forfeiture income has no credit leg — liability drops, no income row booked | `caution.service.ts:203-247` | IT Act Sec 28/41; Circular 178/2022 ¶7.1.5 & ¶11.3 |
| Party/vendor ledger omits caution deposits and mis-signs CREDIT_NOTE (added as positive debit) | `payments.service.ts:299-326,386-420` | ledger completeness |
| Caution/wallet financial rows hard-deletable/mutable; no immutable audit trail | `payments.service.ts:254-282` | CGST Sec 36 (72-month retention); Sec 35/Rule 56 |
| Over-allocation aggregate blind to payment type (RECEIPT vs PAYMENT) — latent | `payments.service.ts:159-164` | n/a |
| No persisted paid/partial state; no derived "due" on invoice list/detail | `invoices.service.ts:550-595,603-614` | n/a |
| Negative outstanding/due never clamped at zero (cosmetic error string only) | `payments.service.ts:164` | n/a |
| Balance formula subtracts FORFEIT but doc-comments omit it (doc/code divergence) | `caution.service.ts:27,40,59`; `schema.prisma:1419` | n/a |

---

## 4. Worked-Examples Ledger (code vs correct accounting)

Both scenarios use **merchant `nkumawat8956@gmail.com` (Rajasthan, 08)** selling to **customer `nkumawat1010@gmail.com`**.

### Example A — Customer-app order, intrastate, 18% taxable product (C1 + H4 compounding)
qty 10 × sellingPrice ₹100, product `taxPercent=18`, 20% coupon `WELCOME20`.

| Step | Correct accounting | Code produces |
|---|---|---|
| Taxable value | 1,000.00 − 400.00 coupon = **800.00** | 1,000.00 (coupon dropped) |
| GST (CGST 9% + SGST 9%) | 72.00 + 72.00 = **144.00** | **0.00** (`taxPercent` never passed) |
| Invoice total | **944.00** | **1,000.00** |
| Customer actually pays (wallet/payable) | 944.00 | 1,600.00 *(payable computed off ₹2,000-base example; here ₹800 → ₹800)* |
| **Discrepancy** | — | Invoice says 1,000.00, **GST ₹144 uncollected**, coupon ₹400 not on the legal document; cash won't reconcile |

> *Note:* even with no coupon, the bare order (qty 10 × ₹100 @18%) should bill **₹1,180** but the code bills **₹1,000** — ₹180 GST silently lost on every order (`agrees: false`).

### Example B — Caution forfeit of a cancelled SUPPLY, interstate (08→27), IGST 18%
Customer cancels a confirmed order; merchant forfeits the ₹11,800 advance with `gstTreatment='SUPPLY'`.

| Step | Correct accounting (Circular 178/2022 ¶11.3) | Code produces |
|---|---|---|
| Treatment | Retained ₹11,800 is GST-inclusive consideration | Stored verbatim, no rate, no flag |
| Taxable value | 11,800 / 1.18 = **10,000.00** | not computed |
| Output IGST | **1,800.00** owed to government | **0.00** — never computed, never posted |
| Income booked | 10,000.00 to a revenue ledger | no credit/income leg anywhere |
| **Result** | ₹1,800 output tax + ₹10,000 income recorded | ₹1,800 GST silently lost; income invisible to every report |

---

## 5. Prioritized Fix List

**P0 — Money-incorrect, ships on every transaction (do first):**
1. **C1 / Example A** — Pass `product.taxPercent` (+ `cessRate`, HSN) through `confirmRequest`→`createInvoice`; add `taxPercent` to the `productMap` select. (`purchase-requests.service.ts:1148-1155`, `invoices.service.ts:304,329`)
2. **H4** — Thread `couponDiscount` into `createInvoice` as a header (or pro-rated line) discount. (`purchase-requests.service.ts:583-594,1141-1155`)
3. **H1** — Pass explicit per-item `discount` on PR→invoice so the promo isn't double-applied. (`purchase-requests.service.ts:416-423`, `invoices.service.ts:331-339`)
4. **C4** — Add cumulative returned-qty cap. (`returns.service.ts:203,221-228`)
5. **C3** — Mount `/reports` with `resolveShop`; add `shop_id` to every report query. (`app.ts:345`, `reports.service.ts:30-367`)
6. **C2** — Net returns out of revenue/GST/COGS (credit-note + `RETURN_IN` stock + report join). (`returns.service.ts:406-525`, `reports.service.ts`)

**P1 — Invalid documents / negative tax / phantom ledger entries:**
7. **H2/H6** — Clamp explicit & quote item discounts to `< qty*unitPrice`; reject otherwise. (`invoices.service.ts:332-353`, `quotations.service.ts:76`)
8. **H3** — Reject/clamp `headerDiscount > taxable+tax`; route reductions via CREDIT_NOTE. (`invoices.service.ts:388-392`)
9. **H5** — Apportion header discount before tax (Sec 15(3)) or forbid post-tax header discount. (`invoices.service.ts:388-390`)
10. **H7** — Reject payments against non-CONFIRMED invoices; mirror in `caution.adjust`. (`payments.service.ts:140-170`)
11. **Place-of-supply / interstate** — Require a resolvable, validated POS for TAX_INVOICE; never default-guess CGST/SGST. (`invoices.service.ts:294-298`, `indian.ts:93-99`)
12. **Forfeit-SUPPLY GST + income leg** — Compute the split, persist it, book the income; reject SUPPLY forfeits lacking a rate. (`caution.service.ts:203-247`)

**P2 — Reporting correctness & reconciliation:**
13. Separate net turnover (`SUM(taxable_value)`) from "tax collected" and "gross collection"; stop labelling tax-inclusive total as revenue. (`reports.service.ts`)
14. Make GST headline `outputTax` and by-rate `tax` consistent; report cess separately; subtract header discount; sum stored igst/cgst/sgst columns; split by interstate. (`reports.service.ts:254-305`)
15. Round (`round2`) outstanding and all ledger running balances; return DB-derived balances. (`payments.service.ts:164,386-561`)
16. Add cess/HSN/quotation tax-head/quotation round-off parity (H8, M1). (`quotations.service.ts`)
17. Shop-scope dashboard draft count. (`dashboard.service.ts:41`)

**P3 — Statutory format & audit-trail (structural):**
18. Soft-void instead of hard-deleting payments/caution/wallet rows; append-only ledgers (72-month retention, Sec 36). (`payments.service.ts:254-282`, `wallet`, `caution`)
19. Add invoice-format fields: reverse-charge flag, authorised-signatory/DSC block, credit/debit-note→original-invoice linkage, receipt/refund voucher types, HSN required + digit-count validation. (`invoice-pdf-renderer.ts`, `schema.prisma`)
20. Branch the PDF renderer on `documentType` (Bill of Supply must drop tax columns + add composition declaration). (`invoice-pdf-renderer.ts:270-427`)
21. Add `registrationType` (REGULAR/COMPOSITION/UNREGISTERED) and supply-type enum (TAXABLE/EXEMPT/NIL/ZERO_RATED_LUT/ZERO_RATED_IGST); drive tax + document type from them. (`schema.prisma`, `invoices.service.ts`)
22. Route challan conversion through `invoicesService.createInvoice`. (`challans.service.ts:235-285`)
23. Add `priorFyTurnover`/`is194QLiable` to Shop; implement 194Q deduction + TDS-receivable tracking; document the 206C(1H) no-TCS decision and gate backdated SALE dates. (`schema.prisma:35-42`, `invoices.service.ts`, `payments.service.ts`)
24. Add wallet reconciliation (`walletBalance == SUM(WalletEntry.amount)`); fix CREDIT_NOTE sign and surface caution deposits in the party ledger. (`wallet.service.ts`, `payments.service.ts:299-326`)

**P4 — Hygiene:**
25. Single shared `round2`; integer-paise tax accumulation; paise-integer tolerance comparisons (strict `>`); persisted paid/partial/due on invoices; fix FORFEIT doc-comments. (multiple)