import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/store.dart';
import '../models/store_location.dart';

/// Finds real, physical grocery store branches near a location, using
/// OpenStreetMap's free Overpass API — no key required, unlike Google
/// Places or Kassalapp's store data. Deliberately not Kassalapp: see the
/// project's data-sourcing notes on why that dependency stays narrowly
/// scoped to product/price lookups only, not something core features like
/// this lean on further.
///
/// Overpass is free public infrastructure with no SLA — it can be slow,
/// rate-limited, or reject requests from certain networks (observed: a
/// blanket 406 from a cloud/datacenter IP during development). Failures are
/// swallowed and return an empty list rather than throwing, same as the
/// other third-party-backed services in this app.
class StoreLocatorService {
  StoreLocatorService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://overpass-api.de/api/interpreter';

  final http.Client _client;
  final String _baseUrl;

  Future<List<StoreLocation>> findNearby(
    double latitude,
    double longitude, {
    double radiusMeters = 3000,
  }) async {
    final radius = radiusMeters.round();
    final query = '[out:json][timeout:25];'
        '(node["shop"="supermarket"](around:$radius,$latitude,$longitude);'
        'node["shop"="convenience"](around:$radius,$latitude,$longitude););'
        'out body;';

    try {
      final response = await _client
          .post(Uri.parse(_baseUrl), body: {'data': query})
          .timeout(const Duration(seconds: 15));
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
