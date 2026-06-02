import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_detail_screen.dart';

// 🟢 1. เปลี่ยนเป็น StatefulWidget เพื่อรองรับการเปลี่ยนค่า Filter/Sort
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF4F6F8); 

  // 🟢 2. ตัวแปรเก็บสถานะการกรองข้อมูล
  String _selectedCategory = 'All';
  String _sortBy = 'newest'; // newest, coins_asc (น้อยไปมาก), coins_desc (มากไปน้อย)
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // 🟢 3. ฟังก์ชันเปิดหน้าต่างเลือกการจัดเรียง (Sort)
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('จัดเรียงตาม', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('โพสต์ล่าสุด'),
                trailing: _sortBy == 'newest' ? Icon(Icons.check, color: tealColor) : null,
                onTap: () {
                  setState(() => _sortBy = 'newest');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('ราคาประเมิน: น้อยไปมาก'),
                trailing: _sortBy == 'coins_asc' ? Icon(Icons.check, color: tealColor) : null,
                onTap: () {
                  setState(() => _sortBy = 'coins_asc');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('ราคาประเมิน: มากไปน้อย'),
                trailing: _sortBy == 'coins_desc' ? Icon(Icons.check, color: tealColor) : null,
                onTap: () {
                  setState(() => _sortBy = 'coins_desc');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

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
            onPressed: _showSortOptions, // 🟢 ผูกปุ่มเข้ากับหน้าต่าง Sort
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
            _buildSectionTitle('สิ่งของแนะนำ'),
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
    final categories = ['All', 'Skills', 'Home Goods', 'Books', 'Gadgets', 'Fashion'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: categories.map((cat) {
            bool isActive = _selectedCategory == cat;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.white,
                  border: isActive ? Border.all(color: tealColor, width: 1.5) : Border.all(color: Colors.transparent),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isActive ? null : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    Icon(
                      cat == 'All' ? Icons.border_all : _getCategoryIcon(cat), 
                      size: 18, 
                      color: isActive ? tealColor : Colors.grey
                    ),
                    const SizedBox(width: 4),
                    Text(cat, style: TextStyle(color: isActive ? tealColor : Colors.black87, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            );
          }).toList(),
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
      case 'Fashion': return Icons.checkroom_outlined;
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
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('listings')
            .where('type', isEqualTo: 'item')
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Color(0xFF008080))),
            );
          }
          if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('ยังไม่มีสิ่งของให้แลกเปลี่ยนในขณะนี้', style: TextStyle(color: Colors.grey))));
          }

          // 🟢 4. การจัดการลอจิก Filter และ Sort ด้วยภาษา Dart (ไม่ต้องง้อ Index Firebase)
          final rawDocs = snapshot.data!.docs;
          
          var filteredDocs = rawDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ownerId = data['owner_id'] ?? '';
            final category = data['category'] ?? '';

            // กฎข้อ 1: ห้ามเห็นของตัวเองเด็ดขาด
            if (ownerId == currentUserId) return false; 
            
            // กฎข้อ 2: ถ้าไม่ได้เลือกหมวดหมู่ 'All' ให้กรองเอาเฉพาะหมวดที่ตรง
            if (_selectedCategory != 'All' && category != _selectedCategory) return false; 

            return true;
          }).toList();

          // ทำการเรียงลำดับข้อมูล
          filteredDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            
            if (_sortBy == 'coins_asc') {
              return (dataA['estimated_coins'] ?? 0).compareTo(dataB['estimated_coins'] ?? 0);
            } else if (_sortBy == 'coins_desc') {
              return (dataB['estimated_coins'] ?? 0).compareTo(dataA['estimated_coins'] ?? 0);
            } else {
              // กรณี newest (ล่าสุดขึ้นก่อน)
              Timestamp timeA = dataA['created_at'] ?? Timestamp.now();
              Timestamp timeB = dataB['created_at'] ?? Timestamp.now();
              return timeB.compareTo(timeA);
            }
          });

          // เช็คอีกรอบหลังกรองเสร็จ เผื่อว่ากรองแล้วไม่เหลือของเลย
          if (filteredDocs.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text('ไม่พบสิ่งของในหมวดหมู่นี้', style: TextStyle(color: Colors.grey))));
          }

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
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
                            // 🟢 อัปเดต: ดึงชื่อเจ้าของโพสต์มาแสดง
                            // 🟢 โซนที่ 1: ชื่อเจ้าของโพสต์ และ คะแนนรีวิว
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance.collection('users').doc(data['owner_id']).get(),
                                    builder: (context, userSnap) {
                                      String ownerName = 'กำลังโหลด...';
                                      if (userSnap.hasData && userSnap.data!.exists) {
                                        final userData = userSnap.data!.data() as Map<String, dynamic>;
                                        ownerName = userData['name'] ?? 'ผู้ใช้งาน';
                                        
                                        if (ownerName.trim().isEmpty) {
                                          ownerName = 'ผู้ใช้งาน';
                                        }
                                      }
                                      return Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              ownerName,
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star, size: 14, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    const Text('4.5', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // 🟢 โซนที่ 2: ราคาประเมิน (Coins) นำกลับมาใส่ตรงนี้
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
      ),
    );
  }
}