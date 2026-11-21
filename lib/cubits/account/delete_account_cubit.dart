import 'package:cloud_functions/cloud_functions.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/auth_repository.dart';

enum DeleteAccountStep { idle, working, done, failed }

class DeleteAccountState extends Equatable {
  final DeleteAccountStep step;

  /// Why it failed, ready to show (Thai).
  final String? message;

  const DeleteAccountState(this.step, [this.message]);

  @override
  List<Object?> get props => [step, message];
}

/// Deletes the signed-in account: signs in again (password or Google),
/// then asks the server to delete it. On success the user is signed out,
/// so the app's root goes back to the login screen by itself.
class DeleteAccountCubit extends Cubit<DeleteAccountState> {
  final AuthRepository _authRepository;

  DeleteAccountCubit({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const DeleteAccountState(DeleteAccountStep.idle));

  /// 'password' (ask for it) or 'google.com' (show the picker).
  String? get provider => _authRepository.reauthProvider;

  Future<void> delete({String? password}) async {
    emit(const DeleteAccountState(DeleteAccountStep.working));
    try {
      final confirmed =
          await _authRepository.reauthenticate(password: password);
      if (!confirmed) {
        // Closed the Google picker: back to the form, nothing to report.
        emit(const DeleteAccountState(DeleteAccountStep.idle));
        return;
      }
      await _authRepository.deleteAccount();
      emit(const DeleteAccountState(DeleteAccountStep.done));
    } on FirebaseAuthException catch (e) {
      emit(DeleteAccountState(DeleteAccountStep.failed, _authMessage(e.code)));
    } on FirebaseFunctionsException catch (e) {
      emit(DeleteAccountState(DeleteAccountStep.failed, _serverMessage(e)));
    } catch (_) {
      emit(const DeleteAccountState(
          DeleteAccountStep.failed, 'ลบบัญชีไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'));
    }
  }

  static String _authMessage(String code) => switch (code) {
        'wrong-password' || 'invalid-credential' => 'รหัสผ่านไม่ถูกต้อง',
        'user-mismatch' =>
          'กรุณาเลือกบัญชี Google เดียวกับที่ใช้เข้าสู่ระบบอยู่',
        'too-many-requests' =>
          'ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่',
        'network-request-failed' =>
          'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ',
        _ => 'ยืนยันตัวตนไม่สำเร็จ ($code)',
      };

  static String _serverMessage(FirebaseFunctionsException e) {
    if (e.code == 'failed-precondition' && e.message == 'active-trades') {
      final details = e.details;
      final count = details is Map ? details['count'] : null;
      return 'คุณยังมีการแลกที่ตกลงแล้วแต่ยังไม่เสร็จ'
          '${count is int ? ' $count รายการ' : ''} '
          'กรุณาส่งมอบหรือยกเลิกให้เรียบร้อยก่อนลบบัญชี';
    }
    if (e.code == 'failed-precondition' &&
        e.message == 'requires-recent-login') {
      return 'การยืนยันตัวตนหมดเวลา กรุณาลองใหม่อีกครั้ง';
    }
    if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
      return 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาลองใหม่อีกครั้ง';
    }
    return 'ลบบัญชีไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
  }
}
