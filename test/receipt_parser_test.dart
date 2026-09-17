import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/services/receipt_parser.dart';

void main() {
  group('ReceiptParser', () {
    test('parses a typical single-line-per-item receipt', () {
      const raw = '''
Tine Lettmelk 1l           24,90
Kneippbrød grovt           32,90
Bananer                    16,58
SUM                        74,38
Bankaxept                  74,38
''';

      final items = ReceiptParser.parse(raw);

      expect(items, hasLength(3));
      expect(items[0].name, 'Tine Lettmelk 1l');
      expect(items[0].price, 24.90);
      expect(items[1].name, 'Kneippbrød grovt');
      expect(items[2].name, 'Bananer');
      expect(items[2].price, 16.58);
    });

    test('merges a two-line "name then qty x price" item onto the name', () {
      const raw = '''
Yoghurt Jordbær
3 stk x 12,50               37,50
''';

      final items = ReceiptParser.parse(raw);

      expect(items, hasLength(1));
      expect(items[0].name, 'Yoghurt Jordbær');
      expect(items[0].price, 37.50);
    });

    test('skips receipt footer/header noise', () {
      const raw = '''
KIWI STORGATA
Org.nr 123 456 789
Kvittering 4821
Egg 12pk                   45,90
Totalt                     45,90
Vipps                      45,90
Takk for handelen!
''';

      final items = ReceiptParser.parse(raw);

      expect(items, hasLength(1));
      expect(items[0].name, 'Egg 12pk');
    });

    test('returns an empty list for text with no price-shaped lines', () {
      final items = ReceiptParser.parse('bare litt tilfeldig tekst\nuten priser i det hele tatt');
      expect(items, isEmpty);
    });

    test('handles a comma or a dot as the decimal separator', () {
      final items = ReceiptParser.parse('Kaffe                     89.90\nTe                        45,00');
      expect(items[0].price, 89.90);
      expect(items[1].price, 45.00);
    });

    test('handles a whole-number price written as "<n> kr"', () {
      final items = ReceiptParser.parse('2 bananer 30 kr');
      expect(items, hasLength(1));
      expect(items[0].name, '2 bananer');
      expect(items[0].price, 30);
    });

    test('handles a whole-number price with no currency marker at all', () {
      final items = ReceiptParser.parse('Brød 32');
      expect(items, hasLength(1));
      expect(items[0].name, 'Brød');
      expect(items[0].price, 32);
    });
  });
}
