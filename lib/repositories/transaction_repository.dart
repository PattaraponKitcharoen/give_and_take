import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants/firebase_config.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  TransactionRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? appFunctions();

  Stream<TransactionModel> getTransactionStream(String transactionId) {
    return _firestore
        .collection('transactions')
        .doc(transactionId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return TransactionModel.fromJson(snapshot.data()!, snapshot.id);
      }
      throw Exception('Transaction not found');
    });
  }

  Stream<TransactionModel?> getTransactionByOfferIdStream(
      String offerId, String userId) {
    // Firestore security rules can only validate a *query* (as opposed to a
    // single-document get) by checking the query's own filters against the
    // rule — they can't inspect each matched document's fields ahead of
    // time. A rule like "members contains request.auth.uid" is satisfied by
    // any single transaction doc, but a query that filters only on offer_id
    // gives Firestore no way to prove every possible match would pass that
    // rule, so the whole query gets rejected with permission-denied. Filtering
    // on `members` here too (matching confirmTransactionByOfferId/
    // cancelAcceptedDeal below) lets the rule validate against the query
    // itself.
    return _firestore
        .collection('transactions')
        .where('offer_id', isEqualTo: offerId)
        .where('members', arrayContains: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return TransactionModel.fromJson(
            snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    });
  }

  Future<TransactionModel> getTransaction(String transactionId) async {
    final snapshot =
        await _firestore.collection('transactions').doc(transactionId).get();
    if (snapshot.exists && snapshot.data() != null) {
      return TransactionModel.fromJson(snapshot.data()!, snapshot.id);
    }
    throw Exception('Transaction not found');
  }

  Future<Map<String, dynamic>> confirmTransaction(
      String transactionId, String userId, String inputOtp) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        DocumentReference txRef =
            _firestore.collection('transactions').doc(transactionId);
        DocumentSnapshot txSnap = await transaction.get(txRef);

        if (!txSnap.exists) throw Exception("ไม่พบข้อมูลสัญญากองกลาง");
        Map<String, dynamic> txData = txSnap.data() as Map<String, dynamic>;

        if (txData['status'] != 'in_progress')
          throw Exception("สถานะดีลไม่ถูกต้อง");

        final List<dynamic> members = txData['members'] ?? [];
        if (!members.contains(userId)) {
          throw Exception("คุณไม่มีสิทธิ์ยืนยันดีลนี้");
        }

        Map<String, dynamic> codes = txData['verification_codes'] ?? {};
        String partnerId = members.firstWhere(
          (id) => id != userId,
          orElse: () => throw Exception("ไม่พบคู่สัญญาในดีลนี้"),
        );
        String partnerCode = codes[partnerId] ?? '';

        if (inputOtp != partnerCode) throw Exception("รหัสยืนยันไม่ถูกต้อง");

        List<dynamic> confirmedByIds =
            List.from(txData['confirmed_by_user_ids'] ?? []);
        if (!confirmedByIds.contains(userId)) {
          confirmedByIds.add(userId);
        }

        bool isCompleted = confirmedByIds.length == 2;

        if (isCompleted) {
          // Escrow Release Logic
          String offerId = txData['offer_id'];
          DocumentReference offerRef =
              _firestore.collection('offers').doc(offerId);
          DocumentSnapshot offerSnap = await transaction.get(offerRef);
          if (!offerSnap.exists)
            throw Exception("ไม่พบข้อมูลข้อเสนอที่เกี่ยวข้อง");
          Map<String, dynamic> offerData =
              offerSnap.data() as Map<String, dynamic>;

          String targetItemId = offerData['target_listing_id'];
          String offeredItemId = offerData['offered_listing_id'];
          int escrowCoins = txData['escrow_coins'] ?? 0;

          DocumentReference? receiverRef;
          // UserModel.coinsBalance is a Dart double (see user_model.dart),
          // so Firestore stores coins_balance as a double — reading it into
          // an int here throws "type 'double' is not a subtype of type
          // 'int'" at runtime.
          double newBalance = 0;
          String? receiverId;

          if (escrowCoins > 0) {
            int coinOffset = offerData['coin_offset'] ?? 0;
            String senderId = offerData['sender_id'];
            String targetUserId =
                offerData['target_user_id'] ?? offerData['target_owner_id'];
            receiverId = coinOffset > 0 ? targetUserId : senderId;

            receiverRef = _firestore.collection('users').doc(receiverId);
            DocumentSnapshot receiverSnap = await transaction.get(receiverRef);
            if (!receiverSnap.exists) throw Exception("ไม่พบบัญชีผู้รับเหรียญ");

            double currentBalance = ((receiverSnap.data()
                        as Map<String, dynamic>)['coins_balance'] ??
                    0)
                .toDouble();
            newBalance = currentBalance + escrowCoins;
          }

          transaction.update(
              _firestore.collection('listings').doc(targetItemId),
              {'status': 'completed'});
          transaction.update(
              _firestore.collection('listings').doc(offeredItemId),
              {'status': 'completed'});

          if (receiverRef != null && escrowCoins > 0 && receiverId != null) {
            transaction.update(receiverRef, {'coins_balance': newBalance});
            DocumentReference walletTxRef =
                _firestore.collection('wallet_transactions').doc();
            transaction.set(walletTxRef, {
              'log_id': walletTxRef.id,
              'user_id': receiverId,
              'amount': escrowCoins,
              'balance_after': newBalance,
              'type': 'escrow_release',
              'status': 'success',
              'reference_id': transactionId,
              'description': 'ได้รับเหรียญจากระบบกองกลาง (แลกเปลี่ยนสำเร็จ)',
              'created_at': FieldValue.serverTimestamp(),
            });
          }

          transaction.update(txRef, {
            'confirmed_by_user_ids': confirmedByIds,
            'status': 'completed',
            'updated_at': FieldValue.serverTimestamp()
          });
          transaction.update(offerRef, {'status': 'completed'});
        } else {
          transaction.update(txRef, {
            'confirmed_by_user_ids': confirmedByIds,
            'updated_at': FieldValue.serverTimestamp()
          });
        }

        return {
          'isCompleted': isCompleted,
          'partnerId': partnerId,
        };
      });
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Confirming an OTP means completing the deal, which can require updating
  // a listing and crediting a coins_balance that belong to the OTHER party
  // — no Firestore security rule can grant that narrowly without opening a
  // much bigger hole, so this now runs server-side (see
  // functions/index.js#confirmHandoverOtp) via the Admin SDK, which bypasses
  // rules entirely and enforces membership/OTP-correctness in code instead.
  Future<Map<String, dynamic>> confirmTransactionByOfferId(
      String offerId, String userId, String inputOtp) async {
    try {
      final callable = _functions.httpsCallable('confirmHandoverOtp');
      final result = await callable.call(<String, dynamic>{
        'offerId': offerId,
        'inputOtp': inputOtp,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return {
        'isCompleted': data['isCompleted'] ?? false,
        'partnerId': data['partnerId'] ?? '',
      };
    } on FirebaseFunctionsException catch (e) {
      throw Exception(
          e.message ?? 'ไม่สามารถยืนยันรหัสได้ กรุณาลองใหม่อีกครั้ง');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการยืนยันรหัส กรุณาลองใหม่อีกครั้ง');
    }
  }

  // Same reasoning as confirmTransactionByOfferId above — cancelling also
  // writes listings/coins belonging to the other party, so it runs
  // server-side (functions/index.js#cancelAcceptedTrade), which resolves the
  // caller's display name itself instead of trusting one passed in.
  Future<void> cancelAcceptedDeal(String offerId, String reason,
      String currentUserId, String roomId) async {
    try {
      final callable = _functions.httpsCallable('cancelAcceptedTrade');
      await callable.call(<String, dynamic>{
        'offerId': offerId,
        'reason': reason,
        'roomId': roomId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(
          e.message ?? 'ไม่สามารถยกเลิกการแลกเปลี่ยนได้ กรุณาลองใหม่อีกครั้ง');
    } catch (e) {
      throw Exception(
          'เกิดข้อผิดพลาดในการยกเลิกการแลกเปลี่ยน กรุณาลองใหม่อีกครั้ง');
    }
  }
}
