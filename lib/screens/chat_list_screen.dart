import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  // 🟢 ฟังก์ชันตัวช่วย: ดึงชื่อสิ่งของมาทำเป็นชื่อห้องแชท
  Future<String> _getChatRoomName(String? offerId) async {
    if (offerId == null || offerId.isEmpty) return 'ห้องแชทส่วนตัว';
    try {
      final offerDoc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) return 'ห้องแชท (ไม่พบข้อเสนอ)';

      final targetItemId = offerDoc.data()?['target_listing_id'];
      if (targetItemId == null) return 'ห้องแชทส่วนตัว';

      final itemDoc = await FirebaseFirestore.instance.collection('listings').doc(targetItemId).get();
      if (!itemDoc.exists) return 'สิ่งของถูกลบไปแล้ว';

      return itemDoc.data()?['title'] ?? 'ไม่มีชื่อสิ่งของ';
    } catch (e) {
      return 'ห้องแชท';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final Color tealColor = const Color(0xFF008080);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8), // ปรับสีพื้นหลังให้ดูสบายตาขึ้น
      appBar: AppBar(
        title: const Text('ข้อความ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('participants', arrayContains: currentUserId)
            .orderBy('updated_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด:\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('ยังไม่มีรายการสนทนา', style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final room = docs[index].data() as Map<String, dynamic>;
              final String roomId = docs[index].id;
              
              // 🟢 แก้ให้ดึงคีย์ข้อความล่าสุดที่ถูกต้อง
              final String lastMessage = room['last_message_text'] ?? 'เริ่มการสนทนาได้เลย';
              
              // 🟢 เช็กสถานะการอ่าน (เช็กว่า UID ของเราอยู่ในอาเรย์ read_by หรือไม่)
              final List readBy = room['read_by'] ?? [];
              final bool isUnread = !readBy.contains(currentUserId) && room['last_message_text'] != null;

              return FutureBuilder<String>(
                future: _getChatRoomName(room['active_offer_id']),
                builder: (context, nameSnapshot) {
                  String roomName = 'กำลังโหลด...';
                  if (nameSnapshot.hasData) {
                    roomName = nameSnapshot.data!;
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: tealColor.withOpacity(0.1), 
                            child: Icon(Icons.inventory_2_outlined, color: tealColor)
                          ),
                        ],
                      ),
                      title: Text(
                        roomName, 
                        // ถ้ายังไม่อ่านให้ตัวหนา
                        style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, fontSize: 16),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          lastMessage, 
                          // ถ้ายังไม่อ่านข้อความให้เป็นสีดำเข้ม
                          style: TextStyle(color: isUnread ? Colors.black87 : Colors.grey, fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isUnread)
                            Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            )
                          else
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => ChatScreen(roomId: roomId),
                        ));
                      },
                    ),
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}