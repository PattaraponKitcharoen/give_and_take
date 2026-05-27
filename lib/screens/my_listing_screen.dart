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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('จัดการสิ่งของ', style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.black87),
          bottom: TabBar(
            labelColor: tealColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: tealColor,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'ของของฉัน'),
              Tab(text: 'ข้อเสนอที่ส่งไป'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyItemsTab(currentUserId, tealColor),
            _buildSentOffersTab(currentUserId, tealColor),
          ],
        ),
      ),
    );
  }

  // 🟢 1. อัปเดตแท็บ "ของของฉัน" ให้มีปุ่มเมนู จัดการแก้ไข/ลบ
  Widget _buildMyItemsTab(String userId, Color tealColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('owner_id', isEqualTo: userId)
          .where('status', isEqualTo: 'active') // ดึงมาเฉพาะที่ยังแอคทีฟอยู่
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
              // 🟢 เปลี่ยนจาก Icon ธรรมดา เป็น PopupMenu
              // 🟢 แก้ไขตรงนี้ใน _buildMyItemsTab
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'edit') {
                    // 🟢 เปลี่ยนมากระโดดไปหน้า Edit แทน
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditListingScreen(
                          itemId: itemId, 
                          itemData: data,
                        ),
                      ),
                    );
                  } else if (value == 'delete') {
                    _showDeleteConfirmDialog(context, itemId, tealColor);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 8), Text('แก้ไข')]),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('ลบสิ่งของ')]),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 🟢 3. ป๊อปอัปยืนยันการลบ
  void _showDeleteConfirmDialog(BuildContext context, String itemId, Color tealColor) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('คุณแน่ใจหรือไม่ที่จะลบสิ่งของชิ้นนี้? ข้อมูลจะไม่สามารถกู้คืนได้'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                // ใช้วิธีลบออกแบบ Hard Delete ไปเลย
                await FirebaseFirestore.instance.collection('listings').doc(itemId).delete();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('ลบสิ่งของ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // แท็บข้อเสนอที่ส่งไป (โค้ดเดิม ไม่เปลี่ยนแปลง)
  Widget _buildSentOffersTab(String userId, Color tealColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('sender_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('🔥 Firebase Index Link: ${snapshot.error}'); 
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                'เกิดข้อผิดพลาด (ก๊อปปี้ลิงก์ไปเปิด หรือกดจากหน้า Console):\n\n${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('คุณยังไม่ได้ยื่นข้อเสนอให้ใครเลย'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            
            String statusText = 'รอดำเนินการ';
            Color statusColor = Colors.orange;
            
            if (data['status'] == 'accepted') {
              statusText = 'สำเร็จ';
              statusColor = Colors.green;
            } else if (data['status'] == 'rejected') {
              statusText = 'ถูกปฏิเสธ';
              statusColor = Colors.red;
            }

            int coinOffset = data['coin_offset'] ?? 0;
            String coinDetail = coinOffset == 0 
                ? 'แลกเปลี่ยนพอดี' 
                : (coinOffset > 0 ? 'เราแถม $coinOffset Coins' : 'เราขอ ${-coinOffset} Coins');

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: tealColor.withOpacity(0.1), 
                child: Icon(Icons.sync_alt, color: tealColor)
              ),
              title: Text('ดีล: ${docs[index].id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(coinDetail),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            );
          },
        );
      },
    );
  }
}