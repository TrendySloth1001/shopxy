import { Request, Response } from 'express';
import { z } from 'zod';
import { decodeId } from '../../shared/ids/publicId.js';
import { teamService } from './team.service.js';
import { invitationsService } from '../invitations/invitations.service.js';
import { isValidRight } from '../../shared/http/permissions.js';

const ERROR_STATUS: Record<string, number> = {
  MEMBER_NOT_FOUND: 404,
  ROLE_NOT_FOUND: 404,
  ROLE_EXISTS: 409,
  CANNOT_GRANT_BEYOND_OWN_RIGHTS: 403,
};
function fail(res: Response, code: string) {
  res.status(ERROR_STATUS[code] ?? 400).json({ error: code });
}

const ROLE_NAME = z.string().trim().min(1).max(60);
const RIGHTS = z.array(z.string().refine(isValidRight, 'Invalid right'));

export async function listMembers(req: Request, res: Response) {
  res.json({ members: await teamService.listMembers(req.shopId!) });
}

export async function listInvites(req: Request, res: Response) {
  res.json({ invites: await teamService.listInvites(req.shopId!) });
}

const inviteSchema = z.object({
  email: z.string().email(),
  roleName: ROLE_NAME,
  permissions: RIGHTS,
  message: z.string().trim().max(500).optional(),
});

export async function invite(req: Request, res: Response) {
  const parsed = inviteSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.issues[0]?.message ?? 'Invalid input' });
    return;
  }
  const result = await invitationsService.sendInvite({
    shopId: req.shopId!,
    fromUserId: req.user!.sub,
    toEmail: parsed.data.email,
    linkType: 'TEAM',
    teamRoleName: parsed.data.roleName,
    teamPermissions: parsed.data.permissions,
    message: parsed.data.message ?? null,
    actingShopRole: req.user!.shopRole,
    actingPermissions: req.user!.shopPermissions,
  });
  if ('error' in result && result.error) {
    fail(res, result.error);
    return;
  }
  res.status(201).json({ invitation: result.invitation });
}

export async function cancelInvite(req: Request, res: Response) {
  const id = decodeId(req.params.id);
  if (id === null) {
    res.status(400).json({ error: 'Invalid invitation id' });
    return;
  }
  const result = await invitationsService.cancel({ invitationId: id, userId: req.user!.sub });
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.json({ invitation: result.invitation });
}

const setPermissionsSchema = z.object({ roleName: ROLE_NAME, permissions: RIGHTS });

export async function updatePermissions(req: Request, res: Response) {
  const targetUserId = decodeId(req.params.userId);
  if (targetUserId === null) {
    res.status(400).json({ error: 'Invalid user id' });
    return;
  }
  const parsed = setPermissionsSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.issues[0]?.message ?? 'Invalid input' });
    return;
  }
  const result = await teamService.setPermissions({
    shopId: req.shopId!,
    actingUserId: req.user!.sub,
    actingShopRole: req.user!.shopRole,
    actingPermissions: req.user!.shopPermissions,
    targetUserId,
    roleName: parsed.data.roleName,
    permissions: parsed.data.permissions,
  });
  if ('error' in result && result.error) {
    fail(res, result.error);
    return;
  }
  res.json({ member: 'member' in result ? result.member : undefined });
}

export async function removeMember(req: Request, res: Response) {
  const targetUserId = decodeId(req.params.userId);
  if (targetUserId === null) {
    res.status(400).json({ error: 'Invalid user id' });
    return;
  }
  const result = await teamService.removeMember({
    shopId: req.shopId!,
    actingUserId: req.user!.sub,
    targetUserId,
  });
  if ('error' in result && result.error) {
    fail(res, result.error);
    return;
  }
  res.status(204).end();
}

export async function listRoles(req: Request, res: Response) {
  res.json({ roles: await teamService.listRoles(req.shopId!) });
}

const roleSchema = z.object({ name: ROLE_NAME, permissions: RIGHTS });

export async function createRole(req: Request, res: Response) {
  const parsed = roleSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.issues[0]?.message ?? 'Invalid input' });
    return;
  }
  const result = await teamService.createRole({
    shopId: req.shopId!,
    name: parsed.data.name,
    permissions: parsed.data.permissions,
    actingShopRole: req.user!.shopRole,
    actingPermissions: req.user!.shopPermissions,
  });
  if ('error' in result && result.error) {
    fail(res, result.error);
    return;
  }
  res.status(201).json({ role: result.role });
}

const roleUpdateSchema = z.object({
  name: ROLE_NAME.optional(),
  permissions: RIGHTS.optional(),
});

export async function updateRole(req: Request, res: Response) {
  const id = decodeId(req.params.id);
  if (id === null) {
    res.status(400).json({ error: 'Invalid role id' });
    return;
  }
  const parsed = roleUpdateSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.issues[0]?.message ?? 'Invalid input' });
    return;
  }
  const result = await teamService.updateRole({
    shopId: req.shopId!,
    id,
    name: parsed.data.name,
    permissions: parsed.data.permissions,
    actingShopRole: req.user!.shopRole,
    actingPermissions: req.user!.shopPermissions,
  });
  if ('error' in result && result.error) {
    fail(res, result.error);
    return;
  }
  res.json({ role: result.role });
}

export async function deleteRole(req: Request, res: Response) {
  const id = decodeId(req.params.id);
  if (id === null) {
    res.status(400).json({ error: 'Invalid role id' });
    return;
  }
  const result = await teamService.deleteRole({ shopId: req.shopId!, id });
  if ('error' in result && result.error) {
    fail(res, result.error);
    return;
  }
  res.status(204).end();
}
