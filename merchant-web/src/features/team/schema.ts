import { z } from "zod";

/** Team shapes, mirroring `backend/src/modules/team/*`. */

const arr = <T extends z.ZodTypeAny>(s: T) =>
  z
    .array(s)
    .nullish()
    .transform((v) => v ?? []);

export const memberSchema = z
  .object({
    id: z.number(),
    role: z.string(),
    roleName: z.string().nullish(),
    permissions: arr(z.string()),
    createdAt: z.string(),
    isOwner: z.boolean().default(false),
    user: z
      .object({
        id: z.number(),
        name: z.string(),
        email: z.string(),
        avatarUrl: z.string().nullish(),
      })
      .passthrough(),
  })
  .passthrough();
export type Member = z.infer<typeof memberSchema>;

export const inviteSchema = z
  .object({
    id: z.number(),
    toEmail: z.string(),
    teamRoleName: z.string().nullish(),
    teamPermissions: arr(z.string()),
    createdAt: z.string(),
    expiresAt: z.string().nullish(),
  })
  .passthrough();
export type Invite = z.infer<typeof inviteSchema>;

export const roleSchema = z
  .object({
    id: z.number(),
    name: z.string(),
    permissions: arr(z.string()),
    builtin: z.boolean().default(false),
  })
  .passthrough();
export type Role = z.infer<typeof roleSchema>;

export const membersResponse = z.object({ members: z.array(memberSchema) });
export const invitesResponse = z.object({ invites: z.array(inviteSchema) });
export const rolesResponse = z.object({ roles: z.array(roleSchema) });
