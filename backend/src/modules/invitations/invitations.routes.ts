import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { invitationsController } from './invitations.controller.js';

const router = Router();

router.post('/', asyncHandler((req, res) => invitationsController.send(req, res)));
// Claim a pending invite by presenting its per-invite token (from the invite
// link). Secure replacement for the removed email-match auto-claim
// (AUTH-INVITE-1) — possession of the token proves the recipient received it.
router.post('/claim', asyncHandler((req, res) => invitationsController.claim(req, res)));
router.get('/incoming', asyncHandler((req, res) => invitationsController.incoming(req, res)));
router.get('/outgoing', asyncHandler((req, res) => invitationsController.outgoing(req, res)));
router.post('/:id/accept', asyncHandler((req, res) => invitationsController.accept(req, res)));
router.post('/:id/decline', asyncHandler((req, res) => invitationsController.decline(req, res)));
router.delete('/:id', asyncHandler((req, res) => invitationsController.cancel(req, res)));

export default router;
