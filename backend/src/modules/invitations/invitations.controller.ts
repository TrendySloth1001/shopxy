import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { invitationsService } from './invitations.service.js';

const sendSchema = z
  .object({
    toEmail: z.string().trim().email().max(200),
    linkType: z.enum(['PARTY', 'VENDOR']),
    partyId: z.number().int().positive().optional(),
    vendorId: z.number().int().positive().optional(),
    /// Required when neither partyId nor vendorId is provided — used
    /// to name the Party/Vendor row that's created at accept time.
    displayName: z.string().trim().min(1).max(200).optional(),
    message: z.string().max(500).optional(),
  })
  .refine(
    (d) => {
      const hasEntity = d.linkType === 'PARTY' ? !!d.partyId : !!d.vendorId;
      return hasEntity || !!d.displayName;
    },
    { message: 'Either an existing partyId/vendorId or displayName is required' },
  );

const statusSchema = z.enum(['PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'EXPIRED', 'ALL']).optional();

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class InvitationsController {
  async send(req: Request, res: Response): Promise<void> {
    const parsed = sendSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.flatten() });
      return;
    }
    const result = await invitationsService.sendInvite({
      fromUserId: req.user!.sub,
      toEmail: parsed.data.toEmail,
      linkType: parsed.data.linkType,
      partyId: parsed.data.partyId ?? null,
      vendorId: parsed.data.vendorId ?? null,
      displayName: parsed.data.displayName ?? null,
      message: parsed.data.message ?? null,
    });
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.status(201).json(result.invitation);
  }

  async incoming(req: Request, res: Response): Promise<void> {
    const status = statusSchema.parse(req.query.status);
    const { page, limit, skip } = parsePagination(req);
    const { data, total } = await invitationsService.listIncoming({
      userId: req.user!.sub,
      status,
      skip,
      limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async outgoing(req: Request, res: Response): Promise<void> {
    const status = statusSchema.parse(req.query.status);
    const { page, limit, skip } = parsePagination(req);
    const { data, total } = await invitationsService.listOutgoing({
      userId: req.user!.sub,
      status,
      skip,
      limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async accept(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const result = await invitationsService.respond({
      invitationId: id,
      userId: req.user!.sub,
      decision: 'ACCEPT',
    });
    if ('error' in result) { res.status(400).json({ error: result.error }); return; }
    res.json(result.invitation);
  }

  async decline(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const result = await invitationsService.respond({
      invitationId: id,
      userId: req.user!.sub,
      decision: 'DECLINE',
    });
    if ('error' in result) { res.status(400).json({ error: result.error }); return; }
    res.json(result.invitation);
  }

  async cancel(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const result = await invitationsService.cancel({
      invitationId: id,
      userId: req.user!.sub,
    });
    if ('error' in result) { res.status(400).json({ error: result.error }); return; }
    res.status(204).send();
  }
}

export const invitationsController = new InvitationsController();
