import { ticketSchema, type Ticket } from "./types";

/// The POS runs entirely over the WebSocket; the only HTTP call is the ticket
/// mint that bootstraps the socket (cookie-authed via the BFF). See usePosSale.
export async function requestPosTicket(): Promise<Ticket> {
  const res = await fetch("/api/pos/ticket", { method: "POST" });
  const body = (await res.json().catch(() => null)) as unknown;
  if (!res.ok) {
    throw new Error((body as { error?: string } | null)?.error ?? "Could not start the till.");
  }
  return ticketSchema.parse(body);
}
