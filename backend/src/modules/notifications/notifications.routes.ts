import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { notificationsController } from './notifications.controller.js';

const router = Router();

router.get('/', asyncHandler((req, res) => notificationsController.list(req, res)));
router.get('/unread-count', asyncHandler((req, res) => notificationsController.unreadCount(req, res)));
router.post('/read-all', asyncHandler((req, res) => notificationsController.markAllRead(req, res)));
router.post('/:id/read', asyncHandler((req, res) => notificationsController.markRead(req, res)));

export default router;
