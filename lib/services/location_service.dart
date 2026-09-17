import 'package:geolocator/geolocator.dart';

/// Wraps device geolocation for "stores near me" — handles the permission
/// dance and returns null on any failure (service disabled, permission
/// denied, timeout) rather than throwing, so callers can just show a
/// friendly "couldn't get your location" state instead of a crash.
class LocationService {
  Future<({double latitude, double longitude})?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 15));

      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
    }
  }
}
