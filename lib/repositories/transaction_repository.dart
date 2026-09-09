import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final FirebaseFirestore _firestore;

  TransactionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<TransactionModel> getTransactionStream(String transactionId) {
    return _firestore.collection('transactions').doc(transactionId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return TransactionModel.fromJson(snapshot.data()!, snapshot.id);
      }
      throw Exception('Transaction not found');
    });
  }
  
  Stream<TransactionModel?> getTransactionByOfferIdStream(String offerId) {
    return _firestore
        .collection('transactions')
        .where('offer_id', isEqualTo: offerId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return TransactionModel.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    });
  }

  Future<TransactionModel> getTransaction(String transactionId) async {
    final snapshot = await _firestore.collection('transactions').doc(transactionId).get();
    if (snapshot.exists && snapshot.data() != null) {
      return TransactionModel.fromJson(snapshot.data()!, snapshot.id);
    }
    throw Exception('Transaction not found');
  }

  Future<Map<String, dynamic>> confirmTransaction(String transactionId, String userId, String inputOtp) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        DocumentReference txRef = _firestore.collection('transactions').doc(transactionId);
        DocumentSnapshot txSnap = await transaction.get(txRef);
        
        if (!txSnap.exists) throw Exception("ไม่พบข้อมูลสัญญากองกลาง");
        Map<String, dynamic> txData = txSnap.data() as Map<String, dynamic>;
        
        if (txData['status'] != 'in_progress') throw Exception("สถานะดีลไม่ถูกต้อง");

        Map<String, dynamic> codes = txData['verification_codes'] ?? {};
        String partnerId = (txData['members'] as List).firstWhere((id) => id != userId);
        String partnerCode = codes[partnerId] ?? '';

        if (inputOtp != partnerCode) throw Exception("รหัสยืนยันไม่ถูกต้อง");

        List<dynamic> confirmedByIds = List.from(txData['confirmed_by_user_ids'] ?? []);
        if (!confirmedByIds.contains(userId)) {
          confirmedByIds.add(userId);
        }

        bool isCompleted = confirmedByIds.length == 2;

        if (isCompleted) {
          // Escrow Release Logic
          String offerId = txData['offer_id'];
          DocumentReference offerRef = _firestore.collection('offers').doc(offerId);
          DocumentSnapshot offerSnap = await transaction.get(offerRef);
          Map<String, dynamic> offerData = offerSnap.data() as Map<String, dynamic>;

          String targetItemId = offerData['target_listing_id'];
          String offeredItemId = offerData['offered_listing_id'];
          int escrowCoins = txData['escrow_coins'] ?? 0;
          
          DocumentReference? receiverRef; 
          int newBalance = 0; 
          String? receiverId;

          if (escrowCoins > 0) {
            int coinOffset = offerData['coin_offset'] ?? 0;
            String senderId = offerData['sender_id'];
            String targetUserId = offerData['target_user_id'] ?? offerData['target_owner_id'];
            receiverId = coinOffset > 0 ? targetUserId : senderId;
            
            receiverRef = _firestore.collection('users').doc(receiverId);
            DocumentSnapshot receiverSnap = await transaction.get(receiverRef);
            
            int currentBalance = (receiverSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
            newBalance = currentBalance + escrowCoins;
          }

          transaction.update(_firestore.collection('listings').doc(targetItemId), {'status': 'completed'});
          transaction.update(_firestore.collection('listings').doc(offeredItemId), {'status': 'completed'});

          if (receiverRef != null && escrowCoins > 0 && receiverId != null) {
            transaction.update(receiverRef, {'coins_balance': newBalance});
            DocumentReference walletTxRef = _firestore.collection('wallet_transactions').doc();
            transaction.set(walletTxRef, {
              'log_id': walletTxRef.id, 'user_id': receiverId, 'amount': escrowCoins, 'balance_after': newBalance,
              'type': 'escrow_release', 'status': 'success', 'reference_id': transactionId,
              'description': 'ได้รับเหรียญจากระบบกองกลาง (แลกเปลี่ยนสำเร็จ)', 'created_at': FieldValue.serverTimestamp(),
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

  Future<Map<String, dynamic>> confirmTransactionByOfferId(String offerId, String userId, String inputOtp) async {
    try {
      final txQuery = await _firestore.collection('transactions')
          .where('members', arrayContains: userId)
          .where('offer_id', isEqualTo: offerId)
          .limit(1)
          .get();
      if (txQuery.docs.isEmpty) throw Exception("ไม่พบข้อมูลสัญญากองกลาง");
      return await confirmTransaction(txQuery.docs.first.id, userId, inputOtp);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> cancelAcceptedDeal(String offerId, String reason, String currentUserId, String userName, String roomId) async {
    try {
      final txQuery = await _firestore
          .collection('transactions')
          .where('members', arrayContains: currentUserId)
          .where('offer_id', isEqualTo: offerId)
          .limit(1)
          .get();
      if (txQuery.docs.isEmpty) throw Exception("ไม่พบข้อมูลสัญญากองกลาง");
      DocumentReference mainTxRef = txQuery.docs.first.reference;

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot txSnap = await transaction.get(mainTxRef);
        Map<String, dynamic> txData = txSnap.data() as Map<String, dynamic>;
        if (txData['status'] != 'in_progress') throw Exception("สถานะไม่ใช่กำลังดำเนินการ");

        DocumentReference offerRef = _firestore.collection('offers').doc(offerId);
        DocumentSnapshot offerSnap = await transaction.get(offerRef);
        Map<String, dynamic> offerData = offerSnap.data() as Map<String, dynamic>;

        String targetItemId = offerData['target_listing_id'];
        String offeredItemId = offerData['offered_listing_id'];
        int escrowCoins = txData['escrow_coins'] ?? 0;
        String? payerId;
        DocumentSnapshot? payerSnap;
        DocumentReference? payerRef;
        int newBalance = 0;

        if (escrowCoins > 0) {
          int coinOffset = offerData['coin_offset'] ?? 0;
          String senderId = offerData['sender_id'];
          String targetUserId = offerData['target_user_id'] ?? offerData['target_owner_id'];
          payerId = coinOffset > 0 ? senderId : targetUserId;
          payerRef = _firestore.collection('users').doc(payerId);
          payerSnap = await transaction.get(payerRef);
          int currentBalance = (payerSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
          newBalance = currentBalance + escrowCoins;
        }

        transaction.update(_firestore.collection('listings').doc(targetItemId), {'status': 'active'});
        transaction.update(_firestore.collection('listings').doc(offeredItemId), {'status': 'active'});

        if (payerRef != null && escrowCoins > 0 && payerId != null) {
          transaction.update(payerRef, {'coins_balance': newBalance});
          DocumentReference walletTxRef = _firestore.collection('wallet_transactions').doc();
          transaction.set(walletTxRef, {
            'log_id': walletTxRef.id, 'user_id': payerId, 'amount': escrowCoins, 'balance_after': newBalance,
            'type': 'refund', 'status': 'success', 'reference_id': mainTxRef.id,
            'description': 'คืนเหรียญจากระบบกองกลาง (ยกเลิกการแลกเปลี่ยน)', 'created_at': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(mainTxRef, {'status': 'cancelled', 'cancel_reason': reason, 'updated_at': FieldValue.serverTimestamp()});
        transaction.update(offerRef, {'status': 'cancelled'});
        
        DocumentReference roomRef = _firestore.collection('chat_rooms').doc(roomId);
        transaction.update(roomRef, {'last_message_type': 'system_cancel', 'updated_at': FieldValue.serverTimestamp()});
        
        DocumentReference msgRef = roomRef.collection('messages').doc();
        transaction.set(msgRef, {
          'sender_id': 'system', 
          'content': '$userName ได้ยกเลิกการแลกเปลี่ยน ระบบได้ทำการคืนสิ่งของและเหรียญเรียบร้อยแล้ว', 
          'timestamp': FieldValue.serverTimestamp(), 
          'type': 'system_cancel',
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw Exception('ไม่มีสิทธิ์เข้าถึงข้อมูล');
      throw Exception('เกิดข้อผิดพลาดจากระบบ: ${e.message}');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
