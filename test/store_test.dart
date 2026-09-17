import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/models/store.dart';

void main() {
  group('canonicalStoreName', () {
    test('merges different casings of a known chain to the same display name', () {
      expect(canonicalStoreName('KIWI'), 'Kiwi');
      expect(canonicalStoreName('Kiwi'), 'Kiwi');
      expect(canonicalStoreName('kiwi'), 'Kiwi');
    });

    test('matches known chains regardless of the source\'s casing', () {
      expect(canonicalStoreName('SPAR'), 'Spar');
      expect(canonicalStoreName('rema 1000'), 'Rema 1000');
    });

    test('title-cases an unrecognized store name as a fallback', () {
      expect(canonicalStoreName('SOME NEW CHAIN'), 'Some New Chain');
    });
  });
}
