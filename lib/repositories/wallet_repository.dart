import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet_entry.dart';

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

  /// Looks up which deal a wallet entry came from. Escrow locks point at
  /// the offer directly; releases and refunds point at the transaction,
  /// which carries the offer id. Returns null when the deal can't be found
  /// (e.g. deleted) so the row just falls back to its description.
  Future<WalletDeal?> resolveDeal(WalletEntry entry, String userId) async {
    if (entry.referenceId.isEmpty) return null;
    try {
      String offerId = entry.referenceId;
      if (entry.type != 'escrow_lock') {
        final tx = await _firestore
            .collection('transactions')
            .doc(entry.referenceId)
            .get();
        offerId = (tx.data()?['offer_id'] as String?) ?? '';
        if (offerId.isEmpty) return null;
      }

      final offer =
          (await _firestore.collection('offers').doc(offerId).get()).data();
      if (offer == null) return null;

      final senderId = offer['sender_id'] as String? ?? '';
      final iAmSender = senderId == userId;
      final myListingId = (iAmSender
              ? offer['offered_listing_id']
              : offer['target_listing_id']) as String? ??
          '';
      final theirListingId = (iAmSender
              ? offer['target_listing_id']
              : offer['offered_listing_id']) as String? ??
          '';
      final partnerId =
          (iAmSender ? offer['target_user_id'] : senderId) as String? ?? '';

      final results = await Future.wait([
        _listing(myListingId),
        _listing(theirListingId),
        _userName(partnerId),
        _roomId(offerId, userId),
      ]);
      final myItem = results[0] as Map<String, dynamic>?;
      final theirItem = results[1] as Map<String, dynamic>?;

      return WalletDeal(
        offerId: offerId,
        myItemTitle: myItem?['title'] ?? 'สิ่งของที่ถูกลบแล้ว',
        theirItemTitle: theirItem?['title'] ?? 'สิ่งของที่ถูกลบแล้ว',
        theirItemThumbnail: theirItem?['thumbnail_url'] ?? '',
        partnerName: results[2] as String,
        roomId: results[3] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _listing(String id) async {
    if (id.isEmpty) return null;
    return (await _firestore.collection('listings').doc(id).get()).data();
  }

  Future<String> _userName(String id) async {
    if (id.isEmpty) return 'ผู้ใช้งาน';
    final data = (await _firestore.collection('users').doc(id).get()).data();
    final name = (data?['name'] as String?)?.trim() ?? '';
    return name.isEmpty ? 'ผู้ใช้งาน' : name;
  }

  Future<String?> _roomId(String offerId, String userId) async {
    try {
      final snap = await _firestore
          .collection('chat_rooms')
          .where('members', arrayContains: userId)
          .where('active_offer_id', isEqualTo: offerId)
          .limit(1)
          .get();
      return snap.docs.isEmpty ? null : snap.docs.first.id;
    } catch (_) {
      return null;
    }
  }
}
