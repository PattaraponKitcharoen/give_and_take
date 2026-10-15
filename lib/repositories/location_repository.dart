import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place_location.dart';

enum LocationIssue { serviceOff, denied, deniedForever, failed }

class LocationException implements Exception {
  final LocationIssue issue;
  const LocationException(this.issue);
}

/// GPS + reverse geocoding. Everything it returns is already rounded to
/// ~1 km (see [PlaceLocation.coarse]).
class LocationRepository {
  // Medium accuracy is plenty once rounded to 1 km, and much lighter on
  // the battery than high.
  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 500, // metres moved before the stream reports again
  );

  /// Throws [LocationException] when location can't be used. Only shows
  /// the system permission prompt when [askPermission] is true.
  Future<Position> currentPosition({bool askPermission = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationIssue.serviceOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && askPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationIssue.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationIssue.denied);
    }
    try {
      return await Geolocator.getCurrentPosition(locationSettings: _settings);
    } catch (_) {
      throw const LocationException(LocationIssue.failed);
    }
  }

  /// Position updates while the app is in use, after moving ~500 m.
  Stream<Position> positionStream() =>
      Geolocator.getPositionStream(locationSettings: _settings);

  /// Rounds the fix and looks up its district/province. A failed lookup
  /// keeps the coordinates with empty names rather than failing.
  Future<PlaceLocation> describe(double lat, double lng) async {
    final cell = PlaceLocation.coarse(lat, lng);
    try {
      // Geocode the cell centre, not the exact fix, so nothing finer than
      // the rounded point is ever used.
      // Thai names regardless of the phone's language, like the rest of
      // the app.
      await setLocaleIdentifier('th_TH');
      final marks =
          await placemarkFromCoordinates(cell.latitude, cell.longitude);
      if (marks.isEmpty) return cell;
      final place = marks.first;
      // Strip the admin prefixes/suffixes ("อำเภอ", "Amphoe ... District")
      // in case the lookup still answers in English.
      final district = (place.subAdministrativeArea ?? '')
          .replaceAll('อำเภอ', '')
          .replaceAll('เขต', '')
          .replaceAll(RegExp(r'^(อ|ข)\.\s*|^Amphoe\s+|\s+District$'), '')
          .trim();
      final province = (place.administrativeArea ?? '')
          .replaceAll('จังหวัด', '')
          .replaceAll(RegExp(r'^จ\.\s*|^Chang Wat\s+'), '')
          .trim();
      return PlaceLocation.coarse(lat, lng,
          district: district, province: province);
    } catch (_) {
      return cell;
    }
  }
}
