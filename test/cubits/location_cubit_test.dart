import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:give_and_take/cubits/location/location_cubit.dart';
import 'package:give_and_take/models/place_location.dart';
import 'package:give_and_take/repositories/auth_repository.dart';
import 'package:give_and_take/repositories/location_repository.dart';
import 'package:give_and_take/repositories/user_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUser extends Mock implements User {}

Position fix(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026),
      accuracy: 50,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  late MockLocationRepository loc;
  late MockUserRepository users;
  late MockAuthRepository auth;
  late StreamController<Position> moves;

  setUpAll(() =>
      registerFallbackValue(const PlaceLocation(latitude: 0, longitude: 0)));

  setUp(() {
    loc = MockLocationRepository();
    users = MockUserRepository();
    auth = MockAuthRepository();
    moves = StreamController<Position>();
    final me = MockUser();
    when(() => me.uid).thenReturn('me');
    when(() => auth.currentUser).thenReturn(me);
    when(() => loc.positionStream()).thenAnswer((_) => moves.stream);
    when(() => loc.describe(any(), any())).thenAnswer((inv) async =>
        PlaceLocation.coarse(inv.positionalArguments[0] as double,
            inv.positionalArguments[1] as double,
            district: 'หาดใหญ่', province: 'สงขลา'));
    when(() => users.updateUserLocation(any(), any())).thenAnswer((_) async {});
  });

  // Not awaited: close() never completes if nothing listened to it.
  tearDown(() => moves.close().ignore());

  LocationCubit build() => LocationCubit(
      locationRepository: loc, userRepository: users, authRepository: auth);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('refresh finds the place, saves a coarse copy and keeps following',
      () async {
    when(() => loc.currentPosition(askPermission: true))
        .thenAnswer((_) async => fix(7.008634, 100.474712));
    final cubit = build();
    await cubit.refresh(askPermission: true);
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.location?.latitude, 7.01);
    expect(cubit.state.location?.displayName, 'หาดใหญ่, สงขลา');
    final saved = verify(() => users.updateUserLocation('me', captureAny()))
        .captured
        .single as PlaceLocation;
    expect(saved.latitude, 7.01); // never the exact fix
    verify(() => loc.positionStream()).called(1);
    await cubit.close();
  });

  test('moving within the same ~1 km cell: no new lookup, no write', () async {
    when(() => loc.currentPosition(askPermission: any(named: 'askPermission')))
        .thenAnswer((_) async => fix(7.0061, 100.4712));
    final cubit = build();
    await cubit.refresh();
    moves.add(fix(7.0138, 100.4749)); // still 7.01, 100.47
    await settle();
    verify(() => loc.describe(any(), any())).called(1);
    verify(() => users.updateUserLocation(any(), any())).called(1);
    await cubit.close();
  });

  test('moving to another cell updates the place and saves it', () async {
    when(() => loc.currentPosition(askPermission: any(named: 'askPermission')))
        .thenAnswer((_) async => fix(7.01, 100.47));
    final cubit = build();
    await cubit.refresh();
    moves.add(fix(7.20, 100.60));
    await settle();
    await settle();
    expect(cubit.state.location?.latitude, 7.2);
    verify(() => users.updateUserLocation(any(), any())).called(2);
    await cubit.close();
  });

  test('permission denied is reported, nothing saved', () async {
    when(() => loc.currentPosition(askPermission: any(named: 'askPermission')))
        .thenAnswer(
            (_) async => throw const LocationException(LocationIssue.denied));
    final cubit = build();
    await cubit.refresh(askPermission: true);
    expect(cubit.state.issue, LocationIssue.denied);
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.location, isNull);
    verifyNever(() => users.updateUserLocation(any(), any()));
    await cubit.close();
  });

  test('signed out: location still shown, not saved anywhere', () async {
    when(() => auth.currentUser).thenReturn(null);
    when(() => loc.currentPosition(askPermission: any(named: 'askPermission')))
        .thenAnswer((_) async => fix(7.01, 100.47));
    final cubit = build();
    await cubit.refresh();
    expect(cubit.state.location, isNotNull);
    verifyNever(() => users.updateUserLocation(any(), any()));
    await cubit.close();
  });
}
