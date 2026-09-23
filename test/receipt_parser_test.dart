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

    test('skips a discount or bottle-deposit refund line instead of adding it as a positive-priced item', () {
      const raw = '''
Cola 1,5l                  32,90
Rabatt                     -5,00
Pant                       -2,00
''';

      final items = ReceiptParser.parse(raw);

      expect(items, hasLength(1));
      expect(items[0].name, 'Cola 1,5l');
      expect(items[0].price, 32.90);
    });

    test('does not let a card-terminal AID/reference number become an absurd item price', () {
      // A real Biltema receipt (any store paid by card prints the same
      // kind of footer) that previously produced a "5.78e+22 kr" total.
      const raw = '''
Biltema Norge avd 223 Fredrikstad
Foretaksregisteret NO. 882692302 MVA
Åpningstider: 7-21 (9-19) Tlf: 22 22 20 22

SALGSKVITTERING

Butikknr.                    223
Butikknavn      Biltema Norge As
Kvitt. 660939    19.09.2026 15:26:40
Term. nr. 204
Operatørnavn Florentina
Herav mva 147.76         Ant. varer 3

850478 TOALETTPAPIR. 530 M. 24-PK.
1 * 99.90                        99.90
84298 PAPIR TIL AIRFRYER. 50 STK.
1 * 39.90                        39.90
14972 VEKTSTANGSETT. 20.5 KG
1 * 599.00                      599.00

TOTALT Å BETALE                 738.80

BANK                            738.80

Bax: 40081437-369543
19/09/2026 15:26          Overf.:434
BankAxept Contactless   ********3330-0
AID: D5780000210100200000001
Ref.: 269718 062455 KC1 TVR:0000008000
Resp.: 00
GODKJENT

0223020 4190926 01667138
''';

      final items = ReceiptParser.parse(raw);

      // The three real products - nothing derived from the AID/Ref/barcode
      // noise, and no price anywhere near the "5.78e+22" it used to produce.
      expect(items, hasLength(3));
      expect(items.map((i) => i.price), everyElement(lessThan(1000)));
      expect(items[0].price, 99.90);
      expect(items[1].price, 39.90);
      expect(items[2].price, 599.00);
    });
  });

  group('ReceiptParser.detectStore', () {
    test('recognizes the chain name printed in a real receipt header', () {
      const raw = '''
KIWI STORGATA
Org.nr 123 456 789
Egg 12pk                   45,90
''';
      expect(ReceiptParser.detectStore(raw)!.name, 'Kiwi');
    });

    test('distinguishes between Coop sub-brands rather than just matching "Coop"', () {
      expect(ReceiptParser.detectStore('COOP EXTRA SAGENE\nMelk 24,90')!.name, 'Coop Extra');
      expect(ReceiptParser.detectStore('COOP MEGA STORO\nMelk 24,90')!.name, 'Coop Mega');
    });

    test('is not case-sensitive', () {
      expect(ReceiptParser.detectStore('rema 1000 sentrum\nBrød 32,90')!.name, 'Rema 1000');
    });

    test('never detects "Annet" — returns null when nothing matches', () {
      expect(ReceiptParser.detectStore('IKEA FAMILY\nBillys hylle 299'), isNull);
    });
  });
}
