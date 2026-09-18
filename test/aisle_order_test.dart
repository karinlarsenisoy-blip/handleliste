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
  });
}
