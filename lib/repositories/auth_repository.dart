import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get user => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword({required String email, required String password}) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    if (userCredential.user != null && !userCredential.user!.emailVerified) {
      await userCredential.user!.sendEmailVerification();
    }
    return userCredential;
  }

  Future<bool> isEmailVerified() async {
    await _firebaseAuth.currentUser?.reload();
    final user = _firebaseAuth.currentUser;
    final isVerified = user?.emailVerified ?? false;

    // Background Sync: Auth as Truth, Sync to Firestore
    if (isVerified && user != null) {
      _firestore.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists) {
          final currentStatus = doc.data()?['is_email_verified'] ?? false;
          if (currentStatus == false) {
            _firestore.collection('users').doc(user.uid).update({'is_email_verified': true});
          }
        }
      }).catchError((_) {
        // Silently ignore background errors to avoid disrupting the UI
      });
    }

    return isVerified;
  }

  Future<void> signOut() async {
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
