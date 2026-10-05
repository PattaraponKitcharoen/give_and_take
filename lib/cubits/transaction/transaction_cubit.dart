import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/transaction_repository.dart';
import '../../models/transaction_model.dart';
import 'transaction_state.dart';

class TransactionCubit extends Cubit<TransactionState> {
  final TransactionRepository _repository;
  StreamSubscription? _txSubscription;
  String? currentOfferId;
  // Latest snapshot from the active subscription, kept even while a
  // Submitting state suppresses emitting it. Without this, the snapshot that
  // flips the deal to 'completed' lands mid-submit and is dropped, the cubit
  // then parks on TransactionSuccess forever (the doc never changes again),
  // and the offer card's review button — which only renders on
  // TransactionLoaded — never appears.
  TransactionModel? _latest;

  TransactionCubit({required TransactionRepository repository})
      : _repository = repository,
        super(TransactionInitial());

  void listenToTransaction(String transactionId) {
    _latest = null;
    emit(TransactionLoading());
    _txSubscription?.cancel();
    _txSubscription = _repository.getTransactionStream(transactionId).listen(
      (transaction) {
        _latest = transaction;
        if (state is! TransactionSubmitting) {
          emit(TransactionLoaded(transaction));
        }
      },
      onError: (error) {
        emit(TransactionError(error.toString()));
      },
    );
  }

  void listenToTransactionByOfferId(String offerId, String userId) {
    // Only skip when we're already actively subscribed AND successfully
    // loaded for this exact offer — not just because this offerId has
    // been seen before. This cubit is provided once at the app root and
    // lives for the whole session (see main.dart), so a plain "seen it
    // before" guard would let one interrupted or errored attempt for a
    // given offerId permanently block ever retrying it, even after the
    // underlying transaction document becomes available.
    if (currentOfferId == offerId &&
        _txSubscription != null &&
        state is TransactionLoaded) {
      return;
    }
    currentOfferId = offerId;

    _latest = null;
    emit(TransactionLoading());
    _txSubscription?.cancel();
    _txSubscription =
        _repository.getTransactionByOfferIdStream(offerId, userId).listen(
      (transaction) {
        if (transaction != null) {
          _latest = transaction;
          if (state is! TransactionSubmitting) {
            emit(TransactionLoaded(transaction));
          }
        }
      },
      onError: (error) {
        debugPrint('listenToTransactionByOfferId failed: $error');
        emit(TransactionError(error.toString()));
      },
    );
  }

  Future<void> confirmTransaction(
      String transactionId, String userId, String inputOtp) async {
    emit(TransactionSubmitting());
    try {
      final result =
          await _repository.confirmTransaction(transactionId, userId, inputOtp);
      bool isCompleted = result['isCompleted'];
      emit(TransactionSuccess(
          isCompleted
              ? 'ยืนยันรหัสสำเร็จ ดีลจบสมบูรณ์'
              : 'ยืนยันรหัสสำเร็จ รออีกฝ่ายยืนยัน',
          isCompleted: isCompleted));
      _restoreLoaded();
    } catch (e) {
      emit(TransactionError('เกิดข้อผิดพลาด: $e'));
      _restoreLoaded();
    }
  }

  Future<void> confirmTransactionByOfferId(
      String offerId, String userId, String inputOtp) async {
    emit(TransactionSubmitting());
    try {
      final result = await _repository.confirmTransactionByOfferId(
          offerId, userId, inputOtp);
      bool isCompleted = result['isCompleted'];
      emit(TransactionSuccess(
          isCompleted
              ? 'ยืนยันรหัสสำเร็จ ดีลจบสมบูรณ์'
              : 'ยืนยันรหัสสำเร็จ รออีกฝ่ายยืนยัน',
          isCompleted: isCompleted));
      _restoreLoaded();
    } catch (e) {
      // The repository already throws a clean, user-facing message —
      // e.toString() would otherwise re-prefix it with Dart's own
      // "Exception: ", producing a doubled-up "เกิดข้อผิดพลาด: Exception: ...".
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
      _restoreLoaded();
    }
  }

  Future<void> cancelAcceptedDeal(String offerId, String reason,
      String currentUserId, String roomId) async {
    emit(TransactionSubmitting());
    try {
      // The Cloud Function resolves the caller's display name itself now
      // (see functions/index.js#cancelAcceptedTrade), so the extra
      // _userRepository.getUser lookup that used to happen here is gone.
      await _repository.cancelAcceptedDeal(
          offerId, reason, currentUserId, roomId);
      emit(const TransactionSuccess('ยกเลิกการแลกเปลี่ยนสำเร็จ',
          isCompleted: false));
      _restoreLoaded();
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
      _restoreLoaded();
    }
  }

  // Listeners have already seen the Success/Error state emitted just before
  // this (for the snackbar), so hand the builders back the live transaction.
  void _restoreLoaded() {
    final tx = _latest;
    if (tx != null && !isClosed) emit(TransactionLoaded(tx));
  }

  @override
  Future<void> close() {
    _txSubscription?.cancel();
    return super.close();
  }
}
