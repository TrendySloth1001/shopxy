import { describe, it, expect, afterAll } from 'vitest';
import express from 'express';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import {
  AREAS,
  ALL_RIGHTS,
  hasRight,
  normalizeRights,
  presetFor,
  rightForRequest,
  requireArea,
  isValidRight,
  type Area,
} from '../../src/shared/http/permissions.js';
import {
  MERCHANT_AREAS,
  OPEN_MERCHANT_MOUNTS,
} from '../../src/shared/http/merchantAreas.js';

// A tiny app that injects a fixed req.user, then gates /x with
// requireArea('invoices'). Lets us exercise the gate without a DB.
function gatedApp(user: unknown) {
  const a = express();
  a.use((req, _res, next) => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (req as any).user = user;
    next();
  });
  a.use('/x', requireArea('invoices'), (_req, res) => res.json({ ok: true }));
  return a;
}

describe('permissions core', () => {
  it('rightForRequest: reads need :view, writes need :manage', () => {
    expect(rightForRequest('invoices', 'GET')).toBe('invoices:view');
    expect(rightForRequest('invoices', 'POST')).toBe('invoices:manage');
    expect(rightForRequest('invoices', 'DELETE')).toBe('invoices:manage');
  });

  it('hasRight: OWNER bypasses everything', () => {
    expect(hasRight('OWNER', [], 'payments:manage')).toBe(true);
    expect(hasRight('OWNER', undefined, 'team:manage')).toBe(true);
  });

  it('hasRight: manage implies view', () => {
    expect(hasRight('CASHIER', ['invoices:manage'], 'invoices:view')).toBe(true);
    expect(hasRight('CASHIER', ['invoices:view'], 'invoices:manage')).toBe(false);
  });

  it('hasRight: missing/empty grant is denied (fail-closed)', () => {
    expect(hasRight('CASHIER', [], 'invoices:view')).toBe(false);
    expect(hasRight(undefined, undefined, 'invoices:view')).toBe(false);
    expect(hasRight('CASHIER', ['orders:manage'], 'invoices:view')).toBe(false);
  });

  it('normalizeRights drops unknowns and back-fills view for every manage', () => {
    expect(normalizeRights(['invoices:manage', 'bogus:manage'])).toEqual([
      'invoices:manage',
      'invoices:view',
    ]);
  });

  it('presets are subsets of ALL_RIGHTS', () => {
    for (const role of ['MANAGER', 'STOCKIST', 'CASHIER'] as const) {
      for (const r of presetFor(role)) {
        expect(ALL_RIGHTS).toContain(r);
      }
    }
  });
});

describe('requireArea middleware', () => {
  it('lets an owner through reads and writes', async () => {
    const app = gatedApp({ shopRole: 'OWNER', shopPermissions: [] });
    expect((await request(app).get('/x')).status).toBe(200);
    expect((await request(app).post('/x')).status).toBe(200);
  });

  it('allows a viewer to read but not write', async () => {
    const app = gatedApp({ shopRole: 'CASHIER', shopPermissions: ['invoices:view'] });
    expect((await request(app).get('/x')).status).toBe(200);
    const w = await request(app).post('/x');
    expect(w.status).toBe(403);
    expect(w.body.code).toBe('INSUFFICIENT_PERMISSION');
    expect(w.body.required).toBe('invoices:manage');
  });

  it('denies a member without the area entirely (no view → no read)', async () => {
    const app = gatedApp({ shopRole: 'STOCKIST', shopPermissions: ['stock:manage'] });
    expect((await request(app).get('/x')).status).toBe(403);
    expect((await request(app).post('/x')).status).toBe(403);
  });
});

describe('merchant route registry coverage', () => {
  it('every registry value is a real area', () => {
    for (const area of Object.values(MERCHANT_AREAS)) {
      expect(AREAS).toContain(area as Area);
    }
  });

  it('registry and open-mounts do not overlap', () => {
    for (const open of OPEN_MERCHANT_MOUNTS) {
      expect(MERCHANT_AREAS[open]).toBeUndefined();
    }
  });

  it('all grantable rights are valid', () => {
    for (const r of ALL_RIGHTS) expect(isValidRight(r)).toBe(true);
  });

  // buildApp() throws at boot if a merchant router is mounted without a
  // registry entry (mountMerchant fail-closed), so a clean build proves
  // there's no un-gated merchant mount.
  it('app builds (no un-registered merchant mount)', () => {
    expect(() => buildApp()).not.toThrow();
  });

  // …and every registered prefix is actually mounted behind auth: an
  // unauthenticated hit returns 401 (gated), never 404 (missing). Catches
  // stale registry entries whose route was removed.
  it('every registered prefix is mounted behind requireAuth', async () => {
    const app = buildApp();
    for (const prefix of Object.keys(MERCHANT_AREAS)) {
      const res = await request(app).get(prefix);
      expect(res.status, `${prefix} should be gated, not missing`).not.toBe(404);
      expect([401, 403]).toContain(res.status);
    }
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });
});
