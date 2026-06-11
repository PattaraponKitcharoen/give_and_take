import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/system_offer_card.dart';
import '../widgets/counter_offer_dialog.dart';
import '../widgets/handover_otp_dialog.dart';
import '../widgets/rating_review_dialog.dart';
import '../widgets/chat_bubble_widget.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  const ChatScreen({super.key, required this.roomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _markAsRead(); 
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // ==========================================
  // 🟢 DATABASE LOGIC METHODS
  // ==========================================

  Future<void> _markAsRead() async {
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).set({
      'read_by': FieldValue.arrayUnion([currentUserId]),
      'read_timestamps': { currentUserId: FieldValue.serverTimestamp() }
    }, SetOptions(merge: true));
  }

  void _showFloatingSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF008080),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<String> _getCurrentUserName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (doc.exists && doc.data() != null) {
        final name = doc.data()!['name'];
        if (name != null && name.toString().trim().isNotEmpty) return name.toString();
      }
    } catch (e) { debugPrint('Error fetching user name: $e'); }
    return 'ผู้ใช้งาน';
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    int hour = date.hour;
    final min = date.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '$hour:$min $ampm';
  }

  Future<Map<String, dynamic>> _getTargetItemInfo(String? offerId) async {
    if (offerId == null || offerId.isEmpty) return {};
    try {
      final offerDoc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) return {};
      final data = offerDoc.data()!;
      
      String targetId = data['target_listing_id'] ?? '';
      String offeredId = data['offered_listing_id'] ?? '';
      String senderId = data['sender_id'] ?? '';
      
      String itemToShowId = (currentUserId == senderId) ? targetId : offeredId;
      if (itemToShowId.isNotEmpty) {
        final itemDoc = await FirebaseFirestore.instance.collection('listings').doc(itemToShowId).get();
        if (itemDoc.exists) return itemDoc.data() as Map<String, dynamic>;
      }
    } catch (e) { debugPrint('Error getting item info: $e'); }
    return {};
  }

  Future<void> _cancelOffer(String offerId) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).delete();
    String userName = await _getCurrentUserName();
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_type': 'system_cancel', 'updated_at': FieldValue.serverTimestamp(),
    });
    _sendSystemMessage('$userName ได้ยกเลิกข้อเสนอนี้แล้ว', type: 'system_cancel');
  }

  Future<void> _rejectOffer(String offerId) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({'status': 'rejected'});
    String userName = await _getCurrentUserName();
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_type': 'system_reject', 'updated_at': FieldValue.serverTimestamp(),
    });
    _sendSystemMessage('$userName ได้ปฏิเสธข้อเสนอนี้แล้ว', type: 'system_reject');
  }

  Future<void> _acceptOffer(String offerId) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    try {
      await db.runTransaction((transaction) async {
        DocumentReference offerRef = db.collection('offers').doc(offerId);
        DocumentSnapshot offerSnap = await transaction.get(offerRef);
        if (!offerSnap.exists) throw Exception("ไม่พบข้อมูลข้อเสนอ");
        Map<String, dynamic> offerData = offerSnap.data() as Map<String, dynamic>;
        
        int coinOffset = offerData['coin_offset'] ?? 0;
        String senderId = offerData['sender_id'];
        String targetUserId = offerData['target_user_id'];
        String targetItemId = offerData['target_listing_id'];
        String offeredItemId = offerData['offered_listing_id'];
        String? payerId; int amountToPay = 0;
        
        if (coinOffset > 0) { payerId = senderId; amountToPay = coinOffset; } 
        else if (coinOffset < 0) { payerId = targetUserId; amountToPay = coinOffset.abs(); }

        if (payerId != null && amountToPay > 0) {
          DocumentReference payerRef = db.collection('users').doc(payerId);
          DocumentSnapshot payerSnap = await transaction.get(payerRef);
          if (!payerSnap.exists) throw Exception("ไม่พบข้อมูลผู้ใช้งาน");
          
          int currentBalance = (payerSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
          if (currentBalance < amountToPay) throw Exception("ยอดเงินของฝั่งที่ต้องจ่ายไม่เพียงพอ");
          
          int newBalance = currentBalance - amountToPay;
          transaction.update(payerRef, {'coins_balance': newBalance});

          DocumentReference walletTxRef = db.collection('wallet_transactions').doc();
          transaction.set(walletTxRef, {
            'log_id': walletTxRef.id, 'user_id': payerId, 'amount': -amountToPay,
            'balance_after': newBalance, 'type': 'escrow_lock', 'status': 'success',
            'reference_id': offerId, 'description': 'หักเหรียญเข้ากองกลางสำหรับข้อเสนอแลกเปลี่ยน',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        String code1 = (100000 + (DateTime.now().millisecondsSinceEpoch % 400000)).toString();
        String code2 = (500000 + (DateTime.now().millisecondsSinceEpoch % 400000)).toString();
        DocumentReference mainTxRef = db.collection('transactions').doc();
        transaction.set(mainTxRef, {
          'transaction_id': mainTxRef.id, 'offer_id': offerId,
          'listings': [offeredItemId, targetItemId], 'members': [senderId, targetUserId],
          'escrow_coins': amountToPay, 'status': 'in_progress', 'cancel_reason': '',
          'verification_codes': {senderId: code1, targetUserId: code2}, 'confirmed_by_user_ids': [],
          'created_at': FieldValue.serverTimestamp(), 'updated_at': FieldValue.serverTimestamp(),
        });

        transaction.update(offerRef, {'status': 'accepted'});
        transaction.update(db.collection('listings').doc(targetItemId), {'status': 'in_progress'});
        transaction.update(db.collection('listings').doc(offeredItemId), {'status': 'in_progress'});
      });

      String userName = await _getCurrentUserName();
      await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
        'last_message_type': 'system_accept', 'updated_at': FieldValue.serverTimestamp(),
      });
      _sendSystemMessage('$userName ตกลงแลกเปลี่ยนแล้ว และระบบได้ทำการล็อกเหรียญไว้ในกองกลาง', type: 'system_accept');
      _showFloatingSnackBar('เริ่มการแลกเปลี่ยนเรียบร้อยแล้ว');
    } catch (e) {
      _showFloatingSnackBar('ไม่สามารถทำรายการได้: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  Future<void> _cancelAcceptedDeal(String offerId, String reason) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    try {
      final txQuery = await db.collection('transactions').where('offer_id', isEqualTo: offerId).limit(1).get();
      if (txQuery.docs.isEmpty) throw Exception("ไม่พบข้อมูลสัญญากองกลาง");
      DocumentReference mainTxRef = txQuery.docs.first.reference;

      await db.runTransaction((transaction) async {
        DocumentSnapshot txSnap = await transaction.get(mainTxRef);
        Map<String, dynamic> txData = txSnap.data() as Map<String, dynamic>;
        if (txData['status'] != 'in_progress') throw Exception("สถานะไม่ใช่กำลังดำเนินการ");

        DocumentReference offerRef = db.collection('offers').doc(offerId);
        DocumentSnapshot offerSnap = await transaction.get(offerRef);
        Map<String, dynamic> offerData = offerSnap.data() as Map<String, dynamic>;

        String targetItemId = offerData['target_listing_id'];
        String offeredItemId = offerData['offered_listing_id'];
        int escrowCoins = txData['escrow_coins'] ?? 0;
        String? payerId; DocumentSnapshot? payerSnap; DocumentReference? payerRef; int newBalance = 0;

        if (escrowCoins > 0) {
          int coinOffset = offerData['coin_offset'] ?? 0;
          String senderId = offerData['sender_id'];
          String targetUserId = offerData['target_user_id'] ?? offerData['target_owner_id'];
          payerId = coinOffset > 0 ? senderId : targetUserId;
          payerRef = db.collection('users').doc(payerId);
          payerSnap = await transaction.get(payerRef); 
          int currentBalance = (payerSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
          newBalance = currentBalance + escrowCoins; 
        }

        transaction.update(db.collection('listings').doc(targetItemId), {'status': 'active'});
        transaction.update(db.collection('listings').doc(offeredItemId), {'status': 'active'});

        if (payerRef != null && escrowCoins > 0) {
          transaction.update(payerRef, {'coins_balance': newBalance});
          DocumentReference walletTxRef = db.collection('wallet_transactions').doc();
          transaction.set(walletTxRef, {
            'log_id': walletTxRef.id, 'user_id': payerId, 'amount': escrowCoins, 'balance_after': newBalance,
            'type': 'refund', 'status': 'success', 'reference_id': mainTxRef.id,
            'description': 'คืนเหรียญจากระบบกองกลาง (ยกเลิกการแลกเปลี่ยน)', 'created_at': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(mainTxRef, { 'status': 'cancelled', 'cancel_reason': reason, 'updated_at': FieldValue.serverTimestamp() });
        transaction.update(offerRef, {'status': 'cancelled'});
      });

      String userName = await _getCurrentUserName();
      _sendSystemMessage('$userName ได้ยกเลิกการแลกเปลี่ยน ระบบได้ทำการคืนสิ่งของและเหรียญเรียบร้อยแล้ว', type: 'system_cancel'); 
      _showFloatingSnackBar('ยกเลิกการแลกเปลี่ยนสำเร็จ');
    } catch (e) {
      _showFloatingSnackBar('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  Future<void> _verifyHandoverCode(String offerId, String inputCode) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    try {
      final txQuery = await db.collection('transactions').where('offer_id', isEqualTo: offerId).limit(1).get();
      if (txQuery.docs.isEmpty) throw Exception("ไม่พบข้อมูลสัญญากองกลาง");
      DocumentReference mainTxRef = txQuery.docs.first.reference;

      await db.runTransaction((transaction) async {
        DocumentSnapshot txSnap = await transaction.get(mainTxRef);
        Map<String, dynamic> txData = txSnap.data() as Map<String, dynamic>;
        if (txData['status'] != 'in_progress') throw Exception("สถานะดีลไม่ถูกต้อง");

        Map<String, dynamic> codes = txData['verification_codes'] ?? {};
        String partnerId = (txData['members'] as List).firstWhere((id) => id != currentUserId);
        String partnerCode = codes[partnerId] ?? '';

        if (inputCode != partnerCode) throw Exception("รหัสยืนยันไม่ถูกต้อง");

        DocumentReference offerRef = db.collection('offers').doc(offerId);
        DocumentSnapshot offerSnap = await transaction.get(offerRef);
        Map<String, dynamic> offerData = offerSnap.data() as Map<String, dynamic>;

        String targetItemId = offerData['target_listing_id'];
        String offeredItemId = offerData['offered_listing_id'];
        int escrowCoins = txData['escrow_coins'] ?? 0;
        DocumentReference? receiverRef; int newBalance = 0; String? receiverId;

        if (escrowCoins > 0) {
          int coinOffset = offerData['coin_offset'] ?? 0;
          String senderId = offerData['sender_id'];
          String targetUserId = offerData['target_user_id'] ?? offerData['target_owner_id'];
          receiverId = coinOffset > 0 ? targetUserId : senderId;
          receiverRef = db.collection('users').doc(receiverId);
          DocumentSnapshot receiverSnap = await transaction.get(receiverRef);
          int currentBalance = (receiverSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
          newBalance = currentBalance + escrowCoins;
        }

        transaction.update(db.collection('listings').doc(targetItemId), {'status': 'completed'});
        transaction.update(db.collection('listings').doc(offeredItemId), {'status': 'completed'});

        if (receiverRef != null && escrowCoins > 0 && receiverId != null) {
          transaction.update(receiverRef, {'coins_balance': newBalance});
          DocumentReference walletTxRef = db.collection('wallet_transactions').doc();
          transaction.set(walletTxRef, {
            'log_id': walletTxRef.id, 'user_id': receiverId, 'amount': escrowCoins, 'balance_after': newBalance,
            'type': 'escrow_release', 'status': 'success', 'reference_id': mainTxRef.id,
            'description': 'ได้รับเหรียญจากระบบกองกลาง (แลกเปลี่ยนสำเร็จ)', 'created_at': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(mainTxRef, { 'status': 'completed', 'updated_at': FieldValue.serverTimestamp() });
        transaction.update(offerRef, {'status': 'completed'});
      });

      String userName = await _getCurrentUserName();
      _sendSystemMessage('$userName ได้ยืนยันรหัสส่งมอบแล้ว การแลกเปลี่ยนสำเร็จลุล่วง!');

      if (mounted) {
        _showFloatingSnackBar('ยืนยันรหัสสำเร็จ ดีลจบสมบูรณ์');
        final txQuery = await db.collection('transactions').where('offer_id', isEqualTo: offerId).limit(1).get();
        if (txQuery.docs.isNotEmpty) {
           var txData = txQuery.docs.first.data() as Map<String, dynamic>;
           String partnerId = (txData['members'] as List).firstWhere((id) => id != currentUserId);
           String transactionId = txQuery.docs.first.id;
           Future.delayed(const Duration(milliseconds: 500), () {
             if (!mounted) return;
             _showRatingDialog(context, partnerId, transactionId);
           });
        }
      }
    } catch (e) {
      _showFloatingSnackBar('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  Future<void> _submitCounterOffer(String offerId, Map<String, dynamic> offerData, int amount, bool iWillPay) async {
    String senderId = offerData['sender_id'];
    int newCoinOffset = 0;
    if (currentUserId == senderId) {
      newCoinOffset = iWillPay ? amount : -amount;
    } else {
      newCoinOffset = iWillPay ? -amount : amount;
    }

    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({
      'coin_offset': newCoinOffset, 'last_offer_by': currentUserId, 'updated_at': FieldValue.serverTimestamp(),
    });

    String userName = await _getCurrentUserName();
    String actionText = amount == 0 ? 'เสนอแลกของต่อของ (ไม่ต้องเพิ่มเหรียญ)' : (iWillPay ? 'เสนอจ่ายเงินเพิ่ม $amount Coins' : 'ขอรับเงินเพิ่ม $amount Coins');
    _sendSystemMessage('$userName ได้ต่อรองเงื่อนไขใหม่: $actionText', type: 'system_log', notiType: 'system_offer');
  }

  Future<void> _submitReview(String targetUserId, String transactionId, int rating, String comment) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    try {
      final existingReview = await db.collection('reviews').where('transaction_id', isEqualTo: transactionId).where('reviewer_id', isEqualTo: currentUserId).get();
      if (existingReview.docs.isNotEmpty) {
        _showFloatingSnackBar('คุณได้ให้คะแนนดีลนี้ไปแล้ว', isError: true); return;
      }

      await db.runTransaction((transaction) async {
        DocumentReference userRef = db.collection('users').doc(targetUserId);
        DocumentSnapshot userSnap = await transaction.get(userRef);
        if (!userSnap.exists) throw Exception('ไม่พบข้อมูลผู้ใช้ของคู่กรณี');

        Map<String, dynamic> userData = userSnap.data() as Map<String, dynamic>;
        num currentSum = userData['total_rating_sum'] ?? 0;
        num currentCount = userData['rating_count'] ?? 0;
        num newSum = currentSum + rating; num newCount = currentCount + 1;
        double newScore = newSum / newCount;

        transaction.update(userRef, {
          'total_rating_sum': newSum, 'rating_count': newCount,
          'rating_scores': double.parse(newScore.toStringAsFixed(1)), 
        });

        DocumentReference reviewRef = db.collection('reviews').doc();
        transaction.set(reviewRef, {
          'review_id': reviewRef.id, 'transaction_id': transactionId, 'reviewer_id': currentUserId,
          'target_id': targetUserId, 'rating': rating, 'comment': comment, 'created_at': FieldValue.serverTimestamp(),
        });
      });
      _showFloatingSnackBar('ส่งคะแนนรีวิวเรียบร้อย ขอบคุณครับ!');
    } catch (e) {
      _showFloatingSnackBar('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  Future<List<String>> _getRoomParticipants() async {
    Set<String> users = {currentUserId};
    try {
      final roomDoc = await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).get();
      final roomData = roomDoc.data();
      if (roomData == null) return users.toList();

      final String? offerId = roomData['active_offer_id'];
      if (offerId != null) {
        final offerDoc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
        if (offerDoc.exists) {
          users.add(offerDoc.data()?['sender_id'] ?? '');
          users.add(offerDoc.data()?['target_user_id'] ?? '');
        }
      }
    } catch (e) { debugPrint("Error fetching participants: $e"); }
    users.removeWhere((id) => id.isEmpty); 
    return users.toList(); 
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final String text = _messageController.text.trim();
    _messageController.clear();

    List<String> roomUsers = await _getRoomParticipants();
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'sender_id': currentUserId, 'content': text, 'timestamp': FieldValue.serverTimestamp(), 'type': 'text',
    });

    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_text': text, 'last_message_type': 'text', 'last_sender_id': currentUserId,
      'read_by': [currentUserId], 'updated_at': FieldValue.serverTimestamp(),
      'participants': FieldValue.arrayUnion(roomUsers), 
      'read_timestamps.$currentUserId': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendSystemMessage(String text, {String type = 'system_log', String? notiType}) async {
    List<String> roomUsers = await _getRoomParticipants();
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'sender_id': 'system', 'content': text, 'timestamp': FieldValue.serverTimestamp(), 'type': type, 
    });
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_text': text, 'last_message_type': notiType ?? type, 'last_sender_id': currentUserId, 
      'read_by': [currentUserId], 'updated_at': FieldValue.serverTimestamp(),
      'participants': FieldValue.arrayUnion(roomUsers), 
      'read_timestamps.$currentUserId': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================
  // 🟢 DIALOG TRIGGER METHODS
  // ==========================================

  void _showCounterOfferDialog(BuildContext context, String offerId, Map<String, dynamic> offerData) {
    showDialog(
      context: context,
      builder: (context) => CounterOfferDialog(
        offerId: offerId,
        offerData: offerData,
        currentUserId: currentUserId,
        onSubmit: (amount, iWillPay) => _submitCounterOffer(offerId, offerData, amount, iWillPay),
      ),
    );
  }

  void _showOtpDialog(BuildContext context, String offerId) {
    showDialog(
      context: context,
      builder: (context) => HandoverOtpDialog(
        onSubmit: (otpCode) => _verifyHandoverCode(offerId, otpCode),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, String targetUserId, String transactionId) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => RatingReviewDialog(
        onSubmit: (rating, comment) => _submitReview(targetUserId, transactionId, rating, comment),
      ),
    );
  }

  // ==========================================
  // 🟢 CORE UI BUILD METHOD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).snapshots(),
        builder: (context, roomSnap) {
          if (!roomSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          
          final roomData = roomSnap.data!.data() as Map<String, dynamic>? ?? {};
          final String? activeOfferId = roomData['active_offer_id'];

          Map<String, dynamic> readTimestamps = roomData['read_timestamps'] ?? {};
          Timestamp? otherUserReadTime;
          readTimestamps.forEach((key, value) {
            if (key != currentUserId && value is Timestamp) otherUserReadTime = value;
          });
          
          final List readBy = roomData['read_by'] ?? [];
          final bool isReadByOther = readBy.any((id) => id != currentUserId);

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white, elevation: 0.5,
              iconTheme: const IconThemeData(color: Colors.black87),
              title: FutureBuilder<Map<String, dynamic>>(
                future: _getTargetItemInfo(activeOfferId),
                builder: (context, itemSnap) {
                  if (!itemSnap.hasData || itemSnap.data!.isEmpty) {
                    return const Text('เจรจาแลกเปลี่ยน', style: TextStyle(color: Colors.black87, fontSize: 16));
                  }
                  return Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36, height: 36, color: Colors.grey.shade100,
                          child: itemSnap.data!['thumbnail_url'] != null && itemSnap.data!['thumbnail_url'] != ''
                              ? Image.network(itemSnap.data!['thumbnail_url'], fit: BoxFit.cover)
                              : const Icon(Icons.image, size: 20, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(itemSnap.data!['title'] ?? 'สิ่งของแลกเปลี่ยน', style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const Text('รายละเอียดเพิ่มเติมกดดูที่ข้อเสนอ', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      )
                    ],
                  );
                }
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final messages = snapshot.data!.docs;

                      int latestReadIndex = -1;
                      if (otherUserReadTime != null) {
                        for (int i = 0; i < messages.length; i++) {
                          var msgData = messages[i].data() as Map<String, dynamic>;
                          if (msgData['sender_id'] == currentUserId) {
                            Timestamp? msgTime = msgData['timestamp'] as Timestamp?;
                            if (msgTime != null && msgTime.compareTo(otherUserReadTime!) <= 0) { latestReadIndex = i; break; }
                          }
                        }
                      } else if (isReadByOther) {
                        for (int i = 0; i < messages.length; i++) {
                          var msgData = messages[i].data() as Map<String, dynamic>;
                          if (msgData['sender_id'] == currentUserId) { latestReadIndex = i; break; }
                        }
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        reverse: true, itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index].data() as Map<String, dynamic>;
                          bool isMe = msg['sender_id'] == currentUserId;
                          String type = msg['type'] ?? 'text';
                          String timeStr = _formatTime(msg['timestamp']);

                          if (msg['sender_id'] == 'system' && type != 'system_offer') {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                child: Text(msg['content'], style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            );
                          }

                          if (type == 'system_offer') {
                            return SystemOfferCard(
                              msgData: msg,
                              activeOfferId: activeOfferId,
                              currentUserId: currentUserId,
                              onCancel: () => _cancelOffer(activeOfferId!),
                              onReject: () => _rejectOffer(activeOfferId!),
                              onAccept: () => _acceptOffer(activeOfferId!),
                              onCounter: (offerData) => _showCounterOfferDialog(context, activeOfferId!, offerData),
                              onVerifyOtp: () => _showOtpDialog(context, activeOfferId!),
                              onCancelDeal: () => _cancelAcceptedDeal(activeOfferId!, 'เปลี่ยนใจไม่แลกแล้ว'),
                              onOpenRating: (partnerId, txId) => _showRatingDialog(context, partnerId, txId),
                            );
                          }

                          bool showTimeByDefault = true; bool showAvatar = true;
                          if (index > 0) { 
                            final newerMsg = messages[index - 1].data() as Map<String, dynamic>;
                            final newerTime = newerMsg['timestamp'] as Timestamp?;
                            final currentTime = msg['timestamp'] as Timestamp?;
                            if (newerMsg['sender_id'] == msg['sender_id'] && newerTime != null && currentTime != null) {
                              if (newerTime.toDate().difference(currentTime.toDate()).inMinutes.abs() < 3) {
                                showTimeByDefault = false; showAvatar = false; 
                              }
                            }
                          }

                          return ChatBubbleWidget(
                            msg: msg, isMe: isMe, timeStr: timeStr,
                            showTimeByDefault: showTimeByDefault, showAvatar: showAvatar,
                            isLatestRead: index == latestReadIndex,
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                  child: SafeArea(
                    bottom: true, top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'พิมพ์ข้อความ...', filled: true, fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: const Color(0xFF008080),
                          child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}