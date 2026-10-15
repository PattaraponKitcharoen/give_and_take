import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/match_repository.dart';

/// Number of matches the user hasn't looked at yet, for the Home banner.
class MatchBadgeCubit extends Cubit<int> {
  StreamSubscription? _sub;

  MatchBadgeCubit({required MatchRepository matchRepository, required String userId})
      : super(0) {
    if (userId.isEmpty) return;
    _sub = matchRepository.matchesStream(userId).listen(
          (matches) => emit(matches.where((m) => !m.seen).length),
          onError: (_) {},
        );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
