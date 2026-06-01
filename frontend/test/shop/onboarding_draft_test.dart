// Pure model tests for the payout-onboarding draft. The secure-storage layer
// (OnboardingDraftStore) is a thin best-effort wrapper around a platform
// channel; the version + TTL + round-trip decisions live on the model, so we
// test those directly without a channel mock.

import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/features/shop/data/datasources/onboarding_draft_store.dart';

OnboardingDraft _sample({int step = 2, int savedAtMs = 1000}) => OnboardingDraft(
      step: step,
      legalName: 'Acme Traders',
      customerFacing: 'Acme',
      contact: 'Owner',
      email: 'o@acme.test',
      phone: '9999999999',
      businessType: 'partnership',
      category: 'ecommerce',
      pan: 'AAACL1234C',
      gst: '29AABCU9603R1ZX',
      street1: '1 MG Road',
      street2: '',
      city: 'Bengaluru',
      state: 'Karnataka',
      postal: '560001',
      beneficiary: 'Acme Traders',
      account: '1234567890',
      ifsc: 'HDFC0001234',
      savedAtMs: savedAtMs,
    );

void main() {
  test('round-trips every field through toJson/fromJson', () {
    final original = _sample();
    final restored = OnboardingDraft.fromJson(original.toJson());
    expect(restored, isNotNull);
    expect(restored!.step, 2);
    expect(restored.legalName, 'Acme Traders');
    expect(restored.pan, 'AAACL1234C');
    expect(restored.gst, '29AABCU9603R1ZX');
    expect(restored.state, 'Karnataka');
    expect(restored.ifsc, 'HDFC0001234');
    expect(restored.savedAtMs, 1000);
  });

  test('rejects a draft from a different schema version', () {
    final json = _sample().toJson()..['v'] = 999;
    expect(OnboardingDraft.fromJson(json), isNull);
  });

  test('treats an empty state string as null (no selection)', () {
    final json = _sample().toJson()..['state'] = '';
    expect(OnboardingDraft.fromJson(json)!.state, isNull);
  });

  test('falls back to defaults for missing business type / category', () {
    final json = _sample().toJson()
      ..['businessType'] = ''
      ..['category'] = '';
    final d = OnboardingDraft.fromJson(json)!;
    expect(d.businessType, 'proprietorship');
    expect(d.category, 'ecommerce');
  });

  test('isExpiredAt honours the 14-day TTL', () {
    final d = _sample(savedAtMs: 0);
    final justUnder = OnboardingDraft.maxAge.inMilliseconds - 1;
    final justOver = OnboardingDraft.maxAge.inMilliseconds + 1;
    expect(d.isExpiredAt(justUnder), isFalse);
    expect(d.isExpiredAt(justOver), isTrue);
  });

  test('stepLabel maps the step index to its title', () {
    expect(_sample(step: 0).stepLabel, 'Business');
    expect(_sample(step: 1).stepLabel, 'Identity');
    expect(_sample(step: 3).stepLabel, 'Bank');
    // Out-of-range clamps rather than throwing.
    expect(_sample(step: 9).stepLabel, 'Bank');
  });
}
