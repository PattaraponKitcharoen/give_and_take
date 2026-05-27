import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_listing_screen.dart';

class MyListingScreen extends StatelessWidget {
  const MyListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final Color tealColor = const Color(0xFF008080);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('จัดการสิ่งของของฉัน', style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      // 🟢 ดึงแท็บออกไปเลย ให้เหลือแค่ลิสต์โชว์ของตัวเองเพียวๆ
      body: _buildMyItemsTab(context, currentUserId, tealColor),
    );
  }

  Widget _buildMyItemsTab(BuildContext context, String userId, Color tealColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('owner_id', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการดึงข้อมูล'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('คุณยังไม่มีสิ่งของในระบบ'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String itemId = docs[index].id;
            
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                child: (data['thumbnail_url'] != null && data['thumbnail_url'] != '') 
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(data['thumbnail_url'], fit: BoxFit.cover))
                    : const Icon(Icons.image, color: Colors.grey),
              ),
              title: Text(data['title'] ?? 'ไม่มีชื่อสินค้า', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${data['estimated_coins'] ?? 0} Coins', style: TextStyle(color: tealColor)),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => EditListingScreen(itemId: itemId, itemData: data)));
                  } else if (value == 'delete') {
                    _showDeleteConfirmDialog(context, itemId, tealColor);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 8), Text('แก้ไข')])),
                  const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('ลบสิ่งของ')])),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, String itemId, Color tealColor) {
    showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('คุณแน่ใจหรือไม่ที่จะลบสิ่งของชิ้นนี้?\nข้อเสนอที่เกี่ยวข้องทั้งหมดจะถูกยกเลิกด้วย'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contextDialog), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                Navigator.pop(contextDialog);
                try {
                  final offeredQuery = await FirebaseFirestore.instance.collection('offers').where('offered_listing_id', isEqualTo: itemId).get();
                  final targetQuery = await FirebaseFirestore.instance.collection('offers').where('target_listing_id', isEqualTo: itemId).get();
                  final allOffers = [...offeredQuery.docs, ...targetQuery.docs];

                  for (var offerDoc in allOffers) {
                    String offerId = offerDoc.id;
                    final roomQuery = await FirebaseFirestore.instance.collection('chat_rooms').where('active_offer_id', isEqualTo: offerId).get();
                    
                    for (var roomDoc in roomQuery.docs) {
                      await roomDoc.reference.collection('messages').add({
                        'sender_id': 'system',
                        'content': 'สิ่งของในข้อเสนอนี้ถูกลบออกจากระบบแล้ว',
                        'timestamp': FieldValue.serverTimestamp(),
                        'type': 'system_log',
                      });
                      await roomDoc.reference.update({
                        'last_message_text': 'สิ่งของในข้อเสนอนี้ถูกลบออกจากระบบแล้ว',
                        'updated_at': FieldValue.serverTimestamp(),
                      });
                    }
                    await offerDoc.reference.delete();
                  }
                  await FirebaseFirestore.instance.collection('listings').doc(itemId).delete();
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบสิ่งของและยกเลิกข้อเสนอที่เกี่ยวข้องเรียบร้อย')));
                } catch (e) {
                   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
                }
              },
              child: const Text('ลบสิ่งของ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}