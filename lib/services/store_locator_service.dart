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

  /// Tries [_fetchOnce] up to twice — Overpass is free, best-effort
  /// infrastructure with no SLA, and observed firsthand to sometimes fail
  /// outright (timeout/non-200) only to succeed in well under a second on
  /// an immediate retry. One retry turns most of that transient flakiness
  /// into a slightly slower success instead of a false "no stores nearby".
  Future<List<StoreLocation>> findNearby(
    double latitude,
    double longitude, {
    double radiusMeters = 3000,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await _fetchOnce(latitude, longitude, radiusMeters);
      if (result != null) return result;
    }
    return [];
  }

  /// Returns null if this attempt failed outright (network error, timeout,
  /// non-200) — as opposed to a genuinely empty result, which is a real
  /// list (possibly empty) and shouldn't trigger a retry.
  Future<List<StoreLocation>?> _fetchOnce(double latitude, double longitude, double radiusMeters) async {
    final radius = radiusMeters.round();
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'lat': '$latitude',
      'lon': '$longitude',
      'radius': '$radius',
    });

    try {
      // Longer than the proxy's own worst case (two 15s Overpass attempts
      // plus cold-start/network overhead) so a slow-but-working response
      // isn't mistaken for a failure — that mismatch was the cause of
      // "Fant ingen butikker" showing up even when the proxy would have
      // succeeded a few seconds later.
      final response = await _client.get(uri).timeout(const Duration(seconds: 50));
      if (response.statusCode != 200) return null;

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
      return null;
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
