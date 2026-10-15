import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
