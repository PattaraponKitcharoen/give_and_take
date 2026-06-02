import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart'; // อย่าลืมสร้างและนำเข้าไฟล์นี้

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
    final String ownerId = itemData['owner_id'] ?? ''; // ไอดีเจ้าของไอเทม

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
                  const SizedBox(height: 24),

                  // 🟢 5. การ์ดโปรไฟล์เจ้าของสินค้า (เพิ่มเข้ามาใหม่)
                  _buildOwnerProfileCard(context, ownerId),

                  const Divider(height: 40),

                  // 6. รายละเอียดสินค้า
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
      
      // 7. ปุ่มแลกเปลี่ยนด้านล่าง (Action Button)
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: () {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) return;

            final currentUserId = currentUser.uid;

            // ดักเอาไว้ กันไม่ให้ยูสเซอร์เด๋อกดทักแชทไปขอแลกของกับตัวเอง
            if (currentUserId == ownerId) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text(
                    'แจ้งเตือน', 
                    style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)
                  ),
                  content: const Text('คุณไม่สามารถยื่นข้อเสนอให้กับสิ่งของของตัวเองได้ครับ'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'เข้าใจแล้ว', 
                        style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)
                      ),
                    ),
                  ],
                ),
              );
              return;
            }

            _showOfferBottomSheet(context, tealColor, currentUserId, ownerId);
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

  // 🟢 Widget ช่วยสร้างการ์ดโปรไฟล์เจ้าของ
  Widget _buildOwnerProfileCard(BuildContext context, String ownerId) {
    if (ownerId.isEmpty) return const SizedBox(); // ถ้าไม่มีไอดีให้ซ่อนไปเลย

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
      builder: (context, snapshot) {
        String ownerName = 'กำลังโหลด...';
        double ratingScore = 0.0;
        int reviewCount = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          ownerName = userData['name'] ?? 'ผู้ใช้งาน';
          if (ownerName.trim().isEmpty) ownerName = 'ผู้ใช้งาน';
          ratingScore = (userData['rating_scores'] ?? 0.0).toDouble();
          reviewCount = userData['rating_count'] ?? 0;
        }

        return InkWell(
          onTap: () {
            // เมื่อกดที่การ์ด ให้เด้งไปหน้า UserProfileScreen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserProfileScreen(userId: ownerId)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(Icons.person, color: Colors.grey, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('เจ้าของไอเทม', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text(ownerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            ratingScore > 0 ? ratingScore.toStringAsFixed(1) : 'New',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          if (reviewCount > 0)
                            Text(
                              ' ($reviewCount)',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        );
      }
    );
  }

  // ฟังก์ชันสำหรับแสดงป๊อปอัปยื่นข้อเสนอ
  void _showOfferBottomSheet(BuildContext context, Color tealColor, String currentUserId, String ownerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        
        String? selectedMyItemId;
        Map<String, dynamic>? selectedMyItemData; 
        int coinOffset = 0;
        bool requestCoins = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  const Text('จัดแจงข้อเสนอแลกเปลี่ยน', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  const Text('เลือกสิ่งของของคุณที่จะนำไปแลก', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('listings')
                        .where('owner_id', isEqualTo: currentUserId)
                        .where('status', isEqualTo: 'active').get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      var items = snapshot.data!.docs;
                      if (items.isEmpty) return const Text('คุณยังไม่มีสิ่งของในระบบ');
                      
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        hint: const Text('เลือกสิ่งของของคุณ'),
                        items: items.map((doc) => DropdownMenuItem(value: doc.id, child: Text((doc.data() as Map)['title']))).toList(),
                        onChanged: (val) {
                          setModalState(() {
                            selectedMyItemId = val;
                            var selectedDoc = items.firstWhere((doc) => doc.id == val);
                            selectedMyItemData = selectedDoc.data() as Map<String, dynamic>;
                            selectedMyItemData!['listing_id'] = selectedDoc.id;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  const Text('ส่วนต่างเหรียญ (Coins)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(hintText: 'จำนวนเหรียญ', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                          onChanged: (val) => coinOffset = int.tryParse(val) ?? 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ToggleButtons(
                        isSelected: [!requestCoins, requestCoins],
                        onPressed: (index) => setModalState(() => requestCoins = index == 1),
                        borderRadius: BorderRadius.circular(12),
                        selectedColor: Colors.white,
                        fillColor: tealColor,
                        children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('แถมให้')), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('ขอเพิ่ม'))],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: () async {
                      if (selectedMyItemId == null) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('กรุณาเลือกสิ่งของของคุณก่อนยื่นข้อเสนอครับ')),
                         );
                         return;
                      }

                      String coinText = "";
                      if (coinOffset > 0) {
                        coinText = " และยินดี${requestCoins ? 'ขอรับเหรียญเพิ่ม' : 'แถมเหรียญให้'} $coinOffset Coins";
                      }
                      
                      final offerRef = await FirebaseFirestore.instance.collection('offers').add({
                        'sender_id': currentUserId,
                        'target_user_id': ownerId,
                        'target_listing_id': itemData['listing_id'] ?? '', 
                        'offered_listing_id': selectedMyItemId,
                        'coin_offset': requestCoins ? -coinOffset : coinOffset,
                        'status': 'pending',
                        'created_at': FieldValue.serverTimestamp(),
                      });

                      final roomRef = await FirebaseFirestore.instance.collection('chat_rooms').add({
                        'participants': [currentUserId, ownerId],
                        'active_offer_id': offerRef.id,
                        'last_message_text': 'ยื่นข้อเสนอแลกเปลี่ยนสิ่งของใหม่',
                        'last_sender_id': currentUserId,
                        'updated_at': FieldValue.serverTimestamp(),
                        'created_at': FieldValue.serverTimestamp(),
                      });

                      await FirebaseFirestore.instance.collection('chat_rooms').doc(roomRef.id).collection('messages').add({
                        'sender_id': currentUserId,
                        'content': 'สวัสดีครับ! ผมขอเสนอแลกสิ่งของ$coinText ครับ',
                        'timestamp': FieldValue.serverTimestamp(),
                        'type': 'system_offer',
                        'offer_data': {
                           'target_item': itemData, 
                           'offered_item': selectedMyItemData, 
                        }
                      });

                      if (context.mounted) {
                        Navigator.pop(context); 
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(roomId: roomRef.id)));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: tealColor, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('ยืนยันและเริ่มสนทนา', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}