import 'dart:math' as math;

/// A coarse place: coordinates rounded to ~1 km plus the district/province
/// shown to people. Used for a listing's pickup point and the user's own
/// position. Never stores an exact position, so a listing can't reveal
/// someone's room or house.
class PlaceLocation {
  /// 0.01° ≈ 1.1 km north-south (and ~1.1 km east-west near the equator).
  static const double gridDegrees = 0.01;

  final double latitude;
  final double longitude;
  final String district;
  final String province;

  const PlaceLocation({
    required this.latitude,
    required this.longitude,
    this.district = '',
    this.province = '',
  });

  /// Snaps a raw GPS fix to the ~1 km grid.
  factory PlaceLocation.coarse(double lat, double lng,
      {String district = '', String province = ''}) {
    double snap(double v) =>
        (v / gridDegrees).roundToDouble() * gridDegrees;
    return PlaceLocation(
      // Keep the stored value tidy (no 7.010000000000001).
      latitude: double.parse(snap(lat).toStringAsFixed(2)),
      longitude: double.parse(snap(lng).toStringAsFixed(2)),
      district: district,
      province: province,
    );
  }

  static PlaceLocation? fromMap(dynamic data) {
    if (data is! Map) return null;
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat is! num || lng is! num) return null;
    return PlaceLocation(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      district: data['district'] ?? '',
      province: data['province'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'district': district,
        'province': province,
        'display_name': displayName,
      };

  String get displayName => [district, province]
      .where((s) => s.isNotEmpty)
      .join(', ');

  bool sameCell(PlaceLocation other) =>
      latitude == other.latitude && longitude == other.longitude;

  /// Great-circle distance in km.
  double distanceKmTo(PlaceLocation other) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  /// "~1.2 กม." — both points are rounded to ~1 km, so anything closer
  /// than that is shown as "< 1 กม." rather than a fake-precise number.
  static String formatDistance(double km) {
    if (km < 1) return '< 1 กม.';
    if (km < 10) return '~${km.toStringAsFixed(1)} กม.';
    return '~${km.round()} กม.';
  }
}
