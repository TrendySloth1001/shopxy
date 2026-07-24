import {
  invitesResponse,
  membersResponse,
  rolesResponse,
  type Invite,
  type Member,
  type Role,
} from "./schema";

async function okJson<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
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

async function okVoid(res: Response, fallback: string): Promise<void> {
  if (!res.ok && res.status !== 204) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
}

export function listMembers(): Promise<Member[]> {
  return fetch("/api/team/members", { cache: "no-store" }).then((r) =>
    okJson(r, (raw) => membersResponse.parse(raw).members, "Could not load the team."),
  );
}

export function listInvites(): Promise<Invite[]> {
  return fetch("/api/team/invites", { cache: "no-store" }).then((r) =>
    okJson(r, (raw) => invitesResponse.parse(raw).invites, "Could not load invites."),
  );
}

export function listRoles(): Promise<Role[]> {
  return fetch("/api/team/roles", { cache: "no-store" }).then((r) =>
    okJson(r, (raw) => rolesResponse.parse(raw).roles, "Could not load roles."),
  );
}

export function sendInvite(input: {
  email: string;
  roleName: string;
  permissions: string[];
  message?: string;
}): Promise<void> {
  return fetch("/api/team/invites", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => okVoid(r, "Could not send the invite."));
}

export function cancelInvite(id: string): Promise<void> {
  return fetch(`/api/team/invites/${id}`, { method: "DELETE" }).then((r) =>
    okVoid(r, "Could not cancel the invite."),
  );
}

export function setMemberPermissions(
  userId: string,
  input: { roleName: string; permissions: string[] },
): Promise<void> {
  return fetch(`/api/team/members/${userId}/permissions`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => okVoid(r, "Could not update permissions."));
}

export function removeMember(userId: string): Promise<void> {
  return fetch(`/api/team/members/${userId}`, { method: "DELETE" }).then((r) =>
    okVoid(r, "Could not remove the member."),
  );
}

export function createRole(input: { name: string; permissions: string[] }): Promise<void> {
  return fetch("/api/team/roles", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => okVoid(r, "Could not create the role."));
}

export function updateRole(
  id: string,
  input: { name?: string; permissions?: string[] },
): Promise<void> {
  return fetch(`/api/team/roles/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => okVoid(r, "Could not save the role."));
}

export function deleteRole(id: string): Promise<void> {
  return fetch(`/api/team/roles/${id}`, { method: "DELETE" }).then((r) =>
    okVoid(r, "Could not delete the role."),
  );
}
