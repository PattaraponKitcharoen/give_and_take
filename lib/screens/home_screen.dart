import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_detail_screen.dart';
import 'item_search_delegate.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF4F6F8); 

  String _selectedCategory = 'All';
  String _sortBy = 'newest'; 
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                onTap: () { setState(() => _sortBy = 'newest'); Navigator.pop(context); },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('ราคาประเมิน: น้อยไปมาก'),
                trailing: _sortBy == 'coins_asc' ? Icon(Icons.check, color: tealColor) : null,
                onTap: () { setState(() => _sortBy = 'coins_asc'); Navigator.pop(context); },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('ราคาประเมิน: มากไปน้อย'),
                trailing: _sortBy == 'coins_desc' ? Icon(Icons.check, color: tealColor) : null,
                onTap: () { setState(() => _sortBy = 'coins_desc'); Navigator.pop(context); },
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
        backgroundColor: bgColor, // ปรับสีให้กลืนกับพื้นหลัง
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.autorenew_rounded, color: tealColor, size: 28), // ไอคอนแทนโลโก้ด้านหน้า
            const SizedBox(width: 8),
            Text(
              'Give & Take',
              style: TextStyle(color: tealColor, fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          // 1. ปุ่มกระดิ่ง
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chat_rooms')
                .where('participants', arrayContains: currentUserId ?? '')
                .snapshots(),
            builder: (context, snapshot) {
              bool hasUnreadNoti = false;
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final room = doc.data() as Map<String, dynamic>;
                  final List readBy = room['read_by'] ?? [];
                  final String msgType = room['last_message_type'] ?? 'text';
                  if (msgType != 'text' && !readBy.contains(currentUserId)) {
                    hasUnreadNoti = true;
                    break;
                  }
                }
              }

              return Container(
                margin: const EdgeInsets.only(right: 12),
                width: 40, // 🟢 บังคับความกว้างให้เท่ากับรูปโปรไฟล์ (radius 18 * 2 = 36)
                height: 40, // 🟢 บังคับความสูง
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none, // ยอมให้จุดแดงล้นขอบได้นิดหน่อย
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero, // 🟢 ล้างระยะขอบอัตโนมัติ
                      constraints: const BoxConstraints(), // 🟢 ล้างข้อจำกัดขนาดปุ่ม
                      icon: const Icon(Icons.notifications_none, color: Colors.black87, size: 22),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen()));
                      },
                    ),
                    if (hasUnreadNoti)
                      Positioned(
                        right: 0, // 🟢 ปรับตำแหน่งจุดแดงใหม่ให้เข้ากับขนาดวงกลมที่เล็กลง
                        top: 0,
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          
          // 2. รูปโปรไฟล์ User
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
            builder: (context, snapshot) {
              String profileImg = '';
              if (snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                profileImg = userData?['profile_img_url'] ?? '';
              }

              return GestureDetector(
                onTap: () {
                  // 🟢 ใส่คำสั่งนำทางไปหน้า ProfileScreen
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const ProfileScreen())
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 40, // 🟢 บังคับความกว้างให้เท่ากับรูปโปรไฟล์ (radius 18 * 2 = 36)
                  height: 40, // 🟢 บังคับความสูง
                  child: CircleAvatar(
                    radius: 18, 
                    backgroundColor: Colors.grey.shade300, 
                    backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                    child: profileImg.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            _buildLocationBar(),
            _buildHeroBanner(),
            _buildSectionHeader('Categories', 'See all'),
            _buildCategoryChips(),
            _buildSectionHeader('Near You', 'อัปเดตใหม่วันนี้', isTrailingGreen: true),
            _buildProductGrid(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // 🟢 1. สร้าง Search Bar แบบภาพ Reference
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                showSearch(context: context, delegate: ItemSearchDelegate());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24), // ขอบมนกลม
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                    const SizedBox(width: 8),
                    Text('ค้นหาสิ่งของ...', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ปุ่มจัดเรียง (Sort)
          GestureDetector(
            onTap: _showSortOptions,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.tune, color: Colors.black87, size: 20),
            ),
          )
        ],
      ),
    );
  }

  // 🟢 2. โซนบอกสถานที่ (Location)
  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: tealColor, size: 18),
              const SizedBox(width: 4),
              const Text('หาดใหญ่, สงขลา', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
              const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 18),
            ],
          ),
          Text('ใกล้ฉัน', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  // 🟢 3. แบนเนอร์ด้านบน
  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tealColor, Color(0xFF20B2AA)], // ไล่สีตามภาพ
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text('Verified Traders Only', style: TextStyle(color: Colors.white, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Trade what you have.\nGet what you need.',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
          ),
        ],
      ),
    );
  }

  // ตัวช่วยสร้างหัวข้อ Section
  Widget _buildSectionHeader(String title, String trailing, {bool isTrailingGreen = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          Row(
            children: [
              if (isTrailingGreen) Icon(Icons.add_circle, color: tealColor, size: 14),
              if (isTrailingGreen) const SizedBox(width: 4),
              Text(trailing, style: TextStyle(color: isTrailingGreen ? tealColor : Colors.grey.shade600, fontSize: 13, fontWeight: isTrailingGreen ? FontWeight.bold : FontWeight.normal)),
            ],
          )
        ],
      ),
    );
  }

  // 🟢 4. หมวดหมู่ (Categories) ปรับทรงตามภาพ
  Widget _buildCategoryChips() {
    final categories = ['All', 'Wishlists', 'Electronics', 'Furniture', 'Books', 'Fashion'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((cat) {
          bool isActive = _selectedCategory == cat;
          return GestureDetector(
            onTap: () { setState(() { _selectedCategory = cat; }); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isActive ? tealColor : Colors.white,
                border: Border.all(color: isActive ? tealColor : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    cat == 'All' ? Icons.grid_view_rounded : _getCategoryIcon(cat), 
                    size: 16, 
                    color: isActive ? Colors.white : tealColor
                  ),
                  const SizedBox(width: 8),
                  Text(cat, style: TextStyle(color: isActive ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Wishlists': return Icons.favorite;
      case 'Electronics': return Icons.laptop_mac_outlined;
      case 'Furniture': return Icons.chair_outlined;
      case 'Books': return Icons.menu_book_outlined;
      case 'Fashion': return Icons.checkroom_outlined;
      default: return Icons.category_outlined;
    }
  }

  // 🟢 5. จัด Layout การ์ดสินค้าใหม่ทั้งหมด
  Widget _buildProductGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('listings').where('type', isEqualTo: 'item').where('status', isEqualTo: 'active').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
          if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('ยังไม่มีสิ่งของให้แลกเปลี่ยนในขณะนี้', style: TextStyle(color: Colors.grey))));

          final rawDocs = snapshot.data!.docs;
          var filteredDocs = rawDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ownerId = data['owner_id'] ?? '';
            final category = data['category'] ?? '';
            final List likedBy = data['liked_by'] ?? []; // 🟢 ดึงข้อมูลคนกดหัวใจ

            // กฎข้อ 1: ห้ามเห็นของตัวเองเด็ดขาด
            if (ownerId == currentUserId) return false; 

            // กฎข้อ 2: ถ้าเลือกแท็บ Wishlists ให้เช็กว่ามี UID เราใน liked_by ไหม
            if (_selectedCategory == 'Wishlists') {
              if (!likedBy.contains(currentUserId)) return false;
            } 
            // กฎข้อ 3: ถ้าไม่ใช่ All และไม่ใช่ Wishlists ให้กรองตามหมวดหมู่ปกติ
            else if (_selectedCategory != 'All' && category != _selectedCategory) {
              return false; 
            }

            return true;
          }).toList();

          filteredDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            if (_sortBy == 'coins_asc') return (dataA['estimated_coins'] ?? 0).compareTo(dataB['estimated_coins'] ?? 0);
            else if (_sortBy == 'coins_desc') return (dataB['estimated_coins'] ?? 0).compareTo(dataA['estimated_coins'] ?? 0);
            else {
              Timestamp timeA = dataA['created_at'] ?? Timestamp.now();
              Timestamp timeB = dataB['created_at'] ?? Timestamp.now();
              return timeB.compareTo(timeA);
            }
          });

          if (filteredDocs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text('ไม่พบสิ่งของในหมวดหมู่นี้', style: TextStyle(color: Colors.grey))));

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.52, // 🟢 ยืดความยาวการ์ดเพื่อรองรับปุ่ม Swap ด้านล่าง
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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🟢 โซนรูปภาพ + ป้าย Coins + ไอคอนหัวใจ (ใช้ Stack)
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              child: thumbnail.isNotEmpty 
                                ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(thumbnail, fit: BoxFit.cover))
                                : const Center(child: Icon(Icons.image, size: 40, color: Colors.black12)),
                            ),
                            // ป้าย Coins มุมซ้ายบน
                            Positioned(
                              top: 8, left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: tealColor, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.monetization_on, color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    Text('$coins', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            // ไอคอนหัวใจมุมขวาบน
                            // 🟢 ไอคอนหัวใจมุมขวาบน (เพิ่มระบบกด Like)
                            Positioned(
                              top: 8, right: 8,
                              child: GestureDetector(
                                onTap: () async {
                                  // เช็กก่อนว่ามี UID เราในระบบหรือยัง
                                  final List currentLikedBy = data['liked_by'] ?? [];
                                  final bool isAlreadyLiked = currentLikedBy.contains(currentUserId);
                                  
                                  final docRef = FirebaseFirestore.instance.collection('listings').doc(data['listing_id']);
                                  
                                  if (isAlreadyLiked) {
                                    // ถ้าเคยไลค์แล้ว ให้เอาออก
                                    await docRef.update({
                                      'liked_by': FieldValue.arrayRemove([currentUserId])
                                    });
                                  } else {
                                    // ถ้ายังไม่ไลค์ ให้เพิ่มเข้าไป
                                    await docRef.update({
                                      'liked_by': FieldValue.arrayUnion([currentUserId])
                                    });
                                  }
                                },
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    // เช็กเพื่อเปลี่ยนสีและรูปแบบไอคอน
                                    (data['liked_by'] ?? []).contains(currentUserId) 
                                        ? Icons.favorite 
                                        : Icons.favorite_border, 
                                    size: 16, 
                                    color: (data['liked_by'] ?? []).contains(currentUserId) 
                                        ? Colors.red 
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 🟢 โซนรายละเอียดด้านล่าง
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            
                            // ข้อมูลเจ้าของ + ดาว
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(data['owner_id']).get(),
                              builder: (context, userSnap) {
                                String ownerName = 'ผู้ใช้งาน';
                                double ratingScore = 0.0; 
                                String profileImg = '';

                                if (userSnap.hasData && userSnap.data!.exists) {
                                  final userData = userSnap.data!.data() as Map<String, dynamic>;
                                  ownerName = userData['name'] ?? 'ผู้ใช้งาน';
                                  if (ownerName.trim().isEmpty) ownerName = 'ผู้ใช้งาน';
                                  ratingScore = (userData['rating_scores'] ?? 0.0).toDouble();
                                  profileImg = userData['profile_img_url'] ?? '';
                                }

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 8, 
                                            backgroundColor: Colors.grey.shade300,
                                            backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                                            child: profileImg.isEmpty ? const Icon(Icons.person, size: 10, color: Colors.white) : null,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(ownerName, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, size: 12, color: Colors.amber),
                                        const SizedBox(width: 2),
                                        Text(ratingScore > 0 ? ratingScore.toStringAsFixed(1) : 'New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                                      ],
                                    ),
                                  ],
                                );
                              }
                            ),
                            const SizedBox(height: 12),
                            // 🟢 ปุ่ม Swap แลกเปลี่ยนด้านล่างสุด
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(color: tealColor, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.swap_horiz, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text('Swap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            )
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