import 'package:cloud_firestore/cloud_firestore.dart';

class WalletRepository {
  final FirebaseFirestore _firestore;

  WalletRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<QuerySnapshot> getWalletHistoryStream(String userId) {
    return _firestore
        .collection('wallet_transactions')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots();
  }
}
