import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/notification_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  StreamSubscription<User?>? _authSubscription;

  AuthCubit({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  })  : _authRepository = authRepository,
        _userRepository = userRepository,
        super(AuthInitial()) {
    _monitorAuthState();
  }

  void _monitorAuthState() {
    emit(AuthLoading());
    _authSubscription = _authRepository.user.listen(
      (User? user) {
        if (user != null) {
          emit(Authenticated(user));
          // Fires on every transition into "logged in" — login, register
          // (which signs the user in automatically), and a persisted
          // session at cold start — so the FCM token saved by
          // NotificationService.initNotification() at app startup (which
          // runs before this stream has ever emitted, and so skips the
          // save if no session was already persisted) still gets written
          // once a session actually exists. Fire-and-forget: a failed
          // token save shouldn't block auth state.
          NotificationService().saveDeviceToken();
        } else {
          emit(Unauthenticated());
        }
      },
      onError: (error) {
        emit(AuthError(error.toString()));
      },
    );
  }

  Future<void> signIn(String email, String password) async {
    try {
      emit(AuthLoading());
      await _authRepository.signInWithEmailAndPassword(email, password);
      // State will automatically update via stream listener
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }

  /// Google sign-in for both existing and new users. A first-time Google
  /// user gets the same starting profile as email sign-up (1,000 coins,
  /// role user); name and photo come from the Google account, and the email
  /// already counts as verified.
  Future<void> signInWithGoogle() async {
    final previous = state;
    try {
      emit(AuthLoading());
      final credential = await _authRepository.signInWithGoogle();
      final user = credential?.user;
      if (user == null) {
        // Picker closed: back to where we were, no error.
        emit(previous is AuthLoading ? Unauthenticated() : previous);
        return;
      }
      if (!await _userRepository.userExists(user.uid)) {
        final now = DateTime.now();
        // Signed in to Firebase but no profile yet: if creating it fails,
        // sign out again rather than leave an account the app can't load.
        await _userRepository
            .createUser(UserModel(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? (user.email ?? '').split('@').first,
          bio: '',
          tel: '',
          role: 'user',
          status: 'active',
          profileImgUrl: user.photoURL ?? '',
          coinsBalance: 1000,
          isEmailVerified: true,
          isPhoneVerified: false,
          createdAt: now,
          updatedAt: now,
          faculty: '',
          academicYear: '',
          isStudent: false,
        ))
            .catchError((Object e) async {
          await _authRepository.signOut();
          throw e;
        });
      }
      // Authenticated is emitted by the authStateChanges listener.
    } on FirebaseAuthException catch (e) {
      emit(AuthError(switch (e.code) {
        'account-exists-with-different-credential' =>
          'อีเมลนี้สมัครไว้ด้วยวิธีอื่น กรุณาเข้าสู่ระบบด้วยอีเมลและรหัสผ่าน',
        'user-disabled' =>
          'บัญชีนี้ถูกระงับการใช้งานถาวร หากคิดว่าเป็นความผิดพลาด กรุณาติดต่อผู้ดูแลระบบ',
        'network-request-failed' =>
          'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ',
        _ => 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ (${e.code})',
      }));
      emit(Unauthenticated());
    } on GoogleSignInException catch (e) {
      emit(AuthError('เข้าสู่ระบบด้วย Google ไม่สำเร็จ (${e.code.name})'));
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
      emit(Unauthenticated());
    }
  }

  Future<void> signOut() async {
    try {
      emit(AuthLoading());
      await _authRepository.signOut();
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
