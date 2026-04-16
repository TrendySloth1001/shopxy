import { Request, Response } from 'express';
import { z } from 'zod';
import { usersService } from './users.service.js';

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

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) ? id : null;
}

export class UsersController {
  async create(req: Request, res: Response): Promise<void> {
    const payload = createUserSchema.parse(req.body);
    const user = await usersService.createUser(payload);
    res.status(201).json(user);
  }

  async list(_req: Request, res: Response): Promise<void> {
    const users = await usersService.listUsers();
    res.json(users);
  }

  async getById(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    const user = await usersService.getUserById(id);
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json(user);
  }

  async update(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    const payload = updateUserSchema.parse(req.body);
    const user = await usersService.updateUser(id, payload);
    res.json(user);
  }

  async delete(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }

    await usersService.deleteUser(id);
    res.status(204).send();
  }
}

export const usersController = new UsersController();
