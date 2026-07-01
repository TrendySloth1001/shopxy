/**
 * Compliance documentation content — the Indian acts, rules and exact formulas
 * the ShopXY merchant & customer apps follow. Extracted from and verified
 * against the live codebase. Shared by the docs layout (sidebar nav) and the
 * per-topic pages so the two never drift.
 *
 * User-facing strings live in the message catalog under `legal.compliance.*`;
 * this module carries only the stable structure (ids, translation keys and the
 * count of each repeated block) so the render components can resolve labels via
 * `t()` at the point of use.
 */

export type Formula = {
  /** Translation key for the formula label. */
  labelKey: string;
  /** Translation key for the (mostly symbolic) expression. */
  expressionKey: string;
  /** Translation key for the explanatory note. */
  noteKey: string;
};
export type Section = {
  id: string;
  /** camelCase key of this section's subtree in the catalog (`legal.compliance.<key>`). */
  key: string;
  /** Number of body paragraphs (keys are `<key>.body.0`, `.1`, …). */
  bodyCount: number;
  /** Number of key points (keys are `<key>.keyPoints.0`, `.1`, …). */
  keyPointCount: number;
  /** Number of law references (keys are `<key>.lawRefs.0`, `.1`, …). */
  lawRefCount: number;
  formulas: Formula[];
};

const K = "compliance";

function section(
  id: string,
  key: string,
  counts: { body: number; keyPoints: number; lawRefs: number },
  formulaKeys: string[],
): Section {
  return {
    id,
    key,
    bodyCount: counts.body,
    keyPointCount: counts.keyPoints,
    lawRefCount: counts.lawRefs,
    formulas: formulaKeys.map((fk) => ({
      labelKey: `${K}.${key}.formulas.${fk}.label`,
      expressionKey: `${K}.${key}.formulas.${fk}.expression`,
      noteKey: `${K}.${key}.formulas.${fk}.note`,
    })),
  };
}

export const SECTIONS: Section[] = [
  section(
    "data-protection-dpdp",
    "dataProtection",
    { body: 6, keyPoints: 6, lawRefs: 11 },
    ["consentGate", "retentionCutoff", "erasure"],
  ),
  section(
    "it-act-intermediary",
    "itAct",
    { body: 4, keyPoints: 4, lawRefs: 5 },
    ["grievanceSla", "policyDiscoverability"],
  ),
  section(
    "gst-tax",
    "gst",
    { body: 6, keyPoints: 7, lawRefs: 8 },
    [
      "taxableExclusive",
      "taxableInclusive",
      "headerDiscount",
      "interstate",
      "igst",
      "cgstSgst",
      "cess",
      "grandTotal",
      "registrationGate",
      "serialNumbering",
      "financialYear",
      "rateSlabs",
      "gstinHsn",
      "recipientDetails",
      "operatorTcs",
      "operatorTds",
    ],
  ),
  section(
    "payments-rbi",
    "payments",
    { body: 5, keyPoints: 7, lawRefs: 5 },
    [
      "refundableCap",
      "walletTopup",
      "kycMapping",
      "heldTransfer",
      "returnReversal",
      "webhookSignature",
      "amountVerification",
    ],
  ),
  section(
    "consumer-protection",
    "consumer",
    { body: 4, keyPoints: 7, lawRefs: 7 },
    [
      "returnWindow",
      "cancellationGate",
      "refundAmount",
      "creditNoteReversal",
      "sellingCeiling",
      "refundIdempotency",
    ],
  ),
  section(
    "customer-side",
    "customerSide",
    { body: 5, keyPoints: 7, lawRefs: 7 },
    ["customerTaxable", "customerPlaceOfSupply", "returnCap"],
  ),
];

export function getSection(id: string): Section | undefined {
  return SECTIONS.find((s) => s.id === id);
}
