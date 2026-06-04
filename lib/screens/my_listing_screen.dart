import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_listing_screen.dart';

class MyListingScreen extends StatefulWidget {
  const MyListingScreen({super.key});

  @override
  State<MyListingScreen> createState() => _MyListingScreenState();
}

class _MyListingScreenState extends State<MyListingScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF4F6F8);
  
  // ตัวแปรเก็บสถานะแท็บที่เลือก
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('My Listings', style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: false, // จัดซ้ายตามภาพ
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.black87),
            onPressed: () {}, // สำหรับตั้งค่า Filter เพิ่มเติมในอนาคต
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🟢 เอา .where('status', isEqualTo: 'active') ออก เพื่อดึงของทั้งหมดมาโชว์
        stream: FirebaseFirestore.instance
            .collection('listings')
            .where('owner_id', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการดึงข้อมูล'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data?.docs ?? [];
          
          // 🟢 1. กรองเอาเฉพาะ Active และ In Negotiation มาใช้ (ทิ้ง Draft หรือของที่จบแล้วไปเลย)
          final validDocs = docs.where((doc) {
            final status = (doc.data() as Map<String, dynamic>)['status'] ?? '';
            return status == 'active' || status == 'in_negotiation';
          }).toList();
          
          // 🟢 2. คำนวณสรุปยอดจาก validDocs แทน
          int total = validDocs.length;
          int activeCount = validDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'active').length;
          int inDealCount = validDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'in_negotiation').length;

          // 🟢 3. กรองข้อมูลตามแท็บที่เลือก (ลบเงื่อนไข Draft ออก)
          var filteredDocs = validDocs.where((doc) {
            final status = (doc.data() as Map<String, dynamic>)['status'] ?? '';
            if (_selectedFilter == 'Active' && status != 'active') return false;
            if (_selectedFilter == 'In Negotiation' && status != 'in_negotiation') return false;
            return true;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(total, activeCount, inDealCount),
              _buildFilterTabs(),
              Expanded(
                child: filteredDocs.isEmpty
                    ? const Center(child: Text('ไม่พบสิ่งของในหมวดหมู่นี้', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data() as Map<String, dynamic>;
                          final String itemId = filteredDocs[index].id;
                          return _buildItemCard(context, itemId, data);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🟢 1. แถบสรุปยอดด้านบน (Summary Pills)
  Widget _buildSummaryRow(int total, int active, int inDeal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildSummaryChip('$total Total', tealColor.withOpacity(0.1), tealColor),
          const SizedBox(width: 8),
          _buildSummaryChip('$active Active', Colors.green.shade50, Colors.green.shade700, icon: Icons.check_circle),
          const SizedBox(width: 8),
          _buildSummaryChip('$inDeal In Deal', Colors.blueGrey.shade50, Colors.blueGrey.shade700, icon: Icons.handshake),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, Color bgColor, Color textColor, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: textColor), const SizedBox(width: 4)],
          if (icon == null) ...[Icon(Icons.layers, size: 14, color: textColor), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  // 🟢 2. แถบแท็บฟิลเตอร์ (Filter Tabs)
  Widget _buildFilterTabs() {
    // 🟢 เอา 'Draft' ออกจากลิสต์
    final filters = ['All', 'Active', 'In Negotiation']; 
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((filter) {
          bool isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? tealColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? tealColor : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    // 🟢 เอาเงื่อนไขไอคอน Draft ออก
                    filter == 'All' ? Icons.grid_view_rounded : 
                    filter == 'Active' ? Icons.check_circle : 
                    Icons.handshake,
                    size: 14, 
                    color: isSelected ? Colors.white : Colors.grey.shade600
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter, 
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700, 
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13
                    )
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 🟢 3. การ์ดแสดงสินค้า (Item Card)
  Widget _buildItemCard(BuildContext context, String itemId, Map<String, dynamic> data) {
    final String title = data['title'] ?? 'ไม่มีชื่อสินค้า';
    final int coins = data['estimated_coins'] ?? 0;
    final String status = data['status'] ?? 'draft';
    final String thumbnail = data['thumbnail_url'] ?? '';

    // ตั้งค่าสีและข้อความของ Status Badge
    Color statusBgColor = Colors.grey.shade100;
    Color statusTextColor = Colors.grey.shade700;
    String statusText = 'Draft';
    IconData statusIcon = Icons.insert_drive_file;

    if (status == 'active') {
      statusBgColor = Colors.green.shade50;
      statusTextColor = Colors.green.shade700;
      statusText = 'Active';
      statusIcon = Icons.check_circle;
    } else if (status == 'in_negotiation') {
      statusBgColor = Colors.blueGrey.shade50;
      statusTextColor = Colors.blueGrey.shade700;
      statusText = 'In Negotiation';
      statusIcon = Icons.handshake;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // รูปภาพ
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100, 
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)
            ),
            child: thumbnail.isNotEmpty 
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(thumbnail, fit: BoxFit.cover))
                : const Center(child: Icon(Icons.image, color: Colors.grey, size: 30)),
          ),
          const SizedBox(width: 16),
          // รายละเอียด
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                // ป้ายสถานะ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: statusTextColor.withOpacity(0.3))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusTextColor),
                      const SizedBox(width: 4),
                      Text(statusText, style: TextStyle(color: statusTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // ป้ายราคาเหรียญ
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: tealColor, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text('$coins', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('TradeCoins', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          // ปุ่มจัดการ (Edit / Delete)
          Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => EditListingScreen(itemId: itemId, itemData: data)));
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.edit_outlined, color: Colors.blue.shade700, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showDeleteConfirmDialog(context, itemId, tealColor),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ลอจิกการลบแบบเดิมของคุณ (โค้ดไม่เปลี่ยน แค่จัดระเบียบให้เข้าที่)
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
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('ลบสิ่งของและยกเลิกข้อเสนอที่เกี่ยวข้องเรียบร้อย'),
                        behavior: SnackBarBehavior.floating, 
                        margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16), 
                        backgroundColor: tealColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                } catch (e) {
                   if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เกิดข้อผิดพลาด: $e'),
                        behavior: SnackBarBehavior.floating, 
                        margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
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