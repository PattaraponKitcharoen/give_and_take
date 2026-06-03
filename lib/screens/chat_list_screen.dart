import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

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
      backgroundColor: const Color(0xFFF4F6F8), 
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
              final String? offerId = room['active_offer_id'];
              
              final String lastMessage = room['last_message_text'] ?? 'เริ่มการสนทนาได้เลย';
              final List readBy = room['read_by'] ?? [];
              final bool isUnread = !readBy.contains(currentUserId) && room['last_message_text'] != null;

              return Dismissible(
                key: Key(roomId),
                direction: DismissDirection.endToStart, 
                background: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (offerId != null && offerId.isNotEmpty) {
                    try {
                      final offerDoc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
                      
                      // 🟢 1. ถ้าข้อเสนอหายไปแล้ว (สินค้าโดนลบ/โดนแลกไปแล้ว) อนุญาตให้ลบแชทได้เลย
                      if (!offerDoc.exists) return true; 

                      final status = offerDoc.data()?['status'] ?? '';
                      
                      // 🟢 2. ถ้าดีลเสร็จสมบูรณ์แล้ว ต้องบังคับเช็กว่า "รีวิวหรือยัง?"
                      if (status == 'completed') {
                        bool hasReviewed = false;
                        
                        // ลองหาจาก transactions ก่อน (ถ้าโครงสร้างคุณเก็บผ่าน transaction_id)
                        final txSnap = await FirebaseFirestore.instance.collection('transactions').where('offer_id', isEqualTo: offerId).limit(1).get();
                        if (txSnap.docs.isNotEmpty) {
                          final txId = txSnap.docs.first.id;
                          final reviewSnap = await FirebaseFirestore.instance.collection('reviews')
                              .where('transaction_id', isEqualTo: txId)
                              .where('reviewer_id', isEqualTo: currentUserId)
                              .get();
                          if (reviewSnap.docs.isNotEmpty) hasReviewed = true;
                        } else {
                          // เผื่อโครงสร้างคุณบันทึก offer_id ลงใน reviews โดยตรง
                          final reviewSnap = await FirebaseFirestore.instance.collection('reviews')
                              .where('offer_id', isEqualTo: offerId)
                              .where('reviewer_id', isEqualTo: currentUserId)
                              .get();
                          if (reviewSnap.docs.isNotEmpty) hasReviewed = true;
                        }

                        // ถ้ายืนยันว่ายังไม่ได้รีวิว
                        if (!hasReviewed) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('คุณยังไม่ได้รีวิวการแลกเปลี่ยนนี้ กรุณารีวิวก่อนลบห้องแชทครับ'),
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                                backgroundColor: Colors.orange.shade800,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                          return false; // ห้ามลบ
                        }
                      } 
                      // 🟢 3. ถ้าดีลยังไม่จบ และไม่ใช่สถานะยกเลิก/ปฏิเสธ
                      else if (status != 'rejected' && status != 'cancelled') {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('การแลกเปลี่ยนยังไม่สมบูรณ์'),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                        return false; // ห้ามลบ
                      }
                    } catch (e) {
                      return false; 
                    }
                  }
                  return true; // อนุญาตให้ลบได้ทุกกรณีที่ผ่านด่านมา
                },
                onDismissed: (direction) async {
                  await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).update({
                    'participants': FieldValue.arrayRemove([currentUserId])
                  });
                },
                child: FutureBuilder<String>(
                  future: _getChatRoomName(offerId),
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
                          style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, fontSize: 16),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            lastMessage, 
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}