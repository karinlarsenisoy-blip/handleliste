import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/utils/distance.dart';

void main() {
  group('haversineMeters', () {
    test('returns 0 for the same point', () {
      expect(haversineMeters(59.9139, 10.7522, 59.9139, 10.7522), 0);
    });

    test('one degree of latitude is roughly 111 km', () {
      final distance = haversineMeters(59.0, 10.0, 60.0, 10.0);
      expect(distance, closeTo(111195, 500));
    });

    test('matches the known straight-line distance between Oslo and Bergen', () {
      // Oslo (59.9139, 10.7522) to Bergen (60.3913, 5.3221) is ~305 km.
      final distance = haversineMeters(59.9139, 10.7522, 60.3913, 5.3221);
      expect(distance / 1000, closeTo(305, 5));
    });
  });
}
