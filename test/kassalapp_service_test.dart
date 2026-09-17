import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/services/kassalapp_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('KassalappService', () {
    test('parses products including price, store and weight', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/products');
        expect(request.url.queryParameters['search'], 'lettmelk');
        expect(request.headers['Authorization'], 'Bearer test-key');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'name': 'Tine Lettmelk 1,0% fett 1l',
                'brand': 'TINE',
                'image': 'https://example.com/melk.png',
                'weight': 1,
                'weight_unit': 'l',
                'current_price': 26.5,
                'store': {'name': 'Coop', 'code': 'COOP_NO'},
              },
            ],
          }),
          200,
        );
      });
      final service = KassalappService(client: client, apiKey: 'test-key');

      final results = await service.search('lettmelk');

      expect(results, hasLength(1));
      expect(results.first.name, 'Tine Lettmelk 1,0% fett 1l');
      expect(results.first.brand, 'TINE');
      expect(results.first.quantity, '1 l');
      expect(results.first.price, 26.5);
      expect(results.first.storeName, 'Coop');
    });

    test('sorts results cheapest-first, with unknown prices last', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['size'], '30');
        return http.Response(
          jsonEncode({
            'data': [
              {'name': 'Lettmelk Joker', 'current_price': 22.9, 'store': {'name': 'Joker'}},
              {'name': 'Lettmelk Spar', 'current_price': 17.5, 'store': {'name': 'SPAR'}},
              {'name': 'Lettmelk uten pris', 'store': {'name': 'Meny'}},
              {'name': 'Lettmelk Coop', 'current_price': 17.9, 'store': {'name': 'Coop'}},
            ],
          }),
          200,
        );
      });
      final service = KassalappService(client: client, apiKey: 'test-key');

      final results = await service.search('lettmelk');

      expect(results.map((r) => r.storeName), ['SPAR', 'Coop', 'Joker', 'Meny']);
    });

    test('filters out non-grocery/wholesale vendors like Engrosnett', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'name': 'Tine Ekstra Lett Melk 1l', 'current_price': 22.92, 'store': {'name': 'Engrosnett'}},
              {'name': 'Tine Ekstra Lett Melk 1l', 'current_price': 24.9, 'store': {'name': 'Kiwi'}},
            ],
          }),
          200,
        );
      });
      final service = KassalappService(client: client, apiKey: 'test-key');

      final results = await service.search('ekstra lett melk');

      expect(results, hasLength(1));
      expect(results.first.storeName, 'Kiwi');
    });

    test('handles a product with no weight or price, kept when its store is recognized', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'name': 'Ukjent produkt', 'brand': null, 'current_price': null, 'store': {'name': 'Meny'}},
            ],
          }),
          200,
        );
      });
      final service = KassalappService(client: client, apiKey: 'test-key');

      final results = await service.search('ukjent');

      expect(results, hasLength(1));
      expect(results.first.quantity, isNull);
      expect(results.first.price, isNull);
    });

    test('excludes a product with no store info at all', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'name': 'Uten butikk', 'current_price': 10},
            ],
          }),
          200,
        );
      });
      final service = KassalappService(client: client, apiKey: 'test-key');

      expect(await service.search('uten butikk'), isEmpty);
    });

    test('throws on a non-200 response', () async {
      final client = MockClient((request) async => http.Response('nope', 401));
      final service = KassalappService(client: client, apiKey: 'bad-key');

      expect(() => service.search('melk'), throwsA(isA<KassalappException>()));
    });

    test('returns an empty list for a blank query without calling the network', () async {
      var wasCalled = false;
      final client = MockClient((request) async {
        wasCalled = true;
        return http.Response('{}', 200);
      });
      final service = KassalappService(client: client, apiKey: 'test-key');

      expect(await service.search('  '), isEmpty);
      expect(wasCalled, isFalse);
    });
  });
}
