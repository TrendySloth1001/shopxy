import { ticketSchema, type Ticket } from "./types";

export async function requestPosTicket(): Promise<Ticket> {
  const res = await fetch("/api/pos/ticket", { method: "POST" });
  const body = (await res.json().catch(() => null)) as unknown;
  if (!res.ok) {
    throw new Error((body as { error?: string } | null)?.error ?? "Could not start the till.");
  }
  return ticketSchema.parse(body);
}
