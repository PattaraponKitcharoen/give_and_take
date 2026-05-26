import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF4F6F8); // สีพื้นหลังออฟไวท์

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Give & Take',
          style: TextStyle(
            color: tealColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationBar(),
            _buildHeroBanner(),
            _buildCategoryChips(),
            _buildSectionTitle('Recommended for You'),
            _buildProductGrid(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: tealColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Haad Yai, Hat Yai, Songkhla',
              style: TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Icon(Icons.image, size: 80, color: Colors.black12),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDot(true),
            _buildDot(false),
            _buildDot(false),
            _buildDot(false),
          ],
        )
      ],
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? tealColor : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['Skills', 'Home Goods', 'Books', 'Gadgets'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // ปุ่ม All (Active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border.all(color: tealColor),
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: tealColor),
                  const SizedBox(width: 4),
                  Text('All', style: TextStyle(color: tealColor)),
                ],
              ),
            ),
            // ปุ่มอื่นๆ
            ...categories.map((cat) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(_getCategoryIcon(cat), size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(cat, style: const TextStyle(color: Colors.black87)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Skills': return Icons.school_outlined;
      case 'Home Goods': return Icons.chair_outlined;
      case 'Books': return Icons.menu_book_outlined;
      case 'Gadgets': return Icons.laptop_mac_outlined;
      default: return Icons.category_outlined;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: tealColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // ใช้ StreamBuilder เพื่อให้ข้อมูลอัปเดตแบบ Real-time ทันทีที่มีคนโพสต์ของใหม่
      child: StreamBuilder<QuerySnapshot>(
        // Query: ดึงเฉพาะข้อมูลที่เป็น item และสถานะ active
        stream: FirebaseFirestore.instance
            .collection('listings')
            .where('type', isEqualTo: 'item')
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          // เช็คสถานะตอนกำลังโหลด
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: Color(0xFF008080)),
              ),
            );
          }

          // เช็คกรณีเกิด Error หรือไม่มีข้อมูล
          if (snapshot.hasError) {
            return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('ยังไม่มีสิ่งของให้แลกเปลี่ยนในขณะนี้', style: TextStyle(color: Colors.grey)),
              ),
            );
          }

          // เอาข้อมูลที่ดึงมาได้ เก็บใส่ตัวแปร items
          final items = snapshot.data!.docs;

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              // แกะข้อมูลออกมาใช้งาน
              final data = items[index].data() as Map<String, dynamic>;
              final title = data['title'] ?? 'No Title';
              final coins = data['estimated_coins'] ?? 0;
              return InkWell( // 🟢 เพิ่มตรงนี้เพื่อให้กดได้
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemDetailScreen(itemData: data), // 🟢 ส่งข้อมูลไปหน้า Detail
                    ),
                  );
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
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.image, size: 40, color: Colors.black12), // ตำแหน่งนี้เดี๋ยวเราค่อยมาทำดึงรูปภาพจริงทีหลัง
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title, // ใช้ตัวแปร title ที่ดึงมาจาก Firebase
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text('4.5', style: const TextStyle(fontSize: 12)), // ค่ารีวิวจำลองไปก่อน
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.monetization_on, size: 14, color: tealColor),
                              const SizedBox(width: 4),
                              Text(
                                '$coins Coins', // ใช้ตัวแปร coins ที่ดึงมาจาก Firebase
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
      ),
    );
  }
}