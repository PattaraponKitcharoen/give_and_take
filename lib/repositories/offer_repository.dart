import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/offer_model.dart';

class OfferRepository {
  final FirebaseFirestore _firestore;

  OfferRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<OfferModel> getOfferStream(String offerId) {
    return _firestore.collection('offers').doc(offerId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return OfferModel.fromJson(snapshot.data()!, snapshot.id);
      }
      throw Exception('Offer not found');
    });
  }

  Future<OfferModel> getOffer(String offerId) async {
    final snapshot = await _firestore.collection('offers').doc(offerId).get();
    if (snapshot.exists && snapshot.data() != null) {
      return OfferModel.fromJson(snapshot.data()!, snapshot.id);
    }
    throw Exception('Offer not found');
  }

  Future<void> updateOfferStatus(String offerId, String status) async {
    await _firestore.collection('offers').doc(offerId).update({
      'status': status, 
      'updated_at': FieldValue.serverTimestamp()
    });
  }

  Stream<List<OfferModel>> getIncomingOffers(String userId) {
    return _firestore.collection('offers')
        .where('target_user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => OfferModel.fromJson(doc.data(), doc.id)).toList());
  }

  Stream<List<OfferModel>> getOutgoingOffers(String userId) {
    return _firestore.collection('offers')
        .where('sender_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => OfferModel.fromJson(doc.data(), doc.id)).toList());
  }

  Future<int> getSuccessfulTradesCount(String userId) async {
    try {
      final sentSnap = await _firestore.collection('offers')
          .where('sender_id', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .count() 
          .get();
      final receivedSnap = await _firestore.collection('offers')
          .where('target_user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .count() 
          .get();
      return (sentSnap.count ?? 0) + (receivedSnap.count ?? 0);
    } catch (e) {
      return 0;
    }
  }

  Future<String> createOfferAndChatRoom({
    required OfferModel offer,
    required Map<String, dynamic> targetItemData,
    required Map<String, dynamic> offeredItemData,
    required String coinText,
  }) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      DocumentReference offerRef = _firestore.collection('offers').doc();
      var offerData = offer.toJson();
      offerData['created_at'] = FieldValue.serverTimestamp();
      offerData['updated_at'] = FieldValue.serverTimestamp();
      offerData['last_offer_by'] = offer.senderId;
      
      debugPrint('----- Create Offer Payload -----');
      debugPrint('Offer Payload: $offerData');

      DocumentReference roomRef = _firestore.collection('chat_rooms').doc();
      var chatRoomData = {
        'members': [offer.senderId, offer.targetUserId],
        'active_offer_id': offerRef.id,
        'last_message_text': 'ยื่นข้อเสนอแลกเปลี่ยนสิ่งของใหม่',
        'last_message_type': 'system_offer', 
        'last_sender_id': offer.senderId,
        'read_by': [offer.senderId], 
        'read_timestamps': { offer.senderId: FieldValue.serverTimestamp() },
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      };
      
      debugPrint('Chat Room Payload: $chatRoomData');

      DocumentReference msgRef = roomRef.collection('messages').doc();
      var messageData = {
        'sender_id': offer.senderId,
        'content': 'สวัสดีครับ! ผมขอเสนอแลกสิ่งของ$coinText ครับ',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system_offer',
        'offer_data': {
           'target_item': targetItemData, 
           'offered_item': offeredItemData, 
        }
      };
      
      debugPrint('Message Payload: $messageData');

      try {
        await offerRef.set(offerData);
      } catch (e) {
        debugPrint('Offer Error (offers): $e');
        throw Exception('ไม่มีสิทธิ์สร้างข้อเสนอ (offers)');
      }

      try {
        await roomRef.set(chatRoomData);
      } catch (e) {
        debugPrint('Offer Error (chat_rooms): $e');
        throw Exception('ไม่มีสิทธิ์สร้างห้องแชท (chat_rooms)');
      }

      try {
        await msgRef.set(messageData);
      } catch (e) {
        debugPrint('Offer Error (messages): $e');
        throw Exception('ไม่มีสิทธิ์ส่งข้อความระบบ (messages)');
      }

      return roomRef.id;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('ไม่มีสิทธิ์สร้างข้อเสนอ');
      }
      throw Exception('เกิดข้อผิดพลาดจากระบบ: ${e.message}');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการสร้างข้อเสนอ: $e');
    }
  }

  Future<void> cancelOffer(String offerId, String roomId, String currentUserId, String userName) async {
    try {
      WriteBatch batch = _firestore.batch();
      DocumentReference offerRef = _firestore.collection('offers').doc(offerId);
      batch.delete(offerRef);

      DocumentReference roomRef = _firestore.collection('chat_rooms').doc(roomId);
      batch.update(roomRef, {
        'last_message_type': 'system_cancel',
        'updated_at': FieldValue.serverTimestamp(),
      });

      DocumentReference msgRef = roomRef.collection('messages').doc();
      batch.set(msgRef, {
        'sender_id': 'system', 
        'content': '$userName ได้ยกเลิกข้อเสนอนี้แล้ว', 
        'timestamp': FieldValue.serverTimestamp(), 
        'type': 'system_cancel',
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('ไม่มีสิทธิ์ยกเลิกข้อเสนอ');
      }
      throw Exception('เกิดข้อผิดพลาดจากระบบ: ${e.message}');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการยกเลิกข้อเสนอ: $e');
    }
  }

  Future<void> rejectOffer(String offerId, String roomId, String currentUserId, String userName) async {
    try {
      WriteBatch batch = _firestore.batch();
      DocumentReference offerRef = _firestore.collection('offers').doc(offerId);
      batch.update(offerRef, {'status': 'rejected', 'updated_at': FieldValue.serverTimestamp()});

      DocumentReference roomRef = _firestore.collection('chat_rooms').doc(roomId);
      batch.update(roomRef, {
        'last_message_type': 'system_reject',
        'updated_at': FieldValue.serverTimestamp(),
      });

      DocumentReference msgRef = roomRef.collection('messages').doc();
      batch.set(msgRef, {
        'sender_id': 'system', 
        'content': '$userName ได้ปฏิเสธข้อเสนอนี้แล้ว', 
        'timestamp': FieldValue.serverTimestamp(), 
        'type': 'system_reject',
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('ไม่มีสิทธิ์ปฏิเสธข้อเสนอ');
      }
      throw Exception('เกิดข้อผิดพลาดจากระบบ: ${e.message}');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการปฏิเสธข้อเสนอ: $e');
    }
  }

  Future<void> submitCounterOffer(String offerId, Map<String, dynamic> offerData, int amount, bool iWillPay, String roomId, String currentUserId, String userName) async {
    try {
      WriteBatch batch = _firestore.batch();
      bool iAmSender = (currentUserId == offerData['sender_id']);
      int newCoinOffset = iWillPay ? amount : -amount;
      if (!iAmSender) newCoinOffset = -newCoinOffset;

      DocumentReference offerRef = _firestore.collection('offers').doc(offerId);
      batch.update(offerRef, {
        'coin_offset': newCoinOffset,
        'last_offer_by': currentUserId,
        'updated_at': FieldValue.serverTimestamp(),
      });

      DocumentReference roomRef = _firestore.collection('chat_rooms').doc(roomId);
      batch.update(roomRef, {
        'last_message_type': 'system_counter',
        'updated_at': FieldValue.serverTimestamp(),
      });

      String content = '$userName เสนอต่อรอง: ';
      content += iWillPay ? 'ยินดีจ่ายเพิ่ม $amount Coins' : 'ขอรับเงินเพิ่ม $amount Coins';

      DocumentReference msgRef = roomRef.collection('messages').doc();
      batch.set(msgRef, {
        'sender_id': 'system', 
        'content': content,
        'timestamp': FieldValue.serverTimestamp(), 
        'type': 'system_counter',
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('ไม่มีสิทธิ์ยื่นข้อเสนอต่อรอง');
      }
      throw Exception('เกิดข้อผิดพลาดจากระบบ: ${e.message}');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการยื่นข้อเสนอต่อรอง: $e');
    }
  }

  Future<void> acceptOffer(String offerId, String roomId, String currentUserId, String userName) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference offerRef = _firestore.collection('offers').doc(offerId);
        DocumentSnapshot offerSnap = await transaction.get(offerRef);
        
        if (!offerSnap.exists) throw Exception("ไม่พบข้อมูลข้อเสนอ");
        Map<String, dynamic> offerData = offerSnap.data() as Map<String, dynamic>;
        
        int coinOffset = offerData['coin_offset'] ?? 0;
        String senderId = offerData['sender_id'];
        String targetUserId = offerData['target_user_id'];
        String targetItemId = offerData['target_listing_id'];
        String offeredItemId = offerData['offered_listing_id'];
        
        String? payerId; 
        int amountToPay = 0;
        
        if (coinOffset > 0) { 
          payerId = senderId; 
          amountToPay = coinOffset; 
        } else if (coinOffset < 0) { 
          payerId = targetUserId; 
          amountToPay = coinOffset.abs(); 
        }

        if (payerId != null && amountToPay > 0) {
          DocumentReference payerRef = _firestore.collection('users').doc(payerId);
          DocumentSnapshot payerSnap = await transaction.get(payerRef);
          
          if (!payerSnap.exists) throw Exception("ไม่พบข้อมูลผู้ใช้งาน");
          
          int currentBalance = (payerSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
          if (currentBalance < amountToPay) throw Exception("ยอดเงินของฝั่งที่ต้องจ่ายไม่เพียงพอ");
          
          int newBalance = currentBalance - amountToPay;
          transaction.update(payerRef, {'coins_balance': newBalance});

          DocumentReference walletTxRef = _firestore.collection('wallet_transactions').doc();
          transaction.set(walletTxRef, {
            'log_id': walletTxRef.id, 
            'user_id': payerId, 
            'amount': -amountToPay,
            'balance_after': newBalance, 
            'type': 'escrow_lock', 
            'status': 'success',
            'reference_id': offerId, 
            'description': 'หักเหรียญเข้ากองกลางสำหรับข้อเสนอแลกเปลี่ยน',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        String code1 = (100000 + (DateTime.now().millisecondsSinceEpoch % 400000)).toString();
        String code2 = (500000 + (DateTime.now().millisecondsSinceEpoch % 400000)).toString();
        
        DocumentReference mainTxRef = _firestore.collection('transactions').doc();
        transaction.set(mainTxRef, {
          'transaction_id': mainTxRef.id, 
          'offer_id': offerId,
          'listings': [offeredItemId, targetItemId], 
          'members': [senderId, targetUserId],
          'escrow_coins': amountToPay, 
          'status': 'in_progress', 
          'cancel_reason': '',
          'verification_codes': {senderId: code1, targetUserId: code2}, 
          'confirmed_by_user_ids': [],
          'created_at': FieldValue.serverTimestamp(), 
          'updated_at': FieldValue.serverTimestamp(),
        });

        transaction.update(offerRef, {'status': 'accepted'});
        transaction.update(_firestore.collection('listings').doc(targetItemId), {'status': 'in_progress'});
        transaction.update(_firestore.collection('listings').doc(offeredItemId), {'status': 'in_progress'});

        DocumentReference roomRef = _firestore.collection('chat_rooms').doc(roomId);
        transaction.update(roomRef, {
          'last_message_type': 'system_accept',
          'updated_at': FieldValue.serverTimestamp(),
        });

        DocumentReference msgRef = roomRef.collection('messages').doc();
        transaction.set(msgRef, {
          'sender_id': 'system', 
          'content': '$userName ได้ตกลงรับข้อเสนอแลกเปลี่ยนแล้ว', 
          'timestamp': FieldValue.serverTimestamp(), 
          'type': 'system_accept',
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('ไม่มีสิทธิ์เข้าถึงข้อมูล');
      }
      throw Exception('เกิดข้อผิดพลาดจากระบบ: ${e.message}');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
