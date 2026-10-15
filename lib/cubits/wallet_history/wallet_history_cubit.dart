import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/wallet_entry.dart';
import '../../repositories/wallet_repository.dart';
import 'wallet_history_state.dart';

/// Streams the user's wallet movements and attaches the deal each one
/// came from. Rows show immediately; deal details fill in once resolved.
class WalletHistoryCubit extends Cubit<WalletHistoryState> {
  final WalletRepository walletRepository;
  final String userId;

  StreamSubscription? _sub;
  // Keyed by reference_id: one deal has several entries (lock, release,
  // refund), and a new entry re-emits the whole list.
  final Map<String, WalletDeal?> _deals = {};
  List<WalletEntry> _entries = [];

  WalletHistoryCubit({required this.walletRepository, required this.userId})
      : super(WalletHistoryLoading()) {
    _sub = walletRepository.getWalletHistoryStream(userId).listen(
      (snapshot) {
        _entries = snapshot.docs.map(WalletEntry.fromDoc).toList();
        _emit();
        _resolveMissing();
      },
      onError: (e) => emit(WalletHistoryError(e.toString())),
    );
  }

  void _emit() {
    if (isClosed) return;
    emit(WalletHistoryLoaded(_entries
        .map((e) => e.withDeal(_deals[e.referenceId],
            loaded: _deals.containsKey(e.referenceId)))
        .toList()));
  }

  Future<void> _resolveMissing() async {
    final pending = <String, WalletEntry>{};
    for (final e in _entries) {
      if (e.referenceId.isNotEmpty && !_deals.containsKey(e.referenceId)) {
        pending[e.referenceId] = e;
      }
    }
    if (pending.isEmpty) return;
    await Future.wait(pending.entries.map((p) async {
      _deals[p.key] = await walletRepository.resolveDeal(p.value, userId);
    }));
    _emit();
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
