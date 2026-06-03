import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import {
  listMembers,
  listInvites,
  invite,
  cancelInvite,
  updatePermissions,
  removeMember,
  listRoles,
  createRole,
  updateRole,
  deleteRole,
} from './team.controller.js';

/// Mounted at /me/team behind requireAuth + requireRole('OWNER') +
/// requireArea('team') + resolveShop. The area gate handles authz: GETs
/// need team:view, mutations need team:manage (OWNER bypasses).
const router = Router();

router.get('/members', asyncHandler(listMembers));
router.patch('/members/:userId/permissions', asyncHandler(updatePermissions));
router.delete('/members/:userId', asyncHandler(removeMember));

router.get('/invites', asyncHandler(listInvites));
router.post('/invites', asyncHandler(invite));
router.delete('/invites/:id', asyncHandler(cancelInvite));

// Owner-defined roles (named permission templates).
router.get('/roles', asyncHandler(listRoles));
router.post('/roles', asyncHandler(createRole));
router.patch('/roles/:id', asyncHandler(updateRole));
router.delete('/roles/:id', asyncHandler(deleteRole));

export default router;
