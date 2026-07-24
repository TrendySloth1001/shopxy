import { invitationListSchema, invitationSchema, type Invitation } from "./schema";

async function jsonOrThrow<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: unknown };
      if (typeof body?.error === "string") message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export type LinkType = "PARTY" | "VENDOR";

export function listOutgoingInvitations(): Promise<Invitation[]> {
  return fetch("/api/invitations", { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => invitationListSchema.parse(raw).data, "Could not load invitations."),
  );
}

/** Invitations addressed to the signed-in user (another shop invited them). */
export function listIncomingInvitations(): Promise<Invitation[]> {
  return fetch("/api/invitations/incoming", { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => invitationListSchema.parse(raw).data, "Could not load invitations."),
  );
}

export async function acceptInvitation(id: string): Promise<void> {
  const res = await fetch(`/api/invitations/${id}/accept`, { method: "POST" });
  if (!res.ok) await jsonOrThrow(res, () => null, "Could not accept the invitation.");
}

export async function declineInvitation(id: string): Promise<void> {
  const res = await fetch(`/api/invitations/${id}/decline`, { method: "POST" });
  if (!res.ok) await jsonOrThrow(res, () => null, "Could not decline the invitation.");
}

export type SendInviteInput = {
  toEmail: string;
  linkType: LinkType;
  partyId?: string;
  vendorId?: string;
  displayName?: string;
  message?: string;
};

export function sendInvitation(input: SendInviteInput): Promise<Invitation> {
  return fetch("/api/invitations", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => invitationSchema.parse(raw), "Could not send the invitation."));
}

export async function cancelInvitation(id: string): Promise<void> {
  const res = await fetch(`/api/invitations/${id}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, () => null, "Could not cancel the invitation.");
  }
}
