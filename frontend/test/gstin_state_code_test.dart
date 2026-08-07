// A GSTIN's first two digits ARE the holder's GST state code — that's how the
// number is constructed. The invoice form relies on this to DERIVE place of
// supply instead of asking for it, so a wrong answer here silently mis-splits
// tax between CGST/SGST and IGST on a real invoice.

import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/shared/constants/indian.dart';

void main() {
  group('IndianStates.stateCodeFromGstin', () {
    test('reads the state code off a complete GSTIN', () {
      expect(IndianStates.stateCodeFromGstin('27ABCDE1234F1Z5'), '27');
      expect(IndianStates.stateCodeFromGstin('23AAAAA0000A1Z5'), '23');
      // 07 = Delhi, and a leading zero must survive — treating the prefix as a
      // number somewhere would turn this into "7" and match nothing.
      expect(IndianStates.stateCodeFromGstin('07AABCU9603R1ZM'), '07');
    });

    // The merchant types left to right, and the state is knowable from the
    // third character on. Waiting for a valid 15-char GSTIN would leave the
    // place-of-supply row blank through almost the whole entry.
    test('answers from just the prefix, mid-typing', () {
      expect(IndianStates.stateCodeFromGstin('27'), '27');
      expect(IndianStates.stateCodeFromGstin('27ABC'), '27');
    });

    test('tolerates surrounding whitespace', () {
      expect(IndianStates.stateCodeFromGstin('  27ABCDE1234F1Z5  '), '27');
    });

    test('returns null for too-short or empty input', () {
      expect(IndianStates.stateCodeFromGstin(null), isNull);
      expect(IndianStates.stateCodeFromGstin(''), isNull);
      expect(IndianStates.stateCodeFromGstin('2'), isNull);
      expect(IndianStates.stateCodeFromGstin('   '), isNull);
    });

    // Guards the fallback: an unrecognised prefix must derive NOTHING, so the
    // form falls back to the shop's own state (a local supply) rather than
    // charging IGST against a state that doesn't exist.
    test('returns null for a two-digit prefix that is not a real state code', () {
      expect(IndianStates.stateCodeFromGstin('99ABCDE1234F1Z5'), isNull);
      expect(IndianStates.stateCodeFromGstin('00ABCDE1234F1Z5'), isNull);
    });

    test('returns null for a non-numeric prefix', () {
      expect(IndianStates.stateCodeFromGstin('ABCDE1234F1Z5'), isNull);
      expect(IndianStates.stateCodeFromGstin('2A'), isNull);
    });

    // Every code the picker could ever show must round-trip, or some states
    // would be underivable from a perfectly valid GSTIN.
    test('resolves every state in the table', () {
      for (final s in IndianStates.all) {
        expect(
          IndianStates.stateCodeFromGstin('${s.code}ABCDE1234F1Z5'),
          s.code,
          reason: '${s.name} (${s.code}) must be derivable from its GSTIN',
        );
      }
    });
  });
}
