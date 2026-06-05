import type { PartyOverview } from "./schema";

/** Net billed = total SALE − total SALES_RETURN. */
export function netBilled(o: PartyOverview): number {
  const sales = o.totals.filter((t) => t.type === "SALE").reduce((s, t) => s + t.total, 0);
  const returns = o.totals.filter((t) => t.type === "SALES_RETURN").reduce((s, t) => s + t.total, 0);
  return sales - returns;
}

export function totalSales(o: PartyOverview): number {
  return o.totals.filter((t) => t.type === "SALE").reduce((s, t) => s + t.total, 0);
}

export function totalReturns(o: PartyOverview): number {
  return o.totals.filter((t) => t.type === "SALES_RETURN").reduce((s, t) => s + t.total, 0);
}

/**
 * Balance semantics for a party (receivable). Positive = the party owes the
 * shop; negative = an advance/credit sits with the party.
 */
export type BalanceView = { label: string; tone: "owe" | "settled" | "advance" };

export function partyBalanceView(balance: number): BalanceView {
  if (Math.abs(balance) < 0.005) return { label: "No outstanding", tone: "settled" };
  if (balance > 0) return { label: "Owes you", tone: "owe" };
  return { label: "Advance / credit", tone: "advance" };
}

export const BALANCE_TONE_TEXT: Record<BalanceView["tone"], string> = {
  owe: "text-error",
  settled: "text-muted",
  advance: "text-success",
};
