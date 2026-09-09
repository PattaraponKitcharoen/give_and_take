import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/transaction_repository.dart';
import '../../repositories/user_repository.dart';
import 'transaction_state.dart';

class TransactionCubit extends Cubit<TransactionState> {
  final TransactionRepository _repository;
  final UserRepository _userRepository;
  StreamSubscription? _txSubscription;
  String? currentOfferId;

  TransactionCubit({required TransactionRepository repository, required UserRepository userRepository})
      : _repository = repository,
        _userRepository = userRepository,
        super(TransactionInitial());

  void listenToTransaction(String transactionId) {
    emit(TransactionLoading());
    _txSubscription?.cancel();
    _txSubscription = _repository.getTransactionStream(transactionId).listen(
      (transaction) {
        if (state is! TransactionSubmitting) {
          emit(TransactionLoaded(transaction));
        }
      },
      onError: (error) {
        emit(TransactionError(error.toString()));
      },
    );
  }

  void listenToTransactionByOfferId(String offerId) {
    if (currentOfferId == offerId) return;
    currentOfferId = offerId;
    
    emit(TransactionLoading());
    _txSubscription?.cancel();
    _txSubscription = _repository.getTransactionByOfferIdStream(offerId).listen(
      (transaction) {
        if (transaction != null) {
          if (state is! TransactionSubmitting) {
            emit(TransactionLoaded(transaction));
          }
        }
      },
      onError: (error) {
        emit(TransactionError(error.toString()));
      },
    );
  }

  Future<void> confirmTransaction(String transactionId, String userId, String inputOtp) async {
    emit(TransactionSubmitting());
    try {
      final result = await _repository.confirmTransaction(transactionId, userId, inputOtp);
      bool isCompleted = result['isCompleted'];
      emit(TransactionSuccess(isCompleted ? 'ยืนยันรหัสสำเร็จ ดีลจบสมบูรณ์' : 'ยืนยันรหัสสำเร็จ รออีกฝ่ายยืนยัน', isCompleted: isCompleted));
    } catch (e) {
      emit(TransactionError('เกิดข้อผิดพลาด: $e'));
    }
  }

  Future<void> confirmTransactionByOfferId(String offerId, String userId, String inputOtp) async {
    emit(TransactionSubmitting());
    try {
      final result = await _repository.confirmTransactionByOfferId(offerId, userId, inputOtp);
      bool isCompleted = result['isCompleted'];
      emit(TransactionSuccess(isCompleted ? 'ยืนยันรหัสสำเร็จ ดีลจบสมบูรณ์' : 'ยืนยันรหัสสำเร็จ รออีกฝ่ายยืนยัน', isCompleted: isCompleted));
    } catch (e) {
      emit(TransactionError('เกิดข้อผิดพลาด: $e'));
    }
  }

  Future<void> cancelAcceptedDeal(String offerId, String reason, String currentUserId, String roomId) async {
    emit(TransactionSubmitting());
    try {
      final user = await _userRepository.getUser(currentUserId);
      final userName = user.name;
      await _repository.cancelAcceptedDeal(offerId, reason, currentUserId, userName, roomId);
      emit(const TransactionSuccess('ยกเลิกการแลกเปลี่ยนสำเร็จ', isCompleted: false));
    } catch (e) {
      emit(TransactionError('เกิดข้อผิดพลาด: $e'));
    }
  }

  @override
  Future<void> close() {
    _txSubscription?.cancel();
    return super.close();
  }
}
