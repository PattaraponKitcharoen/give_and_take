import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/listing_model.dart';
import '../../models/match_model.dart';
import '../../repositories/match_repository.dart';
import 'match_state.dart';

/// The "แลกตามความต้องการ" screen: my wants, the switch, and my matches
/// with both items loaded.
class MatchCubit extends Cubit<MatchState> {
  final MatchRepository matchRepository;
  final String userId;

  final List<StreamSubscription> _subs = [];
  final Map<String, ListingModel?> _listings = {};
  List<MatchModel> _rawMatches = [];
  bool _wantsLoaded = false;
  bool _matchesLoaded = false;

  MatchCubit({required this.matchRepository, required this.userId})
      : super(const MatchState()) {
    _subs.add(matchRepository.wantsStream(userId).listen((wants) {
      _wantsLoaded = true;
      _emit(state.copyWith(wants: wants));
    }, onError: _onError));
    _subs.add(matchRepository.matchesStream(userId).listen((matches) {
      _rawMatches = matches;
      _resolveListings();
    }, onError: _onError));
    _subs.add(matchRepository.matchEnabledStream(userId).listen(
        (enabled) => _emit(state.copyWith(enabled: enabled)),
        onError: _onError));
    // No rescan here: the server already matches every new listing and
    // want as it is written, so opening the screen just shows the results.
  }

  void _emit(MatchState next) {
    if (isClosed) return;
    emit(next.copyWith(loading: !(_wantsLoaded && _matchesLoaded)));
  }

  void _onError(Object e) {
    // Show what we have instead of spinning forever.
    _wantsLoaded = true;
    _matchesLoaded = true;
    _emit(state.copyWith(message: 'โหลดข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง'));
  }

  Future<void> _resolveListings() async {
    final missing = <String>{
      for (final m in _rawMatches) ...[m.myListingId, m.theirListingId]
    }.where((id) => !_listings.containsKey(id));
    await Future.wait(missing.map((id) async {
      try {
        _listings[id] = await matchRepository.getListing(id);
      } catch (_) {
        _listings[id] = null;
      }
    }));
    _matchesLoaded = true;
    bool usable(ListingModel? l) => l != null && l.status == 'active';
    final ready = _rawMatches
        .map((m) => m.withListings(
            _listings[m.myListingId], _listings[m.theirListingId]))
        .where((m) => usable(m.myListing) && usable(m.theirListing))
        .toList()
      // New ones first, then the closest fit.
      ..sort((a, b) => a.seen != b.seen
          ? (a.seen ? 1 : -1)
          : b.score.compareTo(a.score));
    _emit(state.copyWith(matches: ready));
  }

  /// Returns false (with a message) when the want wasn't added.
  Future<bool> addWant(String text) async {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (t.length > 120) {
      _emit(state.copyWith(message: 'พิมพ์ได้ไม่เกิน 120 ตัวอักษร'));
      return false;
    }
    if (state.wants.length >= MatchRepository.maxWants) {
      _emit(state.copyWith(
          message:
              'เพิ่มได้สูงสุด ${MatchRepository.maxWants} รายการ ลบอันเก่าก่อนนะ'));
      return false;
    }
    try {
      await matchRepository.addWant(userId, t);
      return true;
    } catch (_) {
      _emit(state.copyWith(message: 'เพิ่มไม่สำเร็จ ลองใหม่อีกครั้ง'));
      return false;
    }
  }

  Future<void> deleteWant(String wantId) async {
    try {
      await matchRepository.deleteWant(wantId);
    } catch (_) {
      _emit(state.copyWith(message: 'ลบไม่สำเร็จ ลองใหม่อีกครั้ง'));
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _emit(state.copyWith(enabled: enabled));
    try {
      await matchRepository.setMatchEnabled(userId, enabled);
      if (enabled) await rescan();
    } catch (_) {
      _emit(state.copyWith(
          enabled: !enabled, message: 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง'));
    }
  }

  /// Looks again on the server (pull-to-refresh, or turning matching back
  /// on). Limited server-side to once an hour per user.
  Future<void> rescan() async {
    if (state.rescanning) return;
    _emit(state.copyWith(rescanning: true));
    String? message;
    try {
      final waitMinutes = await matchRepository.rescan();
      if (waitMinutes != null) {
        message =
            'ระบบหาคู่ให้อัตโนมัติอยู่แล้ว ค้นหาซ้ำได้อีกครั้งในอีก $waitMinutes นาที';
      }
    } catch (_) {
      message = 'ค้นหาไม่สำเร็จ ลองใหม่อีกครั้ง';
    }
    _emit(state.copyWith(rescanning: false, message: message));
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    // Matches stay marked "ใหม่" while the screen is open, and count as
    // seen once the user leaves it.
    final unseen = state.matches.where((m) => !m.seen).map((m) => m.id);
    if (unseen.isNotEmpty) {
      matchRepository.markSeen(unseen.toList(), userId).ignore();
    }
    return super.close();
  }
}
