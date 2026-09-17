import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/services/store_locator_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('StoreLocatorService', () {
    test('parses known grocery chain branches with brand, name and address', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://overpass-api.de/api/interpreter');
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'lat': 59.914,
                'lon': 10.752,
                'tags': {
                  'shop': 'supermarket',
                  'brand': 'Kiwi',
                  'name': 'Kiwi Grünerløkka',
                  'addr:street': 'Thorvald Meyers gate',
                  'addr:housenumber': '5',
                  'addr:city': 'Oslo',
                },
              },
            ],
          }),
          200,
        );
      });
      final service = StoreLocatorService(client: client);

      final results = await service.findNearby(59.9139, 10.7522);

      expect(results, hasLength(1));
      expect(results.first.chainName, 'Kiwi');
      expect(results.first.name, 'Kiwi Grünerløkka');
      expect(results.first.latitude, 59.914);
      expect(results.first.longitude, 10.752);
      expect(results.first.address, 'Thorvald Meyers gate 5, Oslo');
    });

    test('falls back to the name tag when there is no brand tag', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'lat': 59.9,
                'lon': 10.7,
                'tags': {'shop': 'supermarket', 'name': 'Rema 1000'},
              },
            ],
          }),
          200,
        );
      });
      final service = StoreLocatorService(client: client);

      final results = await service.findNearby(59.9139, 10.7522);

      expect(results.single.chainName, 'Rema 1000');
    });

    test('excludes shops that are not a recognized grocery chain', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'lat': 59.9,
                'lon': 10.7,
                'tags': {'shop': 'supermarket', 'name': 'En helt ukjent kiosk'},
              },
              {
                'lat': 59.91,
                'lon': 10.71,
                'tags': {'shop': 'supermarket', 'brand': 'Kiwi'},
              },
            ],
          }),
          200,
        );
      });
      final service = StoreLocatorService(client: client);

      final results = await service.findNearby(59.9139, 10.7522);

      expect(results, hasLength(1));
      expect(results.single.chainName, 'Kiwi');
    });

    test('skips elements missing coordinates or any name', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'tags': {'shop': 'supermarket', 'brand': 'Kiwi'},
              },
              {
                'lat': 59.9,
                'lon': 10.7,
                'tags': <String, dynamic>{},
              },
            ],
          }),
          200,
        );
      });
      final service = StoreLocatorService(client: client);

      expect(await service.findNearby(59.9139, 10.7522), isEmpty);
    });

    test('returns an empty list on a non-200 response instead of throwing', () async {
      final client = MockClient((request) async => http.Response('error', 500));
      final service = StoreLocatorService(client: client);

      expect(await service.findNearby(59.9139, 10.7522), isEmpty);
    });

    test('returns an empty list if the request throws (e.g. network/blocked)', () async {
      final client = MockClient((request) async => throw Exception('blocked'));
      final service = StoreLocatorService(client: client);

      expect(await service.findNearby(59.9139, 10.7522), isEmpty);
    });
  });
}
