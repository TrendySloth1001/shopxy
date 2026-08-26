import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/shared/constants/indian.dart';

void main() {
  group('IndianStates.stateCodeFromGstin', () {
    test('reads the state code off a complete GSTIN', () {
      expect(IndianStates.stateCodeFromGstin('27ABCDE1234F1Z5'), '27');
      expect(IndianStates.stateCodeFromGstin('23AAAAA0000A1Z5'), '23');
      expect(IndianStates.stateCodeFromGstin('07AABCU9603R1ZM'), '07');
    });

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

    test('returns null for a two-digit prefix that is not a real state code', () {
      expect(IndianStates.stateCodeFromGstin('99ABCDE1234F1Z5'), isNull);
      expect(IndianStates.stateCodeFromGstin('00ABCDE1234F1Z5'), isNull);
    });

    test('returns null for a non-numeric prefix', () {
      expect(IndianStates.stateCodeFromGstin('ABCDE1234F1Z5'), isNull);
      expect(IndianStates.stateCodeFromGstin('2A'), isNull);
    });

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
