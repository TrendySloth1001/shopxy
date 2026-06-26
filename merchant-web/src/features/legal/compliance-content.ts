/**
 * Compliance documentation content — the Indian acts, rules and exact formulas
 * the ShopXY merchant & customer apps follow. Extracted from and verified
 * against the live codebase. Shared by the docs layout (sidebar nav) and the
 * per-topic pages so the two never drift.
 */

export type Formula = { label: string; expression: string; note: string };
export type Section = {
  id: string;
  heading: string;
  /** Short label for the sidebar. */
  nav: string;
  /** One-line summary for the overview index. */
  summary: string;
  lawRefs: string[];
  body: string[];
  keyPoints: string[];
  formulas: Formula[];
};

export const INTRO =
  "ShopXY is an Indian commerce platform with a merchant app, a customer app, and a shared backend. These pages set out, in plain language, the laws ShopXY follows and the exact formulas it uses for tax, refunds, settlements and disclosures. They are provided for information only: the descriptions reflect how the platform is built today, and the formulas are reproduced exactly as the system applies them so that merchants and customers can understand every figure on an invoice or refund.";

export const SECTIONS: Section[] = [
  {
    id: "data-protection-dpdp",
    heading: "Data protection and privacy (DPDP)",
    nav: "Data protection",
    summary: "Consent, your rights, retention windows and breach handling under the DPDP Act 2023.",
    lawRefs: [
      "DPDP Act 2023 §5 (notice)",
      "DPDP §6 (consent & breach notice)",
      "DPDP §8 (security, minimisation, children's data)",
      "DPDP §9 (withdrawal)",
      "DPDP §11 (right to access)",
      "DPDP §12 (erasure)",
      "DPDP §13/§15 (grievance officer)",
      "DPDP §4 (cross-border transfer)",
      "IT Rules 2021",
      "Companies Act §128",
      "GST Rules §36",
    ],
    body: [
      "When you register, ShopXY records your explicit consent to both the Terms of Service and the Privacy Policy. Both consents must be given before an account is created, and the exact moment of consent is timestamped. This consent gate is enforced on the server, so it cannot be bypassed by altering the app on your device.",
      "You can ask to see the personal data ShopXY holds about you. The data export covers your profile, addresses, reviews, wishlist, cart, orders, return requests, notifications, invitations and purchase requests; shop owners additionally receive a full export of their shop's data, scoped to that shop. Your password is never included in any export.",
      "You can ask for your account to be deleted. For customers, deletion removes reviews, addresses, wishlist, cart, notifications and login tokens, and product ratings are recomputed in the same operation. For shop owners who still hold confirmed invoices within the statutory retention window, the law requires those tax records to be kept; in that case the account is anonymised (identifying fields cleared and login disabled) rather than fully erased, so the books of account remain intact.",
      "ShopXY practises data minimisation. A customer's login email is not disclosed to a merchant when the customer links to a shop; only the name and the contact email the merchant already entered are shared. A merchant's internal user identifier is never exposed to linked customers.",
      "You may withdraw consent at any time through granular notification preferences (orders, deals, account, messages, push and SMS), and ShopXY honours the withdrawal by not sending further communications of that type.",
      "Personal data is primarily stored and processed on infrastructure located in India. Limited cross-border transfers occur only for specific processing purposes such as payment handling, only to countries not restricted by the Government of India, and under contractual safeguards. Data is protected with encryption in transit, access controls and least-privilege handling; payment details are forwarded to the payment provider and are not stored by ShopXY. In the event of a personal-data breach, ShopXY will notify the Data Protection Board of India and affected users without undue delay, within the timelines prescribed under the DPDP Act.",
    ],
    keyPoints: [
      "Both Terms and Privacy consent are mandatory at registration, enforced server-side with a recorded consent timestamp.",
      "You can export all your personal data; your password hash is always stripped from the export.",
      "Customers can delete their accounts permanently; owners with retained tax invoices are anonymised instead of erased, to meet the 8-year books-of-account retention.",
      "Confirmed invoices, orders and payment records are retained for 8 years (Companies Act §128 / GST Rules §36); account profile and non-retained personal data are deleted or anonymised within 90 days of account closure.",
      "ShopXY is intended for users aged 18 and over and does not knowingly process children's data without verifiable parental consent.",
      "A customer's login email is never disclosed to merchants on linking.",
    ],
    formulas: [
      {
        label: "Consent gate at registration",
        expression: "acceptedTerms === true AND acceptedPrivacy === true; acceptedAt = now()",
        note: "Both consents are required as a literal true at the API layer; the consent time is stamped at registration.",
      },
      {
        label: "Tax-record retention cutoff (deletion eligibility)",
        expression: "cutoff = today − 8 years; protected = CONFIRMED invoices where invoiceDate ≥ cutoff",
        note: "If an owner has any protected invoices, the account is anonymised rather than hard-deleted.",
      },
      {
        label: "Erasure decision",
        expression:
          "CUSTOMER → cascade-delete personal data + recompute product ratings; OWNER with protected invoices → pseudonymise (clear name/email/phone/avatar, disable login)",
        note: "Requires current-password verification before any deletion proceeds.",
      },
    ],
  },
  {
    id: "it-act-intermediary",
    heading: "IT Act, intermediary status and published policies",
    nav: "IT Act & intermediary",
    summary: "Marketplace status, the policies we publish, acceptable use and the Grievance Officer.",
    lawRefs: [
      "IT (Intermediary Guidelines & Digital Media Ethics Code) Rules 2021, Rule 3(1)(b)",
      "IT Rules 2021, Rule 3(1)(f)",
      "IT Rules 2021, Rule 3(2) (grievance officer)",
      "Consumer Protection (E-Commerce) Rules 2020, r.4(5)/r.5(3)",
      "DPDP Act 2023 §5/§13",
    ],
    body: [
      "ShopXY operates as a neutral marketplace intermediary, not as a principal seller. Orders are accepted and fulfilled by individual shops; each shop is responsible for its own pricing, availability, product descriptions and fulfilment.",
      "The platform publishes its Terms of Service, Privacy Policy and consumer policies (returns, refunds, cancellation and shipping) in a clear and accessible manner. These are reachable before login: the customer storefront links Privacy, Terms and Consumer Policies in its public footer, and the merchant login screen links Terms and Privacy. This satisfies the requirement that policies be available at or before the point data is collected.",
      "An Acceptable Use Policy prohibits using ShopXY for unlawful goods, for infringing the rights of others, or for disrupting the service. Customers are additionally told not to misuse the order, cancel, return, payment or messaging systems or attempt to defraud a shop; merchants are reminded they are responsible for the legality of their listings, invoices and tax handling.",
      "A Grievance Officer is published as the contact point for service complaints and data-related grievances, with committed service levels. The officer's name, designation, phone and postal address are pending appointment and are currently shown as placeholders awaiting completion.",
    ],
    keyPoints: [
      "ShopXY is a marketplace; orders are accepted and fulfilled by individual shops, not by the platform.",
      "Terms, Privacy and consumer policies are published and reachable before login.",
      "A Grievance Officer is the published contact for complaints; officer name/phone/postal address are still to be filled in.",
      "Grievance service levels: acknowledge within 48 hours; resolve consumer/service grievances within one month; resolve DPDP data grievances within 15 days.",
    ],
    formulas: [
      {
        label: "Grievance service-level commitments",
        expression:
          "acknowledge ≤ 48 hours; resolve consumer/service grievance ≤ 1 month; resolve DPDP data grievance ≤ 15 days",
        note: "Contact is grievance@shopxy.app; officer name, designation, phone and postal address are pending appointment.",
      },
      {
        label: "Pre-login policy discoverability",
        expression: "customer footer → Privacy + Terms + Consumer Policies; merchant login → Terms + Privacy",
        note: "Policies are accessible at or before the point of data collection.",
      },
    ],
  },
  {
    id: "gst-tax",
    heading: "GST and tax, with formulas",
    nav: "GST & tax",
    summary: "How CGST/SGST/IGST, cess, rounding, TCS/TDS and invoice numbering are computed.",
    lawRefs: [
      "CGST Act 2017 §10 / §15 / §32 / §34 / §52 / §170",
      "IGST Act 2017 §5 / §7 / §8 / §10 / §12",
      "GST (Compensation to States) Act 2017 §8",
      "CGST Rules 2017, Rule 46 / 49 / 53(1A)",
      "SGST Act (State legislation)",
      "Income Tax Act 1961 §194-O",
      "Legal Metrology (Packaged Commodities) Rules 2011",
      "Notification 78/2020-CT",
    ],
    body: [
      "GST is calculated line by line using exact decimal arithmetic (not floating-point), so figures never drift at the paisa level. Each amount is rounded to two decimal places using round-half-up only at the points where the law fixes a printed figure: the line discount, the taxable value and each tax component.",
      "The taxable value of a line is the quantity times the unit price, less any discount, and the discount is clamped so the taxable value can never go negative. Where the price is marked GST-inclusive (the MRP convention used on the customer storefront), the tax is backed out of the price rather than added on top, so the invoice total equals the amount actually collected.",
      "A discount recorded on the invoice header reduces the value of supply, so it is apportioned across lines before tax is computed; the last line absorbs any rounding remainder so the shares re-sum exactly. Whether the supply is interstate or intrastate is decided by comparing the shop's state code with the place of supply. Interstate supplies carry IGST; intrastate supplies carry CGST and SGST split equally, computed from a single GST total so the two halves always re-sum without drift. Compensation cess, where applicable, is charged on the taxable value at the notified cess rate. The grand total is rounded to the nearest whole rupee and the adjustment is shown as a separate round-off line.",
      "Only a regular GST-registered shop holding a GSTIN may charge output tax and issue a tax invoice. Composition dealers and unregistered shops cannot charge GST; their sale documents are automatically issued as Bills of Supply with zero tax. Each invoice carries a unique, consecutive serial number per shop per financial year, where the Indian financial year runs from 1 April to 31 March.",
      "When a customer returns goods, a sequentially-numbered credit note is issued that references the original invoice and reverses the output tax on the same side (IGST, or CGST plus SGST) as the original sale, using the original invoice's frozen interstate flag so a later change of the shop's state cannot flip an old reversal.",
      "Because ShopXY collects payment on behalf of sellers, it acts as an e-commerce operator: it collects GST TCS at 1% of net taxable value and deducts income-tax TDS at 1% of the gross supply value, withholding these from the seller's settlement.",
    ],
    keyPoints: [
      "All money math uses exact decimal arithmetic and round-half-up to two decimals only where the law fixes a printed figure.",
      "Interstate supply (place of supply differs from shop state) is taxed as IGST; intrastate supply is taxed as CGST + SGST split equally.",
      "Customer storefront prices are GST-inclusive (MRP); tax is backed out of the price, not added on top.",
      "Header/coupon discounts reduce the taxable value before GST is computed (CGST §15(3)).",
      "Only a REGULAR shop with a GSTIN may charge output GST; COMPOSITION and UNREGISTERED shops issue Bills of Supply with zero tax.",
      "Returns generate a numbered credit note that references the original invoice and reverses tax on the same side as the original sale.",
      "As an e-commerce operator, ShopXY collects 1% GST TCS (net taxable) and deducts 1% income-tax TDS (gross) from seller settlements.",
    ],
    formulas: [
      {
        label: "Taxable value (GST-exclusive)",
        expression:
          "lineAmount = quantity × unitPrice; lineDiscountTotal = min(discount, lineAmount); taxableValue = lineAmount − lineDiscountTotal (≥ 0)",
        note: "Discount is clamped to the line gross so taxable value can never be negative.",
      },
      {
        label: "Taxable value (GST-inclusive / MRP path)",
        expression: "taxableValue = lineAmount × 100 / (100 + taxPercent + cessRate); tax = lineAmount − taxableValue",
        note: "Used when the price is marked tax-inclusive; the divisor embeds both GST and cess.",
      },
      {
        label: "Header / coupon discount apportionment (CGST §15(3))",
        expression:
          "headerShare[i] = (i is last) ? (headerDiscount − Σ prior shares) : ROUND_HALF_UP(headerDiscount × lineBase[i] / baseTaxableTotal)",
        note: "Apportioned across lines before tax; the last line absorbs rounding drift.",
      },
      {
        label: "Interstate determination",
        expression: "isInterstate = (shopStateCode ≠ placeOfSupplyStateCode)",
        note: "Shop state code derives from registration, falling back to the first two digits of the GSTIN; unknown sides default to intrastate (safer than mis-charging IGST).",
      },
      {
        label: "IGST (interstate)",
        expression: "igstAmount = ROUND_HALF_UP(taxableValue × taxPercent / 100)",
        note: "Charged when the place of supply is outside the shop's state.",
      },
      {
        label: "CGST and SGST (intrastate)",
        expression:
          "gstTotal = ROUND_HALF_UP(taxableValue × taxPercent / 100); cgst = ROUND_HALF_UP(gstTotal / 2); sgst = gstTotal − cgst",
        note: "Total computed first, then split, so CGST + SGST always re-sum to the GST total.",
      },
      {
        label: "Compensation cess",
        expression: "cessAmount = ROUND_HALF_UP(taxableValue × cessRate / 100)",
        note: "Zero for most goods; ad-valorem for specified luxury/demerit goods.",
      },
      {
        label: "Grand total rounding (CGST §170)",
        expression:
          "grandTotalRaw = taxableValueTotal + igst + cgst + sgst + cess; total = ROUND_HALF_UP(grandTotalRaw, 0); roundOff = total − grandTotalRaw",
        note: "Rounded to the nearest whole rupee; the round-off is recorded as a separate line.",
      },
      {
        label: "Registration gate and document downgrade",
        expression:
          "isShopRegistered = (registrationType = REGULAR) AND (GSTIN present); if SALE AND not registered AND TAX_INVOICE → downgrade to BILL_OF_SUPPLY (all tax = 0)",
        note: "COMPOSITION and UNREGISTERED shops cannot charge output GST.",
      },
      {
        label: "Invoice serial numbering (Rule 46(b))",
        expression: "invoiceNo = prefix / FY / LPAD(sequence, 5, '0')  e.g. CRN/25-26/00042",
        note: "Prefixes: INV (sale), PUR (purchase), CRN (credit note), DBN (debit note), EST (estimate).",
      },
      {
        label: "Financial year",
        expression: "if month ≥ April: FY = YY(year)-YY(year+1); else FY = YY(year−1)-YY(year)",
        note: "India's financial year runs 1 April to 31 March; numbering resets at the FY boundary.",
      },
      {
        label: "Permitted GST rate slabs",
        expression: "taxPercent ∈ {0, 0.1, 0.25, 1, 1.5, 3, 5, 12, 18, 28}",
        note: "A merchant may mark a line exempt/nil, but only a notified slab is accepted.",
      },
      {
        label: "GSTIN / HSN format",
        expression: "GSTIN: 2-digit state + 10-char PAN + entity + Z + checksum (e.g. 27ABCDE1234F1Z5); HSN: 4, 6 or 8 digits",
        note: "HSN for goods or SAC for services is mandatory on tax invoices; 8-digit HSN is required for exports.",
      },
      {
        label: "Recipient details requirement (Rule 46(e)/(f))",
        expression: "needsRecipientDetails = (customer GSTIN present) OR (total ≥ ₹50,000)",
        note: "When required, recipient name and address are mandatory on the tax invoice.",
      },
      {
        label: "Operator GST TCS (CGST §52)",
        expression:
          "gstTcsTotal = ROUND_HALF_UP(netTaxable × 1 / 100); interstate → IGST-TCS = total; else CGST-TCS = ROUND_HALF_UP(total/2), SGST-TCS = total − CGST-TCS",
        note: "Collected on the net taxable value of the seller's supply.",
      },
      {
        label: "Operator income-tax TDS (§194-O)",
        expression: "incomeTaxTds = ROUND_HALF_UP(grossAmount × 1 / 100)",
        note: "Deducted on the gross supply value (invoice total) from the seller's settlement.",
      },
    ],
  },
  {
    id: "payments-rbi",
    heading: "Payments, refunds and settlement (RBI)",
    nav: "Payments & RBI",
    summary: "Refund-to-source, the disabled PPI wallet, idempotency, held transfers and webhook security.",
    lawRefs: [
      "RBI Master Direction — Payment & Settlement Systems (PSS) Act 2007",
      "RBI PPI (Prepaid Payment Instrument) Master Direction",
      "Consumer Protection (E-Commerce) Rules 2020, Rule 4(7)",
      "RBI KYC / linked-account directions",
      "DPDP Act 2023",
    ],
    body: [
      "Refunds for online payments are always reversed to the customer's original payment instrument (card, UPI or netbanking). They are never converted to wallet or store credit. The in-app wallet has been deprecated: loading real money into a spendable wallet would require RBI authorisation as a prepaid payment instrument, so wallet top-up is disabled and that endpoint returns a permanent error.",
      "Refunds are idempotent and crash-safe. Every refund attempt is persisted with its provider reference and status, and a replay using the same idempotency key returns the prior refund rather than refunding twice. The refundable amount is capped at the captured amount less anything already refunded. A reconciliation sweep automatically re-drives refunds that are still pending or have failed, so a refund is never silently dropped.",
      "Marketplace settlements use a held-transfer model on Razorpay Route. A seller's portion is created as an on-hold transfer held in the provider's regulated balance, never in a ShopXY-controlled account. Transfers carry a deterministic key so retries cannot double-pay; before creating a transfer the system lists existing transfers and reconciles instead of creating a duplicate. When the buyer confirms delivery, the held transfer is released to settle to the seller; when a return is refunded, the seller's held slice is clawed back, and if the refund exceeds the recoverable slice the gap is flagged for manual recovery while the customer refund always proceeds.",
      "Sellers can only receive payouts after their linked account passes KYC. A seller's bank details, PAN and GST flow directly to the payment provider during onboarding and are never stored by ShopXY; only the provider's account identifier is kept. Until a linked account is activated, the seller's transfers are recorded as KYC-gated and no money moves; account activation re-triggers reconciliation to release them.",
      "Provider communications are authenticated. Webhooks are verified with an HMAC-SHA256 signature and fail closed if the signature is invalid or the secret is missing in production. Each event is processed exactly once via a unique event identifier, and an ownership check ensures one tenant's webhook can never settle another tenant's payment. On a payment-captured event the captured amount must equal the order intent amount, or the event is rejected, preventing amount tampering and partial payments settling as fully paid.",
    ],
    keyPoints: [
      "Online refunds always go back to the original payment instrument; wallet/store-credit refunds are not used.",
      "Wallet top-up is disabled — loading spendable money would require an RBI PPI licence (PSS Act 2007).",
      "Refunds are idempotent: a refund is capped at captured-minus-already-refunded and replays never double-refund.",
      "Seller funds are held on-hold in the provider's regulated balance, released on buyer confirmation and clawed back on returns.",
      "Seller PAN and bank details flow directly to the payment provider and are never stored by ShopXY.",
      "Webhooks are verified by HMAC-SHA256 and fail closed; events are processed exactly once with a tenant ownership check.",
      "Payouts are gated behind KYC activation of the seller's linked account.",
    ],
    formulas: [
      {
        label: "Refundable amount cap",
        expression: "refundable = amountCaptured − amountAlreadyRefunded; refund = min(requested, refundable)",
        note: "Refund can never exceed what remains unrefunded on the original capture.",
      },
      {
        label: "Wallet top-up status",
        expression: "POST /me/wallet/topup → 410 Gone",
        note: "Disabled because a spendable in-app wallet requires an RBI PPI authorisation.",
      },
      {
        label: "KYC payouts mapping",
        expression:
          "activated | funds_released | created → payoutsEnabled = true; under_review | needs_clarification | suspended | funds_held → payoutsEnabled = false",
        note: "Re-derived on every status read (never cached as activated).",
      },
      {
        label: "Held transfer key and hold window",
        expression: "transferKey = 'gw:{paymentId}:pr:{requestId}'; on_hold = true; on_hold_until = now + returnWindowDays (or null if indefinite)",
        note: "Deterministic key prevents double-pays; the hold auto-releases after the return window.",
      },
      {
        label: "Return reversal and shortfall",
        expression: "remaining = transfer.amount − reversedAmount; reverse = min(requested, remaining); shortfall = max(requested − remaining, 0)",
        note: "Any shortfall is flagged for manual recovery; the customer refund always proceeds.",
      },
      {
        label: "Webhook signature (fail-closed)",
        expression: "expected = HMAC-SHA256(webhookSecret, rawBody); accept only if timingSafeEqual(expected, signature)",
        note: "Rejected with 400 if the secret is empty in production or the signature does not match.",
      },
      {
        label: "Amount verification on capture",
        expression: "captured_paise = amountPaid; reject if captured_paise ≠ intent.amount_paise",
        note: "Prevents amount tampering and partial-payment orders settling as fully paid.",
      },
    ],
  },
  {
    id: "consumer-protection",
    heading: "Consumer protection: returns, refunds, cancellations and pricing",
    nav: "Consumer protection",
    summary: "Return windows, cancellation gates, credit-note refunds and transparent MRP pricing.",
    lawRefs: [
      "Consumer Protection (E-Commerce) Rules 2020, r.3 / r.4 / r.5",
      "Consumer Protection Act 2019, s.2(28)/s.2(47)",
      "CCPA Guidelines for Prevention of Dark Patterns 2023",
      "CGST Act 2017 §15 / §34",
      "CGST Rules 2017, Rule 53",
      "Legal Metrology Act s.18/s.36",
      "Legal Metrology (Packaged Commodities) Rules 2011, r.6 / r.10",
    ],
    body: [
      "Each shop publishes its return, refund, cancellation and shipping policy, and these terms are shown to the customer before purchase and on order detail pages. Returns are only permitted after goods are marked delivered, and the return window is counted from the delivery date. The default window is 7 days, configurable by the merchant; a setting of zero means an unlimited return period.",
      "Cancellation is governed by each shop's cancellation policy, which can allow cancellation up to confirmation, packing, shipping (the default) or delivery. After the relevant milestone, cancellation is no longer available and the customer's remedy is the post-delivery returns flow.",
      "When a return is approved, a GST credit note is issued that links to the original invoice and reverses CGST, SGST or IGST in proportion to the quantity returned and the original place of supply; the goods are restocked. The refund equals the credit note's tax-inclusive total, and is computed from what the buyer actually paid (gross less coupon discount), prorated to the returned share and capped at the credit note total. Refunds for online payments are reversed to the original payment instrument and are idempotent and reconciled, so they are never silently dropped.",
      "Pricing is transparent. A product's selling price can never exceed its Maximum Retail Price, enforced at create, update and publish. Storefront prices are shown GST-inclusive and labelled 'inclusive of all taxes'; MRP is always displayed, with a struck-through price and discount percentage when on offer. Seller-funded coupon discounts reduce the taxable value before GST is applied. Country of origin is shown on the product page when present, and assurance copy is qualified to each shop's actual policy rather than presented as unbacked blanket claims, in line with the guidance against misleading practices and dark patterns.",
    ],
    keyPoints: [
      "Returns are allowed only after delivery; the window is counted from the delivery date and defaults to 7 days (0 = unlimited).",
      "Cancellation is allowed only up to the shop's chosen milestone (default: until shipped); after that, only returns apply.",
      "Every approved return mints a GST credit note linked to the original invoice and reverses tax by the original place of supply.",
      "Refunds equal the tax-inclusive credit-note total, based on what the buyer actually paid, prorated and capped; online refunds go to source.",
      "Selling price can never exceed MRP, enforced at create, update and publish.",
      "Storefront prices are GST-inclusive and labelled 'inclusive of all taxes'; MRP is always shown.",
      "Marketing assurances are qualified to each shop's actual policy, not generic unbacked claims (anti dark-pattern).",
    ],
    formulas: [
      {
        label: "Return eligibility window",
        expression: "ageDays = (now − deliveredAt) / 86,400,000; eligible if ageDays ≤ windowDays (or windowDays = 0 for unlimited)",
        note: "The window starts at the delivered event, and a return after it is rejected as WINDOW_EXPIRED. Default windowDays = 7.",
      },
      {
        label: "Cancellation gate",
        expression: "isCancellableByPolicy(policy, events) = false if any recorded event type is in CANCEL_BLOCKERS[policy]",
        note: "Policies: UNTIL_CONFIRMED, UNTIL_PACKED, UNTIL_SHIPPED (default), UNTIL_DELIVERED.",
      },
      {
        label: "Refund amount on return",
        expression: "buyerOutlay = gross − coupon; refund = min(buyerOutlay × returnFraction, creditNoteTotal)",
        note: "Refund is based on what the buyer actually paid, prorated to the returned share and capped at the credit-note total.",
      },
      {
        label: "Credit-note GST reversal",
        expression: "creditNoteGST = (originalInvoiceGST × returnedQty) / originalQty, on the original place of supply (IGST vs CGST+SGST)",
        note: "A CONFIRMED CREDIT_NOTE is minted, linked to the original invoice; goods are restocked.",
      },
      {
        label: "Selling price ceiling (Legal Metrology)",
        expression: "sellingPrice ≤ MRP",
        note: "Enforced at product create, variant, update and publish.",
      },
      {
        label: "Refund idempotency key",
        expression: "idempotencyKey = `return-refund-${id}`",
        note: "Replays return the prior refund; failed refunds are re-driven by the reconciliation scheduler.",
      },
    ],
  },
  {
    id: "customer-side",
    heading: "Customer-side disclosures and ledgers",
    nav: "Customer side",
    summary: "What the customer sees at checkout, place-of-supply and read-only shop ledgers.",
    lawRefs: [
      "Consumer Protection (E-Commerce) Rules 2020, r.3(2) / r.4(3) / r.5(3) / r.6(5)",
      "CGST Act 2017 §15 / §34",
      "CGST Rules 2017, Rule 46 / Rule 53",
      "IGST Act 2017 §10 / §16",
      "Legal Metrology (Packaged Commodities) Rules 2011, r.6 / r.10",
      "DPDP Act 2023 §5 / §8 / §9 / §16",
      "IT Intermediary Rules 2021, r.3(1)(b)/r.3(2)",
    ],
    body: [
      "Before payment, the customer sees a complete price breakup. When tax applies, the checkout shows the taxable value and per-rate GST, labelled '(incl.)', with a note that prices are inclusive of all taxes. Because storefront prices follow the MRP (GST-inclusive) convention, the invoice engine backs the tax out of each line so the tax-invoice total equals the amount collected.",
      "Place of supply for a customer order is the destination, derived from the shipping address state. If the destination state differs from the shop's state the order is taxed as IGST; if it is the same state it is taxed as CGST plus SGST. This is the same engine used across the platform, so the customer's invoice matches the merchant's books.",
      "Product pages disclose the information required before purchase: MRP is always shown and labelled 'inclusive of all taxes', and a compliance block shows country of origin (when present), net quantity and the marketed-by / brand details. Some packaged-commodity fields such as HSN on the product page and full manufacturer/packer/importer details remain deferred and are not yet shown on the product page.",
      "A single order line can only be returned for the quantity originally purchased, summed across all return requests for that line, so refunds cannot exceed the purchase. The customer app's per-shop invoice ledgers are read-only views of the backend invoices and payments, scoped to the shop and the customer, so every GST, tax, credit-note and refund rule described above applies equally to what the customer sees.",
      "The customer storefront publishes the privacy policy, terms and the consumer policy page (cancellation, returns, refunds and shipping), all linked from the public footer. The privacy notice states concrete retention periods, a breach-notification commitment, a children's-data clause, the cross-border transfer posture and the processor list, with the cloud hosting provider name still to be filled in.",
    ],
    keyPoints: [
      "Checkout shows taxable value and per-rate GST with an 'inclusive of all taxes' note before payment.",
      "Customer-order place of supply is the shipping-address state; different state → IGST, same state → CGST + SGST.",
      "MRP is always shown on the product page and labelled 'inclusive of all taxes'.",
      "A line's cumulative returned quantity can never exceed the quantity originally purchased.",
      "Customer shop ledgers are read-only views of the same backend invoices and payments — all tax and refund rules apply identically.",
      "Customer legal pages (privacy, terms, policies) are published and linked from the public footer.",
      "HSN on the product page and full manufacturer/packer/importer details are deferred and not yet shown.",
    ],
    formulas: [
      {
        label: "Customer-order taxable value (inclusive)",
        expression: "taxableValue = inclusivePrice × 100 / (100 + taxPercent); tax = inclusivePrice − taxableValue",
        note: "confirmRequest passes isPriceInclusive = true so the engine backs tax out of each line.",
      },
      {
        label: "Place of supply for a customer order",
        expression: "placeOfSupplyStateCode = stateCode(shippingAddress.state); if ≠ shopStateCode → IGST, else → CGST + SGST",
        note: "Drives the same interstate split used across the platform.",
      },
      {
        label: "Cumulative return cap per line",
        expression: "Σ(returnedQty across all return requests for the line) ≤ originalPurchasedQty",
        note: "requested + alreadyReturned must not exceed the original quantity.",
      },
    ],
  },
];

export function getSection(id: string): Section | undefined {
  return SECTIONS.find((s) => s.id === id);
}
