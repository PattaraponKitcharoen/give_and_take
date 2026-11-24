import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/feature_flags.dart';
import '../constants/firebase_config.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get user => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    return await _firebaseAuth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword(
      {required String email, required String password}) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email, password: password);
    if (userCredential.user != null && !userCredential.user!.emailVerified) {
      await userCredential.user!.sendEmailVerification();
    }
    return userCredential;
  }

  // GoogleSignIn.instance must be initialized exactly once per app run.
  static Future<void>? _googleInit;

  Future<void> _ensureGoogleInitialized() =>
      _googleInit ??= GoogleSignIn.instance.initialize();

  /// Signs in with the Google account picker. Returns null if the user
  /// closed the picker. The client IDs come from GoogleService-Info.plist /
  /// google-services.json, so nothing is hard-coded here.
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw Exception('ไม่ได้รับข้อมูลยืนยันตัวตนจาก Google');
    }
    return _firebaseAuth
        .signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  /// Sign in with Apple is offered on iOS only (App Store rule for apps
  /// with Google sign-in); Android would need Apple's web flow. Off until
  /// the Apple Developer Program is set up: see kAppleSignInEnabled.
  static bool get appleSignInAvailable =>
      kAppleSignInEnabled &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;

  static bool _isAppleCancel(FirebaseAuthException e) =>
      e.code == 'canceled' || e.code == 'web-context-canceled';

  /// Signs in with the native Apple sheet. Returns null if it was closed.
  /// Apple shares the name and email only the first time.
  Future<UserCredential?> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    try {
      return await _firebaseAuth.signInWithProvider(provider);
    } on FirebaseAuthException catch (e) {
      if (_isAppleCancel(e)) return null;
      rethrow;
    }
  }

  Future<bool> isEmailVerified() async {
    await _firebaseAuth.currentUser?.reload();
    final user = _firebaseAuth.currentUser;
    final isVerified = user?.emailVerified ?? false;

    // The ID token (read by Cloud Functions, e.g. the AI assistant) only
    // picks up a new verification on its hourly refresh. Refresh it now if
    // it's behind, e.g. right after an admin verified the email.
    if (isVerified && user != null) {
      try {
        final token = await user.getIdTokenResult();
        if (token.claims?['email_verified'] != true) {
          await user.getIdToken(true);
        }
      } catch (_) {
        // Not fatal: the token refreshes on its own within the hour.
      }
    }

    // Background Sync: Auth as Truth, Sync to Firestore
    if (isVerified && user != null) {
      _firestore.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists) {
          final currentStatus = doc.data()?['is_email_verified'] ?? false;
          if (currentStatus == false) {
            _firestore
                .collection('users')
                .doc(user.uid)
                .update({'is_email_verified': true});
          }
        }
      }).catchError((_) {
        // Silently ignore background errors to avoid disrupting the UI
      });
    }

    return isVerified;
  }

  /// How the signed-in account proves who it is when asked again:
  /// 'password', 'google.com' or 'apple.com' (null if not signed in).
  String? get reauthProvider {
    final ids = _firebaseAuth.currentUser?.providerData
            .map((p) => p.providerId)
            .toSet() ??
        <String>{};
    if (ids.contains('password')) return 'password';
    if (ids.contains('google.com')) return 'google.com';
    if (ids.contains('apple.com')) return 'apple.com';
    return null;
  }

  /// Signs in again as the current user (the server wants a fresh sign-in
  /// before deleting an account). Pass [password] for an email account;
  /// Google and Apple show their own sheet. Returns false if it was closed.
  Future<bool> reauthenticate({String? password}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    if (reauthProvider == 'apple.com') {
      try {
        final result =
            await user.reauthenticateWithProvider(AppleAuthProvider());
        // Kept for deleteAccount: Apple wants the app's token revoked.
        _appleAuthorizationCode = result.additionalUserInfo?.authorizationCode;
      } on FirebaseAuthException catch (e) {
        if (_isAppleCancel(e)) return false;
        rethrow;
      }
      await user.getIdToken(true);
      return true;
    }
    final AuthCredential credential;
    if (reauthProvider == 'password') {
      credential = EmailAuthProvider.credential(
          email: user.email ?? '', password: password ?? '');
    } else {
      await _ensureGoogleInitialized();
      final GoogleSignInAccount account;
      try {
        account = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) return false;
        rethrow;
      }
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('ไม่ได้รับข้อมูลยืนยันตัวตนจาก Google');
      }
      credential = GoogleAuthProvider.credential(idToken: idToken);
    }
    await user.reauthenticateWithCredential(credential);
    // The callable reads auth_time from the ID token: send a fresh one.
    await user.getIdToken(true);
    return true;
  }

  /// Deletes the account on the server (Cloud Function deleteAccount),
  /// then signs out here. Call [reauthenticate] first.
  Future<void> deleteAccount() async {
    // Sign in with Apple accounts: revoke the app's Apple token first (App
    // Store rule), while the Firebase user still exists. Best effort: it
    // needs the Apple key set up in Firebase, and must not block deletion.
    final code = _appleAuthorizationCode;
    _appleAuthorizationCode = null;
    if (code != null) {
      try {
        await _firebaseAuth.revokeTokenWithAuthorizationCode(code);
      } catch (e) {
        debugPrint('Apple token revoke failed: $e');
      }
    }
    await appFunctions().httpsCallable('deleteAccount').call();
    await signOut();
  }

  String? _appleAuthorizationCode;

  Future<void> signOut() async {
    // Also forget the Google account, so the next Google sign-in shows the
    // account picker instead of silently reusing the previous account.
    if (_googleInit != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _firebaseAuth.signOut();
  }

  Future<void> sendEmailVerification() async {
    try {
      if (_firebaseAuth.currentUser != null) {
        await _firebaseAuth.currentUser!.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        throw 'ส่งอีเมลบ่อยเกินไป กรุณารอสักครู่';
      }
      throw 'เกิดข้อผิดพลาด: ${e.message}';
    } catch (e) {
      throw 'เกิดข้อผิดพลาด: $e';
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }
}
