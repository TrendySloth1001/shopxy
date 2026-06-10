import {
  cautionHistorySchema,
  cautionRequestListSchema,
  cautionResultSchema,
  type CautionMode,
  type CautionRequest,
  type CautionTxn,
  type GstTreatment,
} from "./schema";

async function jsonOrThrow<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

async function post<T>(url: string, body: unknown, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body ?? {}),
  });
  return jsonOrThrow(res, parse, fallback);
}

export type CautionHistory = { balance: number; data: CautionTxn[]; total: number };

export function getCautionHistory(partyId: number): Promise<CautionHistory> {
  return fetch(`/api/parties/${partyId}/caution`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => cautionHistorySchema.parse(raw), "Could not load caution history."),
  );
}

export type CautionRecordInput = {
  amount: number;
  mode: CautionMode;
  modeReference?: string | null;
  note?: string | null;
};

export function depositCaution(partyId: number, input: CautionRecordInput): Promise<number> {
  return post(
    `/api/parties/${partyId}/caution/deposit`,
    input,
    (raw) => cautionResultSchema.parse(raw).balance,
    "Could not record the deposit.",
  );
}

export function refundCaution(partyId: number, input: CautionRecordInput): Promise<number> {
  return post(
    `/api/parties/${partyId}/caution/refund`,
    input,
    (raw) => cautionResultSchema.parse(raw).balance,
    "Could not record the refund.",
  );
}

export function adjustCaution(
  partyId: number,
  input: { invoiceId: number; amount: number; note?: string | null },
): Promise<number> {
  return post(
    `/api/parties/${partyId}/caution/adjust`,
    input,
    (raw) => cautionResultSchema.parse(raw).balance,
    "Could not set off the deposit.",
  );
}

export function forfeitCaution(
  partyId: number,
  input: {
    amount: number;
    gstTreatment: GstTreatment;
    /** Goods GST rate — required by the backend when gstTreatment is SUPPLY. */
    taxRate?: number | null;
    note?: string | null;
  },
): Promise<number> {
  return post(
    `/api/parties/${partyId}/caution/forfeit`,
    input,
    (raw) => cautionResultSchema.parse(raw).balance,
    "Could not forfeit the deposit.",
  );
}

/** Shop-wide pending inbox (defaults to PENDING server-side). */
export function listShopCautionRequests(): Promise<CautionRequest[]> {
  return fetch(`/api/caution-requests`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => cautionRequestListSchema.parse(raw).data, "Could not load caution requests."),
  );
}

export function approveCautionRequest(partyId: number, requestId: number): Promise<void> {
  return post(
    `/api/parties/${partyId}/caution-requests/${requestId}/approve`,
    {},
    () => undefined,
    "Could not approve the request.",
  );
}

export function rejectCautionRequest(
  partyId: number,
  requestId: number,
  reviewNote?: string | null,
): Promise<void> {
  return post(
    `/api/parties/${partyId}/caution-requests/${requestId}/reject`,
    { reviewNote: reviewNote ?? null },
    () => undefined,
    "Could not decline the request.",
  );
}
