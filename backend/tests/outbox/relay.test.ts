import { describe, it, expect, afterAll } from 'vitest';
import crypto from 'crypto';
import prisma from '../../src/infra/db/prisma.js';
import { enqueueOutbox } from '../../src/infra/outbox/outbox.js';
import { onOutbox } from '../../src/infra/outbox/handlers.js';
import { runOutboxRelay } from '../../src/infra/outbox/relay.js';
import type { OutboxEnvelope } from '../../src/infra/outbox/types.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

const tag = crypto.randomBytes(6).toString('hex');
const AGG = `test-${tag}`;

describe('outbox relay', () => {
  afterAll(async () => {
    await prisma.outboxEvent.deleteMany({ where: { aggregateType: AGG } });
    await prisma.$disconnect();
  });

  it('dispatches a pending event to its handler and marks it PUBLISHED', async () => {
    const seen: OutboxEnvelope[] = [];
    onOutbox(`test.ok.${tag}`, async (e) => {
      seen.push(e);
    });

    await enqueueOutbox({
      aggregateType: AGG,
      aggregateId: 'a1',
      eventType: `test.ok.${tag}`,
      shopId: 4242,
      payload: { hello: 'world' },
    });

    await runOutboxRelay();

    expect(seen).toHaveLength(1);
    expect(seen[0].shopId).toBe(4242);
    expect(seen[0].payload).toMatchObject({ hello: 'world' });

    const row = await prisma.outboxEvent.findFirst({ where: { aggregateType: AGG, aggregateId: 'a1' } });
    expect(row?.status).toBe('PUBLISHED');
    expect(row?.publishedAt).not.toBeNull();
    expect(row?.attempts).toBe(0);
  });

  it('marks an event with no registered handler as PUBLISHED', async () => {
    await enqueueOutbox({
      aggregateType: AGG,
      aggregateId: 'a2',
      eventType: `test.nohandler.${tag}`,
      payload: {},
    });

    await runOutboxRelay();

    const row = await prisma.outboxEvent.findFirst({ where: { aggregateType: AGG, aggregateId: 'a2' } });
    expect(row?.status).toBe('PUBLISHED');
  });

  it('retries a failing handler with backoff instead of losing the event', async () => {
    onOutbox(`test.boom.${tag}`, async () => {
      throw new Error('boom');
    });

    await enqueueOutbox({
      aggregateType: AGG,
      aggregateId: 'a3',
      eventType: `test.boom.${tag}`,
      payload: {},
    });

    await runOutboxRelay();

    const row = await prisma.outboxEvent.findFirst({ where: { aggregateType: AGG, aggregateId: 'a3' } });
    expect(row?.status).toBe('PENDING');
    expect(row?.attempts).toBe(1);
    expect(row?.lastError).toContain('boom');
    expect(row && row.availableAt.getTime()).toBeGreaterThan(Date.now());
  });

  it('does not re-dispatch an event already PUBLISHED', async () => {
    let count = 0;
    onOutbox(`test.once.${tag}`, async () => {
      count += 1;
    });

    await enqueueOutbox({
      aggregateType: AGG,
      aggregateId: 'a4',
      eventType: `test.once.${tag}`,
      payload: {},
    });

    await runOutboxRelay();
    await runOutboxRelay();

    expect(count).toBe(1);
  });

  it('drives a real invoice.confirmed event through to the roll-up handler', async () => {
    const ctx = await createTestUser();
    try {
      await enqueueOutbox({
        aggregateType: 'invoice',
        aggregateId: `e2e-${tag}`,
        eventType: 'invoice.confirmed',
        shopId: ctx.shopId,
        payload: { invoiceId: 0, occurredAt: new Date().toISOString() },
      });

      await runOutboxRelay();

      const row = await prisma.outboxEvent.findFirst({
        where: { aggregateType: 'invoice', aggregateId: `e2e-${tag}` },
      });
      expect(row?.status).toBe('PUBLISHED');
      expect(row?.attempts).toBe(0);

      await prisma.outboxEvent.deleteMany({ where: { aggregateType: 'invoice', aggregateId: `e2e-${tag}` } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('writes the event in the caller transaction — a rolled-back write leaves no event', async () => {
    await prisma
      .$transaction(async (tx) => {
        await enqueueOutbox(
          { aggregateType: AGG, aggregateId: 'rollback', eventType: `test.ok.${tag}`, payload: {} },
          tx,
        );
        throw new Error('abort');
      })
      .catch(() => {});

    const row = await prisma.outboxEvent.findFirst({ where: { aggregateType: AGG, aggregateId: 'rollback' } });
    expect(row).toBeNull();
  });
});
