import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/utils/aisle_order.dart';

void main() {
  group('aisleRank', () {
    test('orders produce before dairy before frozen before non-food', () {
      final produce = aisleRank('Frukt & grønt');
      final dairy = aisleRank('Meieri');
      final frozen = aisleRank('Frost');
      final nonFood = aisleRank('Non-food');

      expect(produce, lessThan(dairy));
      expect(dairy, lessThan(frozen));
      expect(frozen, lessThan(nonFood));
    });

    test('matches regardless of casing', () {
      expect(aisleRank('meieri'), aisleRank('MEIERI'));
    });

    test('an unrecognized category name sorts after every known aisle', () {
      final unknownRank = aisleRank('Diverse');
      expect(unknownRank, greaterThan(aisleRank('Non-food')));
    });

    test('a null category name sorts after every known aisle too', () {
      final nullRank = aisleRank(null);
      expect(nullRank, greaterThan(aisleRank('Non-food')));
    });

    test('matches real item names directly, not just department names', () {
      // The whole point: there's no user-authored category to read a
      // department from anymore, so this has to work off names like these.
      final produce = aisleRank('Bananer');
      final dairy = aisleRank('Melk');
      final meat = aisleRank('Kjøttdeig');
      final nonFood = aisleRank('Oppvasktabletter');

      expect(produce, lessThan(dairy));
      expect(dairy, lessThan(meat));
      expect(meat, lessThan(nonFood));
    });

    test('matches a plural item name from its singular stem', () {
      expect(aisleRank('Poteter'), lessThan(aisleRank('Diverse')));
      expect(aisleRank('Epler'), lessThan(aisleRank('Diverse')));
    });
  });

  group('aisleGroupLabels', () {
    test('is a fixed, non-empty list usable for mapping a store layout', () {
      expect(aisleGroupLabels, isNotEmpty);
      expect(aisleGroupLabels, contains('Frukt & grønt'));
      expect(aisleGroupLabels, contains('Non-food'));
    });
  });
}
