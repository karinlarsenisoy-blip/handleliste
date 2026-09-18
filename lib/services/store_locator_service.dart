import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/store.dart';
import '../models/store_location.dart';

/// Finds real, physical grocery store branches near a location, using
/// OpenStreetMap data via a small Cloud Function proxy (`nearbyStores`) that
/// queries the free Overpass API on our behalf — no key required, unlike
/// Google Places or Kassalapp's store data. Deliberately not Kassalapp: see
/// the project's data-sourcing notes on why that dependency stays narrowly
/// scoped to product/price lookups only, not something core features like
/// this lean on further.
///
/// Calling Overpass directly from the browser doesn't work: its main
/// instance sends no CORS header for browser requests (confirmed via a
/// `no-cors` probe — the request succeeds, the browser just refuses to hand
/// back the response), and the handful of mirrors that do support CORS
/// either have partial data coverage or are too slow/unreliable for a
/// live UI. The proxy calls Overpass server-to-server, where CORS doesn't
/// apply. Failures are swallowed and return an empty list rather than
/// throwing, same as the other third-party-backed services in this app.
class StoreLocatorService {
  StoreLocatorService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://handleliste-f1659.web.app/api/nearby-stores';

  final http.Client _client;
  final String _baseUrl;

  Future<List<StoreLocation>> findNearby(
    double latitude,
    double longitude, {
    double radiusMeters = 3000,
  }) async {
    final radius = radiusMeters.round();
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'lat': '$latitude',
      'lon': '$longitude',
      'radius': '$radius',
    });

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List<dynamic>?) ?? [];

      final locations = <StoreLocation>[];
      for (final element in elements.cast<Map<String, dynamic>>()) {
        final tags = (element['tags'] as Map<String, dynamic>?) ?? {};
        final rawName = (tags['brand'] as String?) ?? (tags['name'] as String?);
        final lat = element['lat'] as num?;
        final lon = element['lon'] as num?;
        if (rawName == null || lat == null || lon == null) continue;
        if (!isKnownGroceryStoreName(rawName)) continue;

        locations.add(StoreLocation(
          chainName: canonicalStoreName(rawName),
          name: (tags['name'] as String?) ?? canonicalStoreName(rawName),
          latitude: lat.toDouble(),
          longitude: lon.toDouble(),
          address: _formatAddress(tags),
        ));
      }
      return locations;
    } catch (_) {
      return [];
    }
  }

  String? _formatAddress(Map<String, dynamic> tags) {
    final street = tags['addr:street'] as String?;
    final houseNumber = tags['addr:housenumber'] as String?;
    final city = tags['addr:city'] as String?;

    final streetLine = [street, houseNumber].whereType<String>().join(' ');
    final parts = [streetLine, city].where((s) => s != null && s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}
