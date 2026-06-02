import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // ฟังก์ชันตัวช่วย: ดึงชื่อสิ่งของมาแสดงเป็นหัวข้อแจ้งเตือน
  Future<String> _getChatRoomName(String? offerId) async {
    if (offerId == null || offerId.isEmpty) return 'การแลกเปลี่ยน';
    try {
      final offerDoc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) return 'การแลกเปลี่ยน';

      final targetItemId = offerDoc.data()?['target_listing_id'];
      if (targetItemId == null) return 'การแลกเปลี่ยน';

      final itemDoc = await FirebaseFirestore.instance.collection('listings').doc(targetItemId).get();
      if (!itemDoc.exists) return 'สิ่งของถูกลบไปแล้ว';

      return itemDoc.data()?['title'] ?? 'การแลกเปลี่ยนสิ่งของ';
    } catch (e) {
      return 'การแลกเปลี่ยน';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final Color tealColor = const Color(0xFF008080);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('การแจ้งเตือน', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('participants', arrayContains: currentUserId)
            .orderBy('updated_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล', style: TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final rawDocs = snapshot.data!.docs;
          
          // 🟢 กรองเอาเฉพาะข้อมูลที่เป็นแจ้งเตือน (เรายังไม่ได้อ่าน หรือ คนอื่นเป็นคนส่งล่าสุด)
          final notiDocs = rawDocs.where((doc) {
            final room = doc.data() as Map<String, dynamic>;
            final String lastSender = room['last_sender_id'] ?? '';
            final List readBy = room['read_by'] ?? [];
            final String msgType = room['last_message_type'] ?? 'text'; // ดึงประเภทข้อความ
            
            final bool isUnread = !readBy.contains(currentUserId);
            
            // กฎข้อ 1: ไม่เอาข้อความแชทปกติมาโชว์ในหน้าการแจ้งเตือน!
            if (msgType == 'text') return false; 
            
            // กฎข้อ 2: โชว์แจ้งเตือนก็ต่อเมื่ออีกฝ่ายเป็นคนกดปุ่มทำรายการ (lastSender) หรือเป็นแจ้งเตือนที่เรายังไม่อ่าน
            return lastSender != currentUserId || isUnread; 
          }).toList();

          if (notiDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('ไม่มีการแจ้งเตือนใหม่', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notiDocs.length,
            itemBuilder: (context, index) {
              final room = notiDocs[index].data() as Map<String, dynamic>;
              final String roomId = notiDocs[index].id;
              final String lastMessage = room['last_message_text'] ?? 'มีการอัปเดตใหม่ในดีลนี้';
              
              final List readBy = room['read_by'] ?? [];
              final bool isUnread = !readBy.contains(currentUserId);

              return FutureBuilder<String>(
                future: _getChatRoomName(room['active_offer_id']),
                builder: (context, nameSnapshot) {
                  String itemName = nameSnapshot.data ?? 'กำลังโหลด...';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isUnread ? tealColor.withOpacity(0.05) : Colors.white, // เน้นสีพื้นหลังถ้ายังไม่อ่าน
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isUnread ? tealColor.withOpacity(0.3) : Colors.transparent),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: CircleAvatar(
                        backgroundColor: isUnread ? tealColor : Colors.grey.shade200,
                        child: Icon(
                          isUnread ? Icons.notifications_active : Icons.notifications, 
                          color: isUnread ? Colors.white : Colors.grey.shade600
                        ),
                      ),
                      title: Text(
                        'อัปเดตจาก: $itemName',
                        style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          lastMessage,
                          style: TextStyle(color: isUnread ? Colors.black87 : Colors.grey.shade600),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: isUnread 
                          ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
                          : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () {
                        // พอกดแจ้งเตือน ก็วิ่งเข้าห้องแชทนั้นเลย
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(roomId: roomId)));
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