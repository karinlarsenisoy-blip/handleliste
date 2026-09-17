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

    test('handles a product with no weight or store', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'name': 'Ukjent produkt', 'brand': null, 'current_price': null},
            ],
          }),
          200,
        );
      });
      final service = KassalappService(client: client, apiKey: 'test-key');

      final results = await service.search('ukjent');

      expect(results.first.quantity, isNull);
      expect(results.first.storeName, isNull);
      expect(results.first.price, isNull);
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
