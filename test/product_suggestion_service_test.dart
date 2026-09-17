import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/services/product_suggestion_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ProductSuggestionService', () {
    test('parses matching products with a name and image, and filters to Norway', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['search_terms'], 'melk');
        expect(request.url.queryParameters['tag_0'], 'norway');
        return http.Response(
          jsonEncode({
            'products': [
              {
                'product_name': 'Lettmelk 1,0%',
                'brands': 'Tine, Norge',
                'image_small_url': 'https://example.com/melk1.jpg',
                'quantity': '1000 ml',
              },
              {
                'product_name': 'Skummet melk',
                'brands': 'Q-meieriene',
                'image_small_url': 'https://example.com/melk2.jpg',
              },
            ],
          }),
          200,
        );
      });
      final service = ProductSuggestionService(client: client);

      final results = await service.search('melk');

      expect(results, hasLength(2));
      expect(results[0].name, 'Lettmelk 1,0%');
      expect(results[0].brand, 'Tine');
      expect(results[0].imageUrl, 'https://example.com/melk1.jpg');
      expect(results[0].quantity, '1000 ml');
      expect(results[1].imageUrl, 'https://example.com/melk2.jpg');
    });

    test('skips products with no name', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'products': [
              {'product_name': '', 'brands': 'Ukjent'},
              {'product_name': 'Helmelk', 'brands': 'Tine'},
            ],
          }),
          200,
        );
      });
      final service = ProductSuggestionService(client: client);

      final results = await service.search('melk');

      expect(results, hasLength(1));
      expect(results.first.name, 'Helmelk');
    });

    test('sorts entries with a known pack size before entries without one', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'products': [
              {'product_name': 'Lettmelk 1,0% fett', 'brands': 'TINE'},
              {'product_name': 'Lettmelk 0,5% fett', 'brands': 'TINE', 'quantity': '1000 ml'},
              {'product_name': 'Lettmelk 0.5%', 'brands': 'Q'},
              {'product_name': 'Lettmelk 1,0 % fett', 'brands': 'TINE', 'quantity': '1750 ml'},
            ],
          }),
          200,
        );
      });
      final service = ProductSuggestionService(client: client);

      final results = await service.search('lettmelk');

      expect(results.take(2).map((r) => r.quantity), ['1000 ml', '1750 ml']);
      expect(results.skip(2).map((r) => r.quantity), [null, null]);
    });

    test('returns an empty list for a blank query without calling the network', () async {
      var wasCalled = false;
      final client = MockClient((request) async {
        wasCalled = true;
        return http.Response('{}', 200);
      });
      final service = ProductSuggestionService(client: client);

      final results = await service.search('  ');

      expect(results, isEmpty);
      expect(wasCalled, isFalse);
    });

    test('fails quietly (empty list) on a non-200 response', () async {
      final client = MockClient((request) async => http.Response('error', 500));
      final service = ProductSuggestionService(client: client);

      expect(await service.search('melk'), isEmpty);
    });
  });
}
