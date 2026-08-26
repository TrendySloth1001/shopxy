import { describe, it, expect } from 'vitest';
import { isOutputGstRegistered } from '../../src/modules/invoices/gst-registration-gate.js';

const registered = (gstEffectiveFrom: Date | null) => ({
  shopGstin: '27ABCDE1234F1Z5',
  registrationType: 'REGULAR' as const,
  gstEffectiveFrom,
});

describe('isOutputGstRegistered', () => {
  it('REGULAR + GSTIN + null effective date is ungated (pre-feature backward compat)', () => {
    expect(isOutputGstRegistered(registered(null), new Date('2020-01-01'))).toBe(true);
    expect(isOutputGstRegistered(registered(null), new Date('2099-01-01'))).toBe(true);
  });

  it('asOf one calendar day before the effective date is false', () => {
    const owner = registered(new Date('2026-08-10'));
    expect(isOutputGstRegistered(owner, new Date('2026-08-09T23:59:59.999Z'))).toBe(false);
  });

  it('asOf on the effective date is true at both ends of the day (date-only comparison)', () => {
    const owner = registered(new Date('2026-08-10'));
    expect(isOutputGstRegistered(owner, new Date('2026-08-10T00:00:00.000Z'))).toBe(true);
    expect(isOutputGstRegistered(owner, new Date('2026-08-10T23:59:59.999Z'))).toBe(true);
  });

  it('asOf one calendar day after the effective date is true', () => {
    const owner = registered(new Date('2026-08-10'));
    expect(isOutputGstRegistered(owner, new Date('2026-08-11T00:00:01.000Z'))).toBe(true);
  });

  it('COMPOSITION is always false regardless of date', () => {
    const owner = {
      shopGstin: '27ABCDE1234F1Z5',
      registrationType: 'COMPOSITION' as const,
      gstEffectiveFrom: new Date('2020-01-01'),
    };
    expect(isOutputGstRegistered(owner, new Date('2099-01-01'))).toBe(false);
  });

  it('UNREGISTERED is always false regardless of date/GSTIN', () => {
    const owner = {
      shopGstin: null,
      registrationType: 'UNREGISTERED' as const,
      gstEffectiveFrom: null,
    };
    expect(isOutputGstRegistered(owner, new Date('2099-01-01'))).toBe(false);
  });

  it('REGULAR with a missing GSTIN is false regardless of date (misconfigured row)', () => {
    const owner = {
      shopGstin: null,
      registrationType: 'REGULAR' as const,
      gstEffectiveFrom: new Date('2020-01-01'),
    };
    expect(isOutputGstRegistered(owner, new Date('2099-01-01'))).toBe(false);
  });

  it('compares UTC calendar days, not local time — a non-UTC-midnight asOf near the day boundary still resolves correctly', () => {
    const owner = registered(new Date('2026-08-10'));
    expect(isOutputGstRegistered(owner, new Date('2026-08-10T01:30:00.000Z'))).toBe(true);
    expect(isOutputGstRegistered(owner, new Date('2026-08-09T23:00:00.000Z'))).toBe(false);
  });
});
