import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyListingScreen extends StatelessWidget {
  const MyListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final Color tealColor = const Color(0xFF008080);

    return DefaultTabController(
      length: 2, // 🟢 กำหนดให้มีแค่ 2 แท็บตามที่คุณออกแบบ
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
            // แท็บที่ 1: ดึงรายการของที่เราลงไว้
            _buildMyItemsTab(currentUserId, tealColor),
            
            // แท็บที่ 2: ดึงรายการข้อเสนอที่เรายื่นไป
            _buildSentOffersTab(currentUserId, tealColor),
          ],
        ),
      ),
    );
  }

  // 🟢 ฟังก์ชันวาดแท็บ "ของของฉัน"
  Widget _buildMyItemsTab(String userId, Color tealColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('owner_id', isEqualTo: userId)
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
              trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
              onTap: () {
                // TODO: ในอนาคตค่อยทำปุ่มกดเข้าไปแก้ไขรายละเอียดสินค้า
              },
            );
          },
        );
      },
    );
  }

  // 🟢 ฟังก์ชันวาดแท็บ "ข้อเสนอที่ส่งไป"
  Widget _buildSentOffersTab(String userId, Color tealColor) {
    return StreamBuilder<QuerySnapshot>(
      // เช็คว่ามีข้อเสนอไหนบ้างที่เราเป็นคนกดส่ง (sender_id = เรา)
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('sender_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('🔥 Firebase Index Link: ${snapshot.error}'); // 👈 ปริ้นต์ลง VS Code จะได้กดง่ายๆ
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText( // 👈 เปลี่ยนเป็น SelectableText ให้ลากคลุมก๊อปปี้บนจอได้
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
            
            // แปลงสถานะ (Status) ให้เป็นสีและข้อความที่อ่านง่ายขึ้น
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