import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  const ChatScreen({super.key, required this.roomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final String text = _messageController.text.trim();
    _messageController.clear();

    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'sender_id': currentUserId,
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });

    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_text': text,
      'last_sender_id': currentUserId,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ฟังก์ชันช่วยดึงชื่อผู้ใช้งานปัจจุบันจาก Firestore
  Future<String> _getCurrentUserName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (doc.exists && doc.data() != null) {
        final name = doc.data()!['name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString();
        }
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
    return 'ผู้ใช้งาน';
  }

  // ฟังก์ชัน: ยกเลิกข้อเสนอ (ฝั่งคนส่ง)
  Future<void> _cancelOffer(String offerId) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).delete();
    String userName = await _getCurrentUserName();
    _sendSystemMessage('$userName ได้ยกเลิกข้อเสนอนี้แล้ว');
  }

  // ฟังก์ชัน: ปฏิเสธข้อเสนอ (ฝั่งคนรับ)
  Future<void> _rejectOffer(String offerId) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({'status': 'rejected'});
    String userName = await _getCurrentUserName();
    _sendSystemMessage('$userName ได้ปฏิเสธข้อเสนอนี้แล้ว');
  }

  // ฟังก์ชัน: ยอมรับข้อเสนอ พร้อมระบบหักเงินเข้ากองกลาง (Escrow)
  Future<void> _acceptOffer(String offerId) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      await db.runTransaction((transaction) async {
        // 1. อ่านข้อมูล Offer ออกมาก่อน
        DocumentReference offerRef = db.collection('offers').doc(offerId);
        DocumentSnapshot offerSnap = await transaction.get(offerRef);
        
        if (!offerSnap.exists) throw Exception("ไม่พบข้อมูลข้อเสนอ");
        Map<String, dynamic> offerData = offerSnap.data() as Map<String, dynamic>;
        
        int coinOffset = offerData['coin_offset'] ?? 0;
        String senderId = offerData['sender_id'];
        String targetUserId = offerData['target_user_id'];
        
        // ดึง ID ของสิ่งของจากฐานข้อมูลโดยตรง (แก้ปัญหาค่า Null)
        String targetItemId = offerData['target_listing_id'];
        String offeredItemId = offerData['offered_listing_id'];
        
        // ตรวจสอบว่าใครคือคนจ่าย และต้องจ่ายเท่าไหร่
        String? payerId;
        int amountToPay = 0;
        
        if (coinOffset > 0) {
          payerId = senderId;
          amountToPay = coinOffset;
        } else if (coinOffset < 0) {
          payerId = targetUserId;
          amountToPay = coinOffset.abs();
        }

        // 2. ถ้ามีคนต้องจ่ายเงิน เช็คยอดเงินในกระเป๋าคนจ่าย
        if (payerId != null && amountToPay > 0) {
          DocumentReference payerRef = db.collection('users').doc(payerId);
          DocumentSnapshot payerSnap = await transaction.get(payerRef);
          
          if (!payerSnap.exists) throw Exception("ไม่พบข้อมูลผู้ใช้งาน");
          
          int currentBalance = (payerSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
          
          if (currentBalance < amountToPay) {
            throw Exception("ยอดเงินของฝั่งที่ต้องจ่ายไม่เพียงพอ");
          }
          
          int newBalance = currentBalance - amountToPay;

          // สั่งหักเงินคนจ่าย
          transaction.update(payerRef, {'coins_balance': newBalance});

          // บันทึกประวัติลง wallet_transactions
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

        // 3. สร้างข้อมูลในตาราง transactions
        String verifyCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
        DocumentReference mainTxRef = db.collection('transactions').doc();
        
        transaction.set(mainTxRef, {
          'transaction_id': mainTxRef.id,
          'offer_id': offerId,
          'listings': [offeredItemId, targetItemId],
          'members': [senderId, targetUserId],
          'escrow_coins': amountToPay,
          'status': 'in_progress',
          'cancel_reason': '',
          'verification_code': verifyCode,
          'confirmed_by_user_ids': [],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // 4. อัปเดตสถานะของ Offer และ Listings
        transaction.update(offerRef, {'status': 'accepted'});
        
        DocumentReference targetItemRef = db.collection('listings').doc(targetItemId);
        DocumentReference offeredItemRef = db.collection('listings').doc(offeredItemId);
        transaction.update(targetItemRef, {'status': 'in_progress'});
        transaction.update(offeredItemRef, {'status': 'in_progress'});
      });

      // 5. เมื่อ Transaction ทั้งหมดสำเร็จ ค่อยยิงข้อความระบบแจ้งเตือน
      String userName = await _getCurrentUserName();
      _sendSystemMessage('$userName ตกลงแลกเปลี่ยนแล้ว และระบบได้ทำการล็อกเหรียญไว้ในกองกลาง');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เริ่มการแลกเปลี่ยนเรียบร้อยแล้ว')));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถทำรายการได้: ${e.toString().replaceAll('Exception: ', '')}')));
      }
    }
  }

  // ตัวช่วยยิงข้อความระบบ
  Future<void> _sendSystemMessage(String text) async {
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'sender_id': 'system',
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system_log',
    });
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_text': text,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Widget ช่วยสร้างรูปสิ่งของ
  Widget _buildItemThumbnail(BuildContext context, Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(itemData: item)));
      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('เจรจาแลกเปลี่ยน', style: TextStyle(color: Colors.black87, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).snapshots(),
        builder: (context, roomSnap) {
          if (!roomSnap.hasData) return const Center(child: CircularProgressIndicator());
          
          final roomData = roomSnap.data!.data() as Map<String, dynamic>? ?? {};
          final String? activeOfferId = roomData['active_offer_id'];

          return Column(
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
                    return ListView.builder(
                      reverse: true, 
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index].data() as Map<String, dynamic>;
                        bool isMe = msg['sender_id'] == currentUserId;
                        String type = msg['type'] ?? 'text';

                        // วาดข้อความระบบ (อยู่ตรงกลาง)
                        if (type == 'system_log') {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(msg['content'], style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }

                        // วาดกล่องข้อเสนอ (ดีล)
                        if (type == 'system_offer') {
                          final offerDataFromMsg = msg['offer_data'] ?? {};
                          final targetItem = offerDataFromMsg['target_item'] ?? {};
                          final offeredItem = offerDataFromMsg['offered_item'] ?? {};
                          
                          // จัดตำแหน่ง: ของของฉันอยู่ขวาเสมอ
                          bool isSender = (msg['sender_id'] == currentUserId);
                          var myItemData = isSender ? offeredItem : targetItem;
                          var theirItemData = isSender ? targetItem : offeredItem;

                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('offers').doc(activeOfferId).snapshots(),
                            builder: (context, offerSnap) {
                              String offerStatus = 'cancelled';
                              if (offerSnap.hasData && offerSnap.data!.exists) {
                                offerStatus = (offerSnap.data!.data() as Map<String, dynamic>)['status'] ?? 'pending';
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
                                    const Divider(height: 30),
                                    Text(msg['content'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    
                                    // สร้างปุ่ม Action ตามสถานะและบทบาท
                                    const SizedBox(height: 16),
                                    if (offerStatus == 'pending') ...[
                                      if (isSender) 
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: () => _cancelOffer(activeOfferId!),
                                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                            child: const Text('ยกเลิกข้อเสนอ'),
                                          ),
                                        )
                                      else 
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => _rejectOffer(activeOfferId!),
                                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                                child: const Text('ปฏิเสธ'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => _acceptOffer(activeOfferId!),
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
                                                child: const Text('ยอมรับ', style: TextStyle(color: Colors.white)),
                                              ),
                                            ),
                                          ],
                                        )
                                    ] else ...[
                                      // ถ้าสถานะไม่ใช่ pending ให้โชว์ Text สรุปผล
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: offerStatus == 'accepted' ? Colors.green.shade50 : (offerStatus == 'rejected' ? Colors.orange.shade50 : Colors.red.shade50),
                                          borderRadius: BorderRadius.circular(8)
                                        ),
                                        child: Text(
                                          offerStatus == 'accepted' ? 'ตกลงแลกเปลี่ยนแล้ว' : (offerStatus == 'rejected' ? 'ถูกปฏิเสธ' : 'ยกเลิกแล้ว'),
                                          style: TextStyle(fontWeight: FontWeight.bold, color: offerStatus == 'accepted' ? Colors.green : (offerStatus == 'rejected' ? Colors.orange : Colors.red)),
                                        ),
                                      )
                                    ]
                                  ],
                                ),
                              );
                            },
                          );
                        }

                        // วาดบับเบิลข้อความธรรมดา
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF008080) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(msg['content'], style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              
              // ช่องพิมพ์ข้อความด้านล่าง
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                child: SafeArea(
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
          );
        }
      ),
    );
  }
}