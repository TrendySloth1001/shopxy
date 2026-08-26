import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import {
  TEMPLATE_PRESETS,
  DEFAULT_TEMPLATE_ID,
  isKnownTemplateId,
  resolveTemplateConfig,
  renderPdfToBuffer,
  sampleModelForKind,
} from '../../src/shared/pdf/index.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

describe('resolveTemplateConfig (pure)', () => {
  it('resolves every registered preset id to itself', () => {
    for (const p of TEMPLATE_PRESETS) {
      expect(resolveTemplateConfig(p.id).id).toBe(p.id);
    }
  });

  it('falls back to the default for a retired/unknown id instead of throwing', () => {
    expect(resolveTemplateConfig('retired-template-2024').id).toBe(DEFAULT_TEMPLATE_ID);
  });

  it('falls back to the default when no id is stored at all', () => {
    expect(resolveTemplateConfig(null).id).toBe(DEFAULT_TEMPLATE_ID);
    expect(resolveTemplateConfig(undefined).id).toBe(DEFAULT_TEMPLATE_ID);
  });

  it('isKnownTemplateId rejects an unregistered id', () => {
    expect(isKnownTemplateId(DEFAULT_TEMPLATE_ID)).toBe(true);
    expect(isKnownTemplateId('not-a-real-template')).toBe(false);
  });
});

describe('renderPdfToBuffer', () => {
  it('renders a valid PDF for every preset × doc-kind combination', async () => {
    for (const preset of TEMPLATE_PRESETS) {
      for (const kind of ['invoice', 'quotation', 'challan'] as const) {
        const model = sampleModelForKind(kind);
        const buf = await renderPdfToBuffer(model, preset.id);
        expect(buf.subarray(0, 4).toString()).toBe('%PDF');
        expect(buf.length).toBeGreaterThan(500);
      }
    }
  });

  it('falls back to classic for an unrecognized stored template id', async () => {
    const model = sampleModelForKind('invoice');
    const buf = await renderPdfToBuffer(model, 'some-retired-id');
    expect(buf.subarray(0, 4).toString()).toBe('%PDF');
  });
});

describe('GET /pdf-templates', () => {
  it('lists all 7 presets with metadata (no thumbnail URLs — those are bundled client-side)', async () => {
    const app = buildApp();
    const ctx = await createTestUser();
    try {
      const res = await request(app).get('/pdf-templates').set('Authorization', `Bearer ${ctx.accessToken}`);
      expect(res.status).not.toBe(404);
      if (res.status === 200) {
        expect(Array.isArray(res.body)).toBe(true);
        expect(res.body.length).toBe(TEMPLATE_PRESETS.length);
        expect(res.body.map((t: { id: string }) => t.id)).toContain('classic');
      }
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});

describe('GET /pdf-templates/:id/sample', () => {
  it('400s on an unrecognized template id', async () => {
    const app = buildApp();
    const ctx = await createTestUser();
    try {
      const res = await request(app)
        .get('/pdf-templates/not-a-real-template/sample?kind=invoice')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      if (res.status !== 403) {
        expect(res.status).toBe(400);
      }
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('400s on an invalid kind', async () => {
    const app = buildApp();
    const ctx = await createTestUser();
    try {
      const res = await request(app)
        .get('/pdf-templates/classic/sample?kind=bogus')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      if (res.status !== 403) {
        expect(res.status).toBe(400);
      }
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('is not reachable without auth', async () => {
    const app = buildApp();
    const res = await request(app).get('/pdf-templates/classic/sample?kind=invoice');
    expect(res.status).not.toBe(200);
  });
});
