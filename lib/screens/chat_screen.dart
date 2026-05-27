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

  // 🟢 ฟังก์ชัน: ยกเลิกข้อเสนอ (ฝั่งคนส่ง)
  Future<void> _cancelOffer(String offerId) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).delete();
    _sendSystemMessage('คุณได้ยกเลิกข้อเสนอนี้แล้ว');
  }

  // 🟢 ฟังก์ชัน: ปฏิเสธข้อเสนอ (ฝั่งคนรับ)
  Future<void> _rejectOffer(String offerId) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({'status': 'rejected'});
    _sendSystemMessage('ข้อเสนอถูกปฏิเสธแล้ว');
  }

  // 🟢 ฟังก์ชัน: ยอมรับข้อเสนอ (ฝั่งคนรับ)
  Future<void> _acceptOffer(String offerId, String targetItemId, String offeredItemId) async {
    // 1. อัปเดตสถานะดีลเป็น accepted
    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({'status': 'accepted'});
    // 2. เปลี่ยนสถานะของทั้งสองชิ้นให้เป็น exchanged (ป้องกันคนอื่นมากดแลกซ้ำ)
    await FirebaseFirestore.instance.collection('listings').doc(targetItemId).update({'status': 'exchanged'});
    await FirebaseFirestore.instance.collection('listings').doc(offeredItemId).update({'status': 'exchanged'});
    // 3. ยิงข้อความระบบแจ้งข่าวดี
    _sendSystemMessage('ตกลงแลกเปลี่ยนสิ่งของสำเร็จแล้ว!');
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

  // 🟢 Widget ช่วยสร้างรูปสิ่งของ (ย้ายเข้ามาอยู่ในคลาสเพื่อให้เรียกใช้บริบทง่ายขึ้น)
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
        // 🟢 ดึงข้อมูลห้องแชทเพื่อเอา active_offer_id มาใช้
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

                        // --- 1. วาดข้อความระบบ (อยู่ตรงกลาง) ---
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

                        // --- 2. วาดกล่องข้อเสนอ (ดีล) ---
                        if (type == 'system_offer') {
                          final offerDataFromMsg = msg['offer_data'] ?? {};
                          final targetItem = offerDataFromMsg['target_item'] ?? {};
                          final offeredItem = offerDataFromMsg['offered_item'] ?? {};
                          
                          // 🟢 จัดตำแหน่ง: ของของฉันอยู่ขวาเสมอ!
                          bool isSender = (msg['sender_id'] == currentUserId);
                          var myItemData = isSender ? offeredItem : targetItem;
                          var theirItemData = isSender ? targetItem : offeredItem;

                          return StreamBuilder<DocumentSnapshot>(
                            // 🟢 ดึงสถานะ Offer ล่าสุดแบบ Real-time
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
                                        _buildItemThumbnail(context, theirItemData), // 👈 ของเขาอยู่ซ้าย
                                        const Icon(Icons.sync_alt, color: Color(0xFF008080), size: 32),
                                        _buildItemThumbnail(context, myItemData),    // 👉 ของเราอยู่ขวา!
                                      ],
                                    ),
                                    const Divider(height: 30),
                                    Text(msg['content'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    
                                    // 🟢 สร้างปุ่ม Action ตามสถานะและบทบาท
                                    const SizedBox(height: 16),
                                    if (offerStatus == 'pending') ...[
                                      if (isSender) 
                                        // เราเป็นคนส่ง -> มีสิทธิ์กดยกเลิก
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: () => _cancelOffer(activeOfferId!),
                                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                            child: const Text('ยกเลิกข้อเสนอ'),
                                          ),
                                        )
                                      else 
                                        // เราเป็นคนรับ -> มีสิทธิ์กดยอมรับ หรือ ปฏิเสธ
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
                                                onPressed: () => _acceptOffer(activeOfferId!, targetItem['listing_id'], offeredItem['listing_id']),
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

                        // --- 3. วาดบับเบิลข้อความธรรมดา ---
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
              
              // --- ช่องพิมพ์ข้อความด้านล่าง ---
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