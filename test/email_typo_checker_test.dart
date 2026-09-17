import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/utils/email_typo_checker.dart';

void main() {
  group('suggestEmailCorrection', () {
    test('suggests a fix for a one-letter-missing common domain', () {
      expect(suggestEmailCorrection('karin@gmai.com'), 'karin@gmail.com');
    });

    test('suggests a fix for a common transposition typo', () {
      expect(suggestEmailCorrection('karin@gmial.com'), 'karin@gmail.com');
    });

    test('returns null for an already-correct common domain', () {
      expect(suggestEmailCorrection('karin@gmail.com'), isNull);
    });

    test('returns null for an unrecognized but plausible domain', () {
      expect(suggestEmailCorrection('karin@integrasjonspartner.no'), isNull);
    });

    test('returns null when there is no @ at all', () {
      expect(suggestEmailCorrection('not-an-email'), isNull);
    });

    test('returns null when the domain is too different to guess confidently', () {
      expect(suggestEmailCorrection('karin@xyz.com'), isNull);
    });
  });
}
