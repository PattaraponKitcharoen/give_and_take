import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> itemData; // รับข้อมูลไอเทมมาจากหน้า Home

  const ItemDetailScreen({super.key, required this.itemData});

  @override
  Widget build(BuildContext context) {
    final Color tealColor = const Color(0xFF008080);
    
    // ดึงข้อมูลจาก Map ออกมาเตรียมแสดงผล
    final String title = itemData['title'] ?? 'ไม่มีชื่อสินค้า';
    final String description = itemData['description'] ?? 'ไม่มีรายละเอียด';
    final String category = itemData['category'] ?? 'ทั่วไป';
    final int coins = itemData['estimated_coins'] ?? 0;
    
    // ดึงข้อมูลจาก MapMetadata
    final Map<String, dynamic> metadata = itemData['metadata'] ?? {};
    final String condition = metadata['condition'] ?? 'ไม่ระบุสภาพ';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('รายละเอียดสิ่งของ', style: TextStyle(color: Colors.black87, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ส่วนรูปภาพ (Placeholder ไว้ก่อน)
            Container(
              height: 350,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(Icons.image, size: 100, color: Colors.black12),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. หมวดหมู่และสภาพสินค้า
                  Row(
                    children: [
                      _buildBadge(category, tealColor.withOpacity(0.1), tealColor),
                      const SizedBox(width: 8),
                      _buildBadge(condition, Colors.orange.withOpacity(0.1), Colors.orange.shade800),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. ชื่อสินค้า
                  Text(
                    title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  // 4. ราคาเหรียญ (Coins)
                  Row(
                    children: [
                      Icon(Icons.monetization_on, color: tealColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '$coins Coins',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tealColor),
                      ),
                      const Spacer(),
                      const Text('ราคาประเมินกลาง', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 40),

                  // 5. รายละเอียดสินค้า
                  const Text('รายละเอียด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
                  ),
                  const SizedBox(height: 100), // เผื่อที่ให้ปุ่มด้านล่าง
                ],
              ),
            ),
          ],
        ),
      ),
      
      // 6. ปุ่มแลกเปลี่ยนด้านล่าง (Action Button)
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: () async {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) return;

            final currentUserId = currentUser.uid;
            final ownerId = itemData['owner_id'] ?? '';

            // ดักเอาไว้ กันไม่ให้ยูสเซอร์เด๋อกดทักแชทไปขอแลกของกับตัวเอง
            if (currentUserId == ownerId) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('นี่คือสิ่งของของคุณเอง')),
              );
              return;
            }

            // สร้าง Document ห้องแชทใหม่ลงฐานข้อมูล (ปรับฟิลด์ให้ตรงกับตาราง Schema ล่าสุดของคุณ)
            final roomRef = await FirebaseFirestore.instance.collection('chat_rooms').add({
              'participants': [currentUserId, ownerId],
              'last_message_text': 'สนใจแลกเปลี่ยนสิ่งของครับ', // ใช้ชื่อคีย์ตามตารางเป๊ะๆ
              'last_sender_id': currentUserId,
              'updated_at': FieldValue.serverTimestamp(),
              'created_at': FieldValue.serverTimestamp(),
            });

            if (context.mounted) {
              // พอสร้างห้องเสร็จ ก็พากระโดดเข้าหน้าห้องแชททันที
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(roomId: roomRef.id),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: tealColor,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('ยื่นข้อเสนอแลกเปลี่ยน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  // Widget ช่วยสร้าง Badge เล็กๆ
  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}