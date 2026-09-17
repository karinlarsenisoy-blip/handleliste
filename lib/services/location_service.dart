import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationFailureReason { permissionDenied, timeout, unknown }

class LocationResult {
  LocationResult.success(this.latitude, this.longitude)
      : failureReason = null,
        debugMessage = null;

  LocationResult.failure(this.failureReason, {this.debugMessage})
      : latitude = null,
        longitude = null;

  final double? latitude;
  final double? longitude;
  final LocationFailureReason? failureReason;

  /// The raw underlying error, when the failure wasn't a clean permission
  /// denial — shown to the user for an unexpected failure so a report back
  /// to us actually says what broke, instead of just "it didn't work".
  final String? debugMessage;

  bool get isSuccess => failureReason == null;
}

/// Wraps device geolocation for "stores near me". Deliberately does NOT
/// check `Geolocator.isLocationServiceEnabled()` first — that check has
/// been unreliable on web (observed returning as if disabled even with
/// permission granted) and isn't actually needed: if location is genuinely
/// unavailable, `getCurrentPosition` fails on its own with a clear error.
class LocationService {
  Future<LocationResult> getCurrentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return LocationResult.failure(LocationFailureReason.permissionDenied);
      }

      final position = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 15));
      return LocationResult.success(position.latitude, position.longitude);
    } on TimeoutException {
      return LocationResult.failure(LocationFailureReason.timeout);
    } catch (e) {
      return LocationResult.failure(LocationFailureReason.unknown, debugMessage: e.toString());
    }
  }
}
