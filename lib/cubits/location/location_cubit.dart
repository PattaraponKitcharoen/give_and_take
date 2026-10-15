import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/place_location.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/location_repository.dart';
import '../../repositories/user_repository.dart';

class LocationState extends Equatable {
  final PlaceLocation? location; // ~1 km cell, null until known
  final bool loading;
  final LocationIssue? issue;

  const LocationState({this.location, this.loading = false, this.issue});

  LocationState copyWith(
          {PlaceLocation? location, bool? loading, LocationIssue? issue}) =>
      LocationState(
        location: location ?? this.location,
        loading: loading ?? this.loading,
        issue: issue,
      );

  @override
  List<Object?> get props => [location, loading, issue];
}

/// The user's own coarse position while the app is open: read on start and
/// on returning to the app, then followed with a 500 m distance filter.
/// Kept on the device for distance sorting; the user doc gets a ~1 km copy
/// only when the user moves into a different cell.
class LocationCubit extends Cubit<LocationState> {
  final LocationRepository _locationRepository;
  final UserRepository _userRepository;
  final AuthRepository _authRepository;

  StreamSubscription? _positionSub;
  AppLifecycleListener? _lifecycle;
  bool _started = false;

  LocationCubit({
    required LocationRepository locationRepository,
    required UserRepository userRepository,
    required AuthRepository authRepository,
  })  : _locationRepository = locationRepository,
        _userRepository = userRepository,
        _authRepository = authRepository,
        super(const LocationState());

  /// Called once the user is signed in and on the main screen.
  void start() {
    if (_started) return;
    _started = true;
    _lifecycle = AppLifecycleListener(onResume: () => refresh());
    refresh(askPermission: true);
  }

  /// [askPermission]: show the system prompt if not decided yet — on first
  /// start, or when the user taps the location bar.
  Future<void> refresh({bool askPermission = false}) async {
    if (state.loading) return;
    emit(state.copyWith(loading: true));
    try {
      final pos = await _locationRepository.currentPosition(
          askPermission: askPermission);
      await _apply(pos.latitude, pos.longitude);
      _follow();
    } on LocationException catch (e) {
      if (!isClosed) emit(state.copyWith(loading: false, issue: e.issue));
    }
  }

  void _follow() {
    if (_positionSub != null) return;
    _positionSub = _locationRepository.positionStream().listen(
          (pos) => _apply(pos.latitude, pos.longitude),
          onError: (_) {},
        );
  }

  Future<void> _apply(double lat, double lng) async {
    final cell = PlaceLocation.coarse(lat, lng);
    final current = state.location;
    if (current != null && current.sameCell(cell)) {
      // Same 1 km cell: nothing visible changes, skip geocoding and writes.
      if (!isClosed) emit(state.copyWith(loading: false));
      return;
    }
    final place = await _locationRepository.describe(lat, lng);
    if (isClosed) return;
    emit(LocationState(location: place));
    final uid = _authRepository.currentUser?.uid;
    if (uid != null) {
      _userRepository.updateUserLocation(uid, place).ignore();
    }
  }

  @override
  Future<void> close() {
    _positionSub?.cancel();
    _lifecycle?.dispose();
    return super.close();
  }
}
