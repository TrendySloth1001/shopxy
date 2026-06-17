import { ticketSchema, type Ticket } from "./types";

/** Mint a one-time WebSocket ticket (cookie-authed via the BFF). */
export async function requestTicket(): Promise<Ticket> {
  const res = await fetch("/api/scan-console/ticket", { method: "POST" });
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { error?: string } | null;
    throw new Error(body?.error ?? "Could not start the scan console.");
  }
  return ticketSchema.parse(await res.json());
}

/** Reset every live console for this shop. */
export async function clearConsole(): Promise<void> {
  const res = await fetch("/api/scan-console/clear", { method: "POST" });
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { error?: string } | null;
    throw new Error(body?.error ?? "Could not clear the console.");
  }
}

/**
 * Browser-reachable backend WebSocket origin. This is the one place merchant-web
 * deliberately steps outside the BFF: Next 16's App Router can't transparently
 * proxy a WebSocket upgrade, so the browser connects to the backend directly.
 * The JWT still never ships to the client — only the single-use ticket does
 * (see PENDING.md for the production-correct same-origin path).
 */
export function wsBase(): string {
  return process.env.NEXT_PUBLIC_BACKEND_WS_URL ?? "ws://localhost:3003";
}
