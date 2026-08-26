import { ticketSchema, type Ticket } from "./types";

export async function requestTicket(): Promise<Ticket> {
  const res = await fetch("/api/scan-console/ticket", { method: "POST" });
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { error?: string } | null;
    throw new Error(body?.error ?? "Could not start the scan console.");
  }
  return ticketSchema.parse(await res.json());
}

export async function clearConsole(): Promise<void> {
  const res = await fetch("/api/scan-console/clear", { method: "POST" });
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { error?: string } | null;
    throw new Error(body?.error ?? "Could not clear the console.");
  }
}

export function wsBase(): string {
  return process.env.NEXT_PUBLIC_BACKEND_WS_URL ?? "ws://localhost:3003";
}
