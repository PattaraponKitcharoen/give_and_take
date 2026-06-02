import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_detail_screen.dart';

class ItemSearchDelegate extends SearchDelegate<String> {
  final Color tealColor = const Color(0xFF008080);
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // เปลี่ยนคำใบ้ในช่องค้นหา
  @override
  String get searchFieldLabel => 'ค้นหาสิ่งของ...';

  // ปุ่มด้านขวาของช่องค้นหา (ปุ่ม X สำหรับล้างคำ)
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.grey),
          onPressed: () {
            query = ''; // ล้างข้อความ
          },
        ),
    ];
  }

  // ปุ่มด้านซ้ายของช่องค้นหา (ปุ่ม Back กลับหน้าเดิม)
  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.grey),
      onPressed: () {
        close(context, ''); // ปิดหน้าต่างค้นหา
      },
    );
  }

  // สิ่งที่แสดงเมื่อผู้ใช้กดปุ่ม 'ค้นหา' หรือ 'Enter' บนคีย์บอร์ด
  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  // สิ่งที่แสดงแบบ Real-time ระหว่างที่กำลังพิมพ์
  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('พิมพ์ชื่อสิ่งของที่ต้องการค้นหา', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }
    return _buildSearchResults();
  }

  // ฟังก์ชันหลักที่ใช้ดึงข้อมูลและกรองคำ
  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      // โหลดเฉพาะของที่เป็น active มาทั้งหมด
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('ไม่พบสิ่งของในระบบ'));
        }

        final rawDocs = snapshot.data!.docs;
        final searchQuery = query.toLowerCase().trim();

        // 🟢 ลอจิกการกรองคำค้นหา (ทำในเครื่องมือถือ)
        final filteredDocs = rawDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ownerId = data['owner_id'] ?? '';
          final title = (data['title'] ?? '').toString().toLowerCase();

          if (ownerId == currentUserId) return false; // กฎเดิม: ไม่แสดงของตัวเอง
          if (!title.contains(searchQuery)) return false; // ถ้าชื่อไม่มีคำที่พิมพ์ ให้ซ่อนไป

          return true;
        }).toList();

        // ถ้ากรองแล้วไม่เหลือของเลย
        if (filteredDocs.isEmpty) {
          return Center(
            child: Text('ไม่พบผลลัพธ์สำหรับ "$query"', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          );
        }

        // วาด UI แบบ GridView แบบเดียวกับหน้า Home 
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75, // ปรับสัดส่วนให้เหมือนหน้าแรก
          ),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            data['listing_id'] = filteredDocs[index].id;
            
            final title = data['title'] ?? 'No Title';
            final coins = data['estimated_coins'] ?? 0;
            final thumbnail = data['thumbnail_url'] ?? '';

            return InkWell(
              onTap: () {
                // พอกดที่สินค้า ให้เข้าไปหน้ารายละเอียดได้เลย
                Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(itemData: data)));
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: thumbnail.isNotEmpty 
                          ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(thumbnail, fit: BoxFit.cover))
                          : const Center(child: Icon(Icons.image, size: 40, color: Colors.black12)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.monetization_on, size: 14, color: tealColor),
                              const SizedBox(width: 4),
                              Text(
                                '$coins Coins',
                                style: TextStyle(color: tealColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}