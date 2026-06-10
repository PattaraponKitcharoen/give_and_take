import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_detail_screen.dart';
import 'user_profile_screen.dart'; // 🟢 ดึงหน้าโปรไฟล์มาใช้

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

  // 🟢 อัปเดต: เก็บเวลาที่อ่านล่าสุดไว้ด้วย (read_timestamps)
  Future<void> _markAsRead() async {
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).set({
      'read_by': FieldValue.arrayUnion([currentUserId]),
      'read_timestamps': {
        currentUserId: FieldValue.serverTimestamp(),
      }
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
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
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
      
      // 🟢 แยกการแสดงผลให้ชัดเจน:
      // ถ้า "เรา" คือคนทักไปยื่นข้อเสนอ (sender) -> ต้องเห็นของเป้าหมายที่อยากได้ (target)
      // ถ้า "เรา" คือคนถูกทัก (receiver) -> ต้องเห็นของที่เขาเอามาเสนอ (offered)
      String itemToShowId = (currentUserId == senderId) ? targetId : offeredId;
      
      // ถ้ามี ID ให้ไปดึงข้อมูลสิ่งของมาแสดง
      if (itemToShowId.isNotEmpty) {
        final itemDoc = await FirebaseFirestore.instance.collection('listings').doc(itemToShowId).get();
        if (itemDoc.exists) {
          return itemDoc.data() as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Error getting item info: $e');
    }
    return {};
  }

  Future<void> _cancelOffer(String offerId) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).delete();
    String userName = await _getCurrentUserName();
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_type': 'system_cancel',
      'updated_at': FieldValue.serverTimestamp(),
    });
    _sendSystemMessage('$userName ได้ยกเลิกข้อเสนอนี้แล้ว', type: 'system_cancel');
  }

  Future<void> _rejectOffer(String offerId) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({'status': 'rejected'});
    String userName = await _getCurrentUserName();
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_type': 'system_reject',
      'updated_at': FieldValue.serverTimestamp(),
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
          DocumentReference payerRef = db.collection('users').doc(payerId);
          DocumentSnapshot payerSnap = await transaction.get(payerRef);
          if (!payerSnap.exists) throw Exception("ไม่พบข้อมูลผู้ใช้งาน");
          
          int currentBalance = (payerSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
          if (currentBalance < amountToPay) throw Exception("ยอดเงินของฝั่งที่ต้องจ่ายไม่เพียงพอ");
          
          int newBalance = currentBalance - amountToPay;
          transaction.update(payerRef, {'coins_balance': newBalance});

          DocumentReference walletTxRef = db.collection('wallet_transactions').doc();
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
        DocumentReference mainTxRef = db.collection('transactions').doc();
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
        transaction.update(db.collection('listings').doc(targetItemId), {'status': 'in_progress'});
        transaction.update(db.collection('listings').doc(offeredItemId), {'status': 'in_progress'});
      });

      String userName = await _getCurrentUserName();
      await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
        'last_message_type': 'system_accept',
        'updated_at': FieldValue.serverTimestamp(),
      });
      _sendSystemMessage('$userName ตกลงแลกเปลี่ยนแล้ว และระบบได้ทำการล็อกเหรียญไว้ในกองกลาง', type: 'system_accept');
      _showFloatingSnackBar('เริ่มการแลกเปลี่ยนเรียบร้อยแล้ว');
    } catch (e) {
      _showFloatingSnackBar('ไม่สามารถทำรายการได้: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
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

      if (users.length <= 1) {
        final msgSnap = await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').get();
        for (var doc in msgSnap.docs) {
          final data = doc.data();
          final sender = data['sender_id'];
          if (sender != 'system' && sender != null) users.add(sender); 
          if (data['type'] == 'system_offer' && data['offer_data'] != null) {
            final tOwner = data['offer_data']['target_item']?['owner_id'];
            final oOwner = data['offer_data']['offered_item']?['owner_id'];
            if (tOwner != null) users.add(tOwner);
            if (oOwner != null) users.add(oOwner);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching participants: $e");
    }
    users.removeWhere((id) => id.isEmpty); 
    return users.toList(); 
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final String text = _messageController.text.trim();
    _messageController.clear();

    List<String> roomUsers = await _getRoomParticipants();

    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'sender_id': currentUserId,
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });

    // 🟢 อัปเดตเวลาที่เราอ่านล่าสุดเข้าไปด้วย
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_text': text,
      'last_message_type': 'text',
      'last_sender_id': currentUserId,
      'read_by': [currentUserId], 
      'updated_at': FieldValue.serverTimestamp(),
      'participants': FieldValue.arrayUnion(roomUsers), 
      'read_timestamps.$currentUserId': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendSystemMessage(String text, {String type = 'system_log', String? notiType}) async {
    List<String> roomUsers = await _getRoomParticipants();

    // 1. บันทึกลงใน messages (ใช้ type เดิม เพื่อให้แสดงเป็นกล่องสีเทาตรงกลางแชท)
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'sender_id': 'system',
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type, 
    });
    
    // 2. อัปเดตข้อมูลหน้าห้องแชท (ใช้ notiType เพื่อให้หน้า Noti ดึงไปแสดงผลตามที่เราต้องการ)
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_text': text,
      'last_message_type': notiType ?? type, // 🟢 สับขาหลอกตรงนี้: ถ้ามี notiType ให้ใช้ทับไปเลย
      'last_sender_id': currentUserId, 
      'read_by': [currentUserId], 
      'updated_at': FieldValue.serverTimestamp(),
      'participants': FieldValue.arrayUnion(roomUsers), 
      'read_timestamps.$currentUserId': FieldValue.serverTimestamp(),
    });
  }

  Widget _buildItemThumbnail(BuildContext context, Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(itemData: item))),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: (item['thumbnail_url'] != null && item['thumbnail_url'] != '') 
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item['thumbnail_url'], fit: BoxFit.cover))
                : const Icon(Icons.image, color: Colors.grey, size: 30),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(item['title'] ?? 'ไม่มีชื่อ', overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
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
        if (txData['status'] != 'in_progress') throw Exception("ไม่สามารถยกเลิกได้ เนื่องจากสถานะไม่ใช่กำลังดำเนินการ");

        DocumentReference offerRef = db.collection('offers').doc(offerId);
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
            'log_id': walletTxRef.id,
            'user_id': payerId,
            'amount': escrowCoins,
            'balance_after': newBalance,
            'type': 'refund',
            'status': 'success',
            'reference_id': mainTxRef.id,
            'description': 'คืนเหรียญจากระบบกองกลาง (ยกเลิกการแลกเปลี่ยน)',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(mainTxRef, {
          'status': 'cancelled',
          'cancel_reason': reason,
          'updated_at': FieldValue.serverTimestamp(),
        });
        transaction.update(offerRef, {'status': 'cancelled'});
      });

      String userName = await _getCurrentUserName();
      _sendSystemMessage('$userName ได้ยกเลิกการแลกเปลี่ยน ระบบได้ทำการคืนสิ่งของและเหรียญเรียบร้อยแล้ว', type: 'system_cancel'); 
      _showFloatingSnackBar('ยกเลิกการแลกเปลี่ยนสำเร็จ');
    } catch (e) {
      _showFloatingSnackBar('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  void _showCounterOfferDialog(BuildContext context, String offerId, Map<String, dynamic> offerData) {
    final TextEditingController amountController = TextEditingController();
    String offerType = 'give'; // โหมดเริ่มต้น

    // ฟังก์ชันช่วยบวกเหรียญแบบด่วน
    void addCoins(int amount, StateSetter setState) {
      int current = int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
      amountController.text = (current + amount).toString();
      amountController.selection = TextSelection.fromPosition(TextPosition(offset: amountController.text.length));
    }

    // ฟังก์ชันสร้างปุ่ม Segment
    Widget buildSegmentButton(String text, IconData icon, String value, String currentValue, VoidCallback onTap) {
      bool isSelected = (value == currentValue);
      Color activeColor = value == 'give' ? const Color(0xFF008080) : (value == 'ask' ? Colors.orange : Colors.blueGrey);
      
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: isSelected ? activeColor : Colors.grey.shade400),
                const SizedBox(height: 6),
                Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? activeColor : Colors.grey.shade500)),
              ],
            ),
          ),
        ),
      );
    }

    // ฟังก์ชันสร้างปุ่ม Quick Add
    Widget buildQuickAddButton(String text, VoidCallback onTap) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.orange.shade200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🟢 Header & Close Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Counter Offer', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87)),
                              SizedBox(height: 4),
                              Text('ปรับเปลี่ยนข้อเสนอของคุณ', style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 16, color: Colors.black54),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 28),

                      // 🟢 Negotiation Mode (Segmented Control)
                      const Text('NEGOTIATION MODE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          children: [
                            buildSegmentButton('Give Coins', Icons.payments_outlined, 'give', offerType, () => setState(() => offerType = 'give')),
                            buildSegmentButton('Trade Only', Icons.handshake_outlined, 'none', offerType, () => setState(() { offerType = 'none'; amountController.clear(); })),
                            buildSegmentButton('Ask Coins', Icons.request_page_outlined, 'ask', offerType, () => setState(() => offerType = 'ask')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 🟢 Coin Amount Section
                      if (offerType != 'none') ...[
                        const Text('COIN AMOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade200, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                ),
                                child: const Icon(Icons.attach_money, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: amountController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(color: Colors.grey.shade300),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              const Text('COINS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.orange)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 🟢 Quick Add Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            buildQuickAddButton('+50', () => addCoins(50, setState)),
                            buildQuickAddButton('+100', () => addCoins(100, setState)),
                            buildQuickAddButton('+200', () => addCoins(200, setState)),
                            buildQuickAddButton('+500', () => addCoins(500, setState)),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ] else ...[
                        // 🟢 Trade Only Placeholder
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            color: const Color(0xFF008080).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF008080).withOpacity(0.2)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.sync_alt, size: 40, color: Color(0xFF008080)),
                              SizedBox(height: 12),
                              Text('แลกของต่อของ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF008080))),
                              Text('ไม่มีการใช้เหรียญในข้อเสนอนี้', style: TextStyle(color: Colors.blueGrey)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // 🟢 Action Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            int amount = 0;
                            if (offerType != 'none') {
                              amount = int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
                              if (amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาระบุจำนวนเหรียญให้ถูกต้อง')));
                                return;
                              }
                            }
                            Navigator.pop(context);
                            bool iWillPay = (offerType == 'give'); 
                            _submitCounterOffer(offerId, offerData, amount, iWillPay);
                          },
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          label: const Text('Send Counter Offer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50), // สีเขียวสไตล์ Confirmation
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.blueGrey)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
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
      'coin_offset': newCoinOffset,
      'last_offer_by': currentUserId, 
      'updated_at': FieldValue.serverTimestamp(),
    });

    String userName = await _getCurrentUserName();
    
    String actionText;
    if (amount == 0) {
      actionText = 'เสนอแลกของต่อของ (ไม่ต้องเพิ่มเหรียญ)';
    } else {
      actionText = iWillPay ? 'เสนอจ่ายเงินเพิ่ม $amount Coins' : 'ขอรับเงินเพิ่ม $amount Coins';
    }
    
    // 🟢 แก้ตรงนี้: ส่ง type เป็น log ธรรมดาสำหรับหน้าแชท แต่บังคับให้ Noti เห็นเป็น system_offer
    _sendSystemMessage(
      '$userName ได้ต่อรองเงื่อนไขใหม่: $actionText', 
      type: 'system_log', 
      notiType: 'system_offer'
    );
  }

  void _showOtpDialog(BuildContext context, String offerId) {
    final TextEditingController otpController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการรับของ', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'กรอกรหัส 6 หลักของอีกฝ่าย'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _verifyHandoverCode(offerId, otpController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
        DocumentReference? receiverRef;
        int newBalance = 0;
        String? receiverId;

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
            'log_id': walletTxRef.id,
            'user_id': receiverId,
            'amount': escrowCoins,
            'balance_after': newBalance,
            'type': 'escrow_release',
            'status': 'success',
            'reference_id': mainTxRef.id,
            'description': 'ได้รับเหรียญจากระบบกองกลาง (แลกเปลี่ยนสำเร็จ)',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(mainTxRef, {
          'status': 'completed',
          'updated_at': FieldValue.serverTimestamp(),
        });
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
           Future.delayed(const Duration(milliseconds: 500), () => _showRatingDialog(context, partnerId, transactionId));
        }
      }
    } catch (e) {
      _showFloatingSnackBar('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  void _showRatingDialog(BuildContext context, String targetUserId, String transactionId) {
    int selectedRating = 5; 
    final TextEditingController commentController = TextEditingController(); 

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('ให้คะแนนการแลกเปลี่ยน', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ความประทับใจต่อคู่กรณีในดีลนี้', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(index < selectedRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
                          onPressed: () => setState(() => selectedRating = index + 1),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'เขียนรีวิวสั้นๆ (ไม่บังคับ)...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('ข้าม', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _submitReview(targetUserId, transactionId, selectedRating, commentController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
                  child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _submitReview(String targetUserId, String transactionId, int rating, String comment) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    try {
      final existingReview = await db.collection('reviews').where('transaction_id', isEqualTo: transactionId).where('reviewer_id', isEqualTo: currentUserId).get();
      if (existingReview.docs.isNotEmpty) {
        _showFloatingSnackBar('คุณได้ให้คะแนนดีลนี้ไปแล้ว', isError: true);
        return;
      }

      await db.runTransaction((transaction) async {
        DocumentReference userRef = db.collection('users').doc(targetUserId);
        DocumentSnapshot userSnap = await transaction.get(userRef);
        if (!userSnap.exists) throw Exception('ไม่พบข้อมูลผู้ใช้ของคู่กรณี');

        Map<String, dynamic> userData = userSnap.data() as Map<String, dynamic>;
        num currentSum = userData['total_rating_sum'] ?? 0;
        num currentCount = userData['rating_count'] ?? 0;
        num newSum = currentSum + rating;
        num newCount = currentCount + 1;
        double newScore = newSum / newCount;

        transaction.update(userRef, {
          'total_rating_sum': newSum,
          'rating_count': newCount,
          'rating_scores': double.parse(newScore.toStringAsFixed(1)), 
        });

        DocumentReference reviewRef = db.collection('reviews').doc();
        transaction.set(reviewRef, {
          'review_id': reviewRef.id,
          'transaction_id': transactionId,
          'reviewer_id': currentUserId,
          'target_id': targetUserId,
          'rating': rating,
          'comment': comment,
          'created_at': FieldValue.serverTimestamp(),
        });
      });
      _showFloatingSnackBar('ส่งคะแนนรีวิวเรียบร้อย ขอบคุณครับ!');
    } catch (e) {
      _showFloatingSnackBar('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

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

          // 🟢 คำนวณหาเวลาที่อีกฝ่ายเปิดอ่านล่าสุด
          Map<String, dynamic> readTimestamps = roomData['read_timestamps'] ?? {};
          Timestamp? otherUserReadTime;
          readTimestamps.forEach((key, value) {
            if (key != currentUserId && value is Timestamp) {
              otherUserReadTime = value;
            }
          });
          
          final List readBy = roomData['read_by'] ?? [];
          final bool isReadByOther = readBy.any((id) => id != currentUserId);

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              iconTheme: const IconThemeData(color: Colors.black87),
              title: FutureBuilder<Map<String, dynamic>>(
                future: _getTargetItemInfo(activeOfferId),
                builder: (context, itemSnap) {
                  if (!itemSnap.hasData || itemSnap.data!.isEmpty) {
                    return const Text('เจรจาแลกเปลี่ยน', style: TextStyle(color: Colors.black87, fontSize: 16));
                  }
                  final itemData = itemSnap.data!;
                  final title = itemData['title'] ?? 'สิ่งของแลกเปลี่ยน';
                  final img = itemData['thumbnail_url'] ?? '';

                  return Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36, height: 36,
                          color: Colors.grey.shade100,
                          child: img.isNotEmpty ? Image.network(img, fit: BoxFit.cover) : const Icon(Icons.image, size: 20, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    stream: FirebaseFirestore.instance
                        .collection('chat_rooms')
                        .doc(widget.roomId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final messages = snapshot.data!.docs;

                      // 🟢 คำนวณหา index ของข้อความล่าสุดที่เราส่งและอีกฝ่ายอ่านแล้ว
                      int latestReadIndex = -1;
                      if (otherUserReadTime != null) {
                        for (int i = 0; i < messages.length; i++) {
                          var msgData = messages[i].data() as Map<String, dynamic>;
                          if (msgData['sender_id'] == currentUserId) {
                            Timestamp? msgTime = msgData['timestamp'] as Timestamp?;
                            if (msgTime != null && msgTime.compareTo(otherUserReadTime!) <= 0) {
                              latestReadIndex = i;
                              break;
                            }
                          }
                        }
                      } else if (isReadByOther) {
                        for (int i = 0; i < messages.length; i++) {
                          var msgData = messages[i].data() as Map<String, dynamic>;
                          if (msgData['sender_id'] == currentUserId) {
                            latestReadIndex = i;
                            break;
                          }
                        }
                      }

                      return ListView.builder(
                        // 🟢 ปรับลดระยะห่างระหว่างบับเบิลกับช่องพิมพ์ให้แคบลง
                        padding: const EdgeInsets.only(top: 16, bottom: 8), 
                        reverse: true, 
                        itemCount: messages.length,
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
                            final offerDataFromMsg = msg['offer_data'] ?? {};
                            final targetItem = offerDataFromMsg['target_item'] ?? {};
                            final offeredItem = offerDataFromMsg['offered_item'] ?? {};
                            
                            bool isSender = (msg['sender_id'] == currentUserId);
                            var myItemData = isSender ? offeredItem : targetItem;
                            var theirItemData = isSender ? targetItem : offeredItem;

                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('offers').doc(activeOfferId).snapshots(),
                              builder: (context, offerSnap) {
                                String offerStatus = 'cancelled';
                                Map<String, dynamic> offerData = {};
                                
                                if (offerSnap.hasData && offerSnap.data!.exists) {
                                  offerData = offerSnap.data!.data() as Map<String, dynamic>;
                                  offerStatus = offerData['status'] ?? 'pending';
                                }

                                String lastOfferBy = offerData['last_offer_by'] ?? offerData['sender_id'] ?? '';
                                bool isMyTurn = (lastOfferBy != currentUserId); 
                                int currentOffset = offerData['coin_offset'] ?? 0;
                                String offsetText = 'แลกของต่อของ (ไม่มีการเพิ่มเหรียญ)';
                                Color offsetColor = Colors.black54;

                                if (currentOffset > 0) {
                                  bool iAmSender = (currentUserId == offerData['sender_id']);
                                  offsetText = iAmSender ? 'คุณเสนอจ่ายเพิ่ม $currentOffset Coins' : 'อีกฝ่ายเสนอจ่ายเพิ่ม $currentOffset Coins';
                                  offsetColor = iAmSender ? Colors.red : Colors.green;
                                } else if (currentOffset < 0) {
                                  bool iAmSender = (currentUserId == offerData['sender_id']);
                                  offsetText = iAmSender ? 'คุณขอรับเงินเพิ่ม ${currentOffset.abs()} Coins' : 'อีกฝ่ายขอรับเงินเพิ่ม ${currentOffset.abs()} Coins';
                                  offsetColor = iAmSender ? Colors.green : Colors.red;
                                }

                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF008080), width: 2),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('ข้อเสนอแลกเปลี่ยน', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildItemThumbnail(context, theirItemData),
                                          const Icon(Icons.sync_alt, color: Color(0xFF008080), size: 32),
                                          _buildItemThumbnail(context, myItemData),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.monetization_on, color: offsetColor, size: 16),
                                            const SizedBox(width: 8),
                                            Text(offsetText, style: TextStyle(color: offsetColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 16),
                                      if (offerStatus == 'pending') ...[
                                        if (!isMyTurn)
                                          Column(
                                            children: [
                                              const Text('รออีกฝ่ายพิจารณาข้อเสนอ...', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton(
                                                  onPressed: () => _cancelOffer(activeOfferId!),
                                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                                  child: const Text('ยกเลิกข้อเสนอ'),
                                                ),
                                              ),
                                            ]
                                          )
                                        else 
                                          Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(child: OutlinedButton(onPressed: () => _rejectOffer(activeOfferId!), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('ปฏิเสธ'))),
                                                  const SizedBox(width: 10),
                                                  Expanded(child: ElevatedButton(onPressed: () => _showCounterOfferDialog(context, activeOfferId!, offerData), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('ต่อรอง', style: TextStyle(color: Colors.white)))),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(onPressed: () => _acceptOffer(activeOfferId!), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)), child: const Text('ยอมรับข้อเสนอ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                              ),
                                            ],
                                          )
                                      ] else if (offerStatus == 'accepted' || offerStatus == 'in_progress') ...[
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: const Text('ตกลงแลกเปลี่ยนแล้ว', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance.collection('transactions').where('offer_id', isEqualTo: activeOfferId).limit(1).snapshots(),
                                          builder: (context, txSnap) {
                                            if (!txSnap.hasData || txSnap.data!.docs.isEmpty) return const SizedBox();
                                            var txData = txSnap.data!.docs.first.data() as Map<String, dynamic>;
                                            var codes = txData['verification_codes'] ?? {};
                                            String myCode = codes[currentUserId] ?? '------';
                                            return Column(
                                              children: [
                                                const SizedBox(height: 16),
                                                Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Column(children: [const Text('รหัสของคุณ (ให้อีกฝ่ายกรอก)', style: TextStyle(color: Colors.black54)), Text(myCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 5, color: Color(0xFF008080)))])),
                                                const SizedBox(height: 12),
                                                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _showOtpDialog(context, activeOfferId!), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)), child: const Text('กรอกรหัสของอีกฝ่าย', style: TextStyle(color: Colors.white)))),
                                                const SizedBox(height: 8),
                                                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _cancelAcceptedDeal(activeOfferId!, 'เปลี่ยนใจไม่แลกแล้ว'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('ยกเลิกดีลนี้'))),
                                              ],
                                            );
                                          }
                                        )
                                      ] else ...[
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: offerStatus == 'completed' ? Colors.green.shade50 : (offerStatus == 'rejected' ? Colors.orange.shade50 : Colors.red.shade50), borderRadius: BorderRadius.circular(8)), child: Text(offerStatus == 'completed' ? 'แลกเปลี่ยนสำเร็จสมบูรณ์' : (offerStatus == 'rejected' ? 'ถูกปฏิเสธ' : 'ถูกยกเลิกแล้ว'), style: TextStyle(fontWeight: FontWeight.bold, color: offerStatus == 'completed' ? Colors.green : (offerStatus == 'rejected' ? Colors.orange : Colors.red)))),
                                      if (offerStatus == 'completed') ...[
                                        FutureBuilder<QuerySnapshot>(
                                          future: FirebaseFirestore.instance.collection('transactions').where('offer_id', isEqualTo: activeOfferId).limit(1).get(),
                                          builder: (context, txSnap) {
                                            if (!txSnap.hasData || txSnap.data!.docs.isEmpty) return const SizedBox();
                                            String transactionId = txSnap.data!.docs.first.id;
                                            var txData = txSnap.data!.docs.first.data() as Map<String, dynamic>;
                                            String partnerId = (txData['members'] as List).firstWhere((id) => id != currentUserId);
                                            return StreamBuilder<QuerySnapshot>(
                                              stream: FirebaseFirestore.instance.collection('reviews').where('transaction_id', isEqualTo: transactionId).where('reviewer_id', isEqualTo: currentUserId).snapshots(),
                                              builder: (context, reviewSnap) {
                                                bool hasReviewed = reviewSnap.hasData && reviewSnap.data!.docs.isNotEmpty;
                                                return Column(
                                                  children: [
                                                    const SizedBox(height: 12),
                                                    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: hasReviewed ? null : () => _showRatingDialog(context, partnerId, transactionId), icon: Icon(hasReviewed ? Icons.check_circle : Icons.star, color: hasReviewed ? Colors.white70 : Colors.white, size: 20), label: Text(hasReviewed ? 'คุณให้คะแนนเรียบร้อยแล้ว' : 'ให้คะแนนคู่กรณี', style: TextStyle(color: hasReviewed ? Colors.white70 : Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, disabledBackgroundColor: Colors.grey.shade400))),
                                                  ],
                                                );
                                              },
                                            );
                                          }
                                        ),
                                      ]
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        }

                        // 🟢 ลอจิกซ่อนเวลาถ้ารัวแชท
                        bool showTimeByDefault = true;
                        bool showAvatar = true;

                        if (index > 0) { 
                          final newerMsg = messages[index - 1].data() as Map<String, dynamic>;
                          final newerTime = newerMsg['timestamp'] as Timestamp?;
                          final currentTime = msg['timestamp'] as Timestamp?;
                          if (newerMsg['sender_id'] == msg['sender_id'] && newerTime != null && currentTime != null) {
                            if (newerTime.toDate().difference(currentTime.toDate()).inMinutes.abs() < 3) {
                              showTimeByDefault = false; 
                              showAvatar = false; 
                            }
                          }
                        }

                        // 🟢 ส่งค่าไปให้ Widget วาด "อ่านแล้ว"
                        final bool isLatestRead = (index == latestReadIndex);

                        return ChatBubbleWidget(
                          msg: msg,
                          isMe: isMe,
                          timeStr: timeStr,
                          showTimeByDefault: showTimeByDefault,
                          showAvatar: showAvatar,
                          isLatestRead: isLatestRead,
                        );
                      },
                    );
                  },
                ),
                ),
                
                // 🟢 ลดช่องว่างด้านล่าง
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // ปรับลงเหลือ 8
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                  child: SafeArea(
                    bottom: true, top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'พิมพ์ข้อความ...',
                              filled: true,
                              fillColor: Colors.grey.shade100,
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

// 🟢 Widget แยกสำหรับวาดบับเบิลแชทโดยเฉพาะ (อยู่ล่างสุดของไฟล์)
class ChatBubbleWidget extends StatefulWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String timeStr;
  final bool showTimeByDefault;
  final bool showAvatar;
  final bool isLatestRead;

  const ChatBubbleWidget({
    super.key,
    required this.msg,
    required this.isMe,
    required this.timeStr,
    required this.showTimeByDefault,
    required this.showAvatar,
    required this.isLatestRead,
  });

  @override
  State<ChatBubbleWidget> createState() => _ChatBubbleWidgetState();
}

class _ChatBubbleWidgetState extends State<ChatBubbleWidget> {
  bool _isTapped = false; 

  @override
  Widget build(BuildContext context) {
    bool showTime = widget.showTimeByDefault || _isTapped;
    
    if (widget.isMe) {
      return Padding(
        padding: EdgeInsets.only(right: 16, left: 60, top: 2, bottom: widget.showTimeByDefault ? 8 : 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => setState(() => _isTapped = !_isTapped),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF008080),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: const Radius.circular(16),
                    bottomRight: Radius.circular(widget.showTimeByDefault ? 4 : 16),
                  ),
                ),
                child: Text(widget.msg['content'], style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showTime) 
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 10))),
                  
                  if (widget.isLatestRead)
                    Padding(
                      padding: const EdgeInsets.only(top: 2), 
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.done_all, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text('อ่านแล้ว', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ),
                ],
              ),
            )
          ]
        )
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(left: 16, right: 60, top: 2, bottom: widget.showTimeByDefault ? 8 : 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.showAvatar) ...[
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: widget.msg['sender_id']))),
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(widget.msg['sender_id']).get(),
                  builder: (context, userSnap) {
                    String profileImg = '';
                    if (userSnap.hasData && userSnap.data!.exists) profileImg = (userSnap.data!.data() as Map<String, dynamic>)['profile_img_url'] ?? '';
                    return CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                      child: profileImg.isEmpty ? const Icon(Icons.person, size: 14, color: Colors.white) : null,
                    );
                  }
                ),
              ),
            ] else ...[
              const SizedBox(width: 28), 
            ],
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isTapped = !_isTapped),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(widget.showTimeByDefault ? 4 : 16),
                        ),
                        border: Border.all(color: Colors.grey.shade200)
                      ),
                      child: Text(widget.msg['content'], style: const TextStyle(color: Colors.black87, fontSize: 14)),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: showTime 
                      ? Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)))
                      : const SizedBox.shrink(),
                  )
                ]
              )
            )
          ]
        )
      );
    }
  }
}