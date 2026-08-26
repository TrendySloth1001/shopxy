export type Formula = {
  labelKey: string;
  expressionKey: string;
  noteKey: string;
};
export type Section = {
  id: string;
  key: string;
  bodyCount: number;
  keyPointCount: number;
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
