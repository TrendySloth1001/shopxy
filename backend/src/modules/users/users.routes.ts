import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../infra/db/prisma';
import asyncHandler from '../../shared/http/asyncHandler';

const router = Router();

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).optional(),
});

const updateUserSchema = z
  .object({
    email: z.string().email().optional(),
    name: z.string().min(1).optional(),
  })
  .refine((data) => Object.keys(data).length > 0, {
    message: 'At least one field is required',
  });

router.post(
  '/',
  asyncHandler(async (req, res) => {
    const payload = createUserSchema.parse(req.body);
    const user = await prisma.user.create({ data: payload });
    res.status(201).json(user);
  })
);

router.get(
  '/',
  asyncHandler(async (_req, res) => {
    const users = await prisma.user.findMany({ orderBy: { id: 'asc' } });
    res.json(users);
  })
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json(user);
  })
);

router.patch(
  '/:id',
  asyncHandler(async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    const payload = updateUserSchema.parse(req.body);
    const user = await prisma.user.update({ where: { id }, data: payload });
    res.json(user);
  })
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    await prisma.user.delete({ where: { id } });
    res.status(204).send();
  })
);

export default router;
