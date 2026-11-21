import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/models/place_location.dart';

void main() {
  group('PlaceLocation.coarse', () {
    test('snaps to the 0.01° (~1 km) grid', () {
      final p = PlaceLocation.coarse(7.008634, 100.474712);
      expect(p.latitude, 7.01);
      expect(p.longitude, 100.47);
    });

    test('nearby fixes land in the same cell', () {
      final a = PlaceLocation.coarse(7.0061, 100.4712);
      final b = PlaceLocation.coarse(7.0138, 100.4749);
      expect(a.sameCell(b), isTrue);
    });

    test('keeps the names it is given', () {
      final p = PlaceLocation.coarse(7, 100,
          district: 'หาดใหญ่', province: 'สงขลา');
      expect(p.displayName, 'หาดใหญ่, สงขลา');
    });
  });

  group('PlaceLocation map round trip', () {
    test('toMap / fromMap', () {
      const p = PlaceLocation(
          latitude: 7.01,
          longitude: 100.47,
          district: 'หาดใหญ่',
          province: 'สงขลา');
      final back = PlaceLocation.fromMap(p.toMap())!;
      expect(back.latitude, 7.01);
      expect(back.longitude, 100.47);
      expect(back.displayName, 'หาดใหญ่, สงขลา');
    });

    test('rejects malformed data', () {
      expect(PlaceLocation.fromMap(null), isNull);
      expect(PlaceLocation.fromMap({'latitude': 'here', 'longitude': 1}),
          isNull);
    });
  });

  group('distance', () {
    test('Hat Yai to Songkhla is about 25 km', () {
      const hatYai = PlaceLocation(latitude: 7.01, longitude: 100.47);
      const songkhla = PlaceLocation(latitude: 7.20, longitude: 100.60);
      final km = hatYai.distanceKmTo(songkhla);
      expect(km, greaterThan(20));
      expect(km, lessThan(30));
    });

    test('formatDistance never claims more precision than the 1 km grid', () {
      expect(PlaceLocation.formatDistance(0), '< 1 กม.');
      expect(PlaceLocation.formatDistance(0.9), '< 1 กม.');
      expect(PlaceLocation.formatDistance(1.24), '~1.2 กม.');
      expect(PlaceLocation.formatDistance(24.6), '~25 กม.');
    });
  });
}
