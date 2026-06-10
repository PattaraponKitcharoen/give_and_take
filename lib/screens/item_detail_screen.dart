import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart'; 

class ItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> itemData;

  const ItemDetailScreen({super.key, required this.itemData});

  @override
  Widget build(BuildContext context) {
    // 🟢 แก้รหัสสีให้ตรงกับหน้า Add Item (0xFF008080)
    final Color tealColor = const Color(0xFF008080); 
    final Color lightTeal = const Color(0xFFE0F2F1);
    final Color coinGreen = const Color(0xFF00C853);
    
    final String listingId = itemData['listing_id'] ?? '';
    final String title = itemData['title'] ?? 'ไม่มีชื่อสินค้า';
    final String description = itemData['description'] ?? 'ไม่มีรายละเอียด';
    final String category = itemData['category'] ?? 'ทั่วไป';
    final int coins = itemData['estimated_coins'] ?? 0;
    
    final Map<String, dynamic> metadata = itemData['metadata'] ?? {};
    final String condition = metadata['condition'] ?? 'มือสองสภาพดี';
    final String ownerId = itemData['owner_id'] ?? ''; 
    final String thumbnail = itemData['thumbnail_url'] ?? '';

    // 🟢 แก้ไขการแสดงเวลาให้เป็นภาษาไทย
    String listedText = 'โพสต์เมื่อไม่นานมานี้';
    if (itemData['created_at'] != null) {
      final Timestamp createdAt = itemData['created_at'];
      final int days = DateTime.now().difference(createdAt.toDate()).inDays;
      if (days == 0) {
        listedText = 'โพสต์วันนี้';
      } else {
        listedText = 'โพสต์เมื่อ $days วันที่แล้ว';
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 320, 
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    image: thumbnail.isNotEmpty 
                        ? DecorationImage(image: NetworkImage(thumbnail), fit: BoxFit.cover) 
                        : null,
                  ),
                  child: thumbnail.isEmpty ? const Icon(Icons.image, size: 80, color: Colors.black12) : null,
                ),
                Container(
                  height: 320,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.4)],
                      stops: const [0.0, 0.5, 1.0],
                    )
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFloatingIcon(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16, right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                    child: const Text('1 / 1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                Positioned(
                  bottom: 24, left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDot(true), _buildDot(false), _buildDot(false),
                    ],
                  ),
                )
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge(Icons.laptop_mac, category, lightTeal, tealColor),
                      _buildBadge(Icons.star, condition, lightTeal, tealColor),
                    ],
                  ),
                  const SizedBox(height: 12), 

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2)),
                            const SizedBox(height: 6),
                            Text(listedText, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: coinGreen, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                const Icon(Icons.layers, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text('$coins', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Coin Value', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16), 

                  _buildOwnerProfileCard(context, ownerId, tealColor),

                  const SizedBox(height: 16), 

                  Text('About This Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tealColor)),
                  const SizedBox(height: 8), 
                  Text(
                    description,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.6),
                  ),
                  const SizedBox(height: 80), 
                ],
              ),
            ),
          ],
        ),
      ),
      
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('listings').doc(listingId).snapshots(),
        builder: (context, snapshot) {
          bool isActive = false;
          bool isLiked = false; 
          
          final currentUser = FirebaseAuth.instance.currentUser;
          final currentUserId = currentUser?.uid ?? '';

          if (snapshot.hasData && snapshot.data!.exists) {
            final latestData = snapshot.data!.data() as Map<String, dynamic>;
            if (latestData['status'] == 'active') {
              isActive = true;
            }
            
            final List likedBy = latestData['liked_by'] ?? [];
            isLiked = likedBy.contains(currentUserId);
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              top: false, 
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), 
                child: Row(
                  children: [
                    Container(
                      height: 52, width: 52, 
                      decoration: BoxDecoration(
                        color: isLiked ? Colors.red.shade50 : lightTeal,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isLiked ? Colors.red.shade200 : tealColor.withOpacity(0.3)),
                      ),
                      child: IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : tealColor, 
                        ),
                        onPressed: () async {
                          if (currentUserId.isEmpty) return;
                          
                          final docRef = FirebaseFirestore.instance.collection('listings').doc(listingId);
                          
                          if (isLiked) {
                            await docRef.update({
                              'liked_by': FieldValue.arrayRemove([currentUserId])
                            });
                          } else {
                            await docRef.update({
                              'liked_by': FieldValue.arrayUnion([currentUserId])
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      // 🟢 เพิ่ม Container ห่อปุ่มไว้เพื่อทำเอฟเฟกต์เงาแบบเดียวกับหน้า Add Item
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isActive ? [
                            BoxShadow(
                              color: tealColor.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ] : [],
                        ),
                        child: ElevatedButton(
                          onPressed: isActive ? () {
                            if (currentUserId.isEmpty) return;

                            if (currentUserId == ownerId) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Text('แจ้งเตือน', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
                                  content: const Text('คุณไม่สามารถยื่นข้อเสนอให้กับสิ่งของของตัวเองได้ครับ'),
                                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('เข้าใจแล้ว', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold)))],
                                ),
                              );
                              return;
                            }
                            _showOfferBottomSheet(context, tealColor, currentUserId, ownerId);
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tealColor,
                            disabledBackgroundColor: Colors.grey.shade400,
                            minimumSize: const Size(double.infinity, 52), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0, // ปิด elevation เดิมทิ้ง เพราะเราใช้ BoxShadow จาก Container แทนแล้ว
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.swap_horiz, color: isActive ? Colors.white : Colors.white70),
                              const SizedBox(width: 8),
                              Text(isActive ? 'Make an Offer' : 'Item Unavailable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.white70)),
                            ],
                          )
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 16 : 6, height: 6,
      decoration: BoxDecoration(color: isActive ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: textColor.withOpacity(0.3))),
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildOwnerProfileCard(BuildContext context, String ownerId, Color tealColor) {
    if (ownerId.isEmpty) return const SizedBox(); 

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
      builder: (context, snapshot) {
        String ownerName = 'กำลังโหลด...';
        double ratingScore = 0.0;
        String profileImg = '';
        String memberSinceYear = '2024'; 

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          ownerName = userData['name'] ?? 'ผู้ใช้งาน';
          if (ownerName.trim().isEmpty) ownerName = 'ผู้ใช้งาน';
          ratingScore = (userData['rating_scores'] ?? 0.0).toDouble();
          profileImg = userData['profile_img_url'] ?? '';
          
          if (userData['created_at'] != null) {
            final Timestamp createdAt = userData['created_at'];
            memberSinceYear = createdAt.toDate().year.toString();
          }
        }

        return Container(
          padding: const EdgeInsets.all(12), 
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46, height: 46, 
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12),
                      image: profileImg.isNotEmpty ? DecorationImage(image: NetworkImage(profileImg), fit: BoxFit.cover) : null,
                    ),
                    child: profileImg.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ownerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2), 
                        
                        FutureBuilder<int>(
                          future: () async {
                            try {
                              final sentSnap = await FirebaseFirestore.instance.collection('offers')
                                  .where('sender_id', isEqualTo: ownerId)
                                  .where('status', isEqualTo: 'completed')
                                  .get();
                              final receivedSnap = await FirebaseFirestore.instance.collection('offers')
                                  .where('target_user_id', isEqualTo: ownerId)
                                  .where('status', isEqualTo: 'completed')
                                  .get();
                              return sentSnap.docs.length + receivedSnap.docs.length;
                            } catch (e) {
                              return 0;
                            }
                          }(),
                          builder: (context, tradeSnap) {
                            int tradeCount = tradeSnap.data ?? 0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$tradeCount successful trades', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, height: 1.2)),
                                Text('Member since $memberSinceYear', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, height: 1.2)),
                              ],
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text(ratingScore > 0 ? ratingScore.toStringAsFixed(1) : 'New', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12), 
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: ownerId))),
                  icon: Icon(Icons.person_outline, size: 16, color: tealColor),
                  label: Text('View Profile', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: tealColor.withOpacity(0.05),
                    side: BorderSide(color: tealColor.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  void _showOfferBottomSheet(BuildContext context, Color tealColor, String currentUserId, String ownerId) {
    String? selectedMyItemId;
    Map<String, dynamic>? selectedMyItemData; 
    int coinOffset = 0;
    String offerType = 'none'; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              // 🟢 ห่อหุ้มด้วย GestureDetector ตรงนี้เพื่อดักจับการแตะพื้นที่ว่างภายในแผงทั้งหมด
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  FocusScope.of(context).unfocus(); // สั่งพับคีย์บอร์ดเมื่อแตะพื้นที่ว่าง
                },
                child: SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.only(top: 80), 
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)
                      ]
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ตัวจับลาก (Drag Handle)
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 24),
                        
                        // ส่วนหัว
                        const Center(
                          child: Column(
                            children: [
                              Text('Make an Offer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF004D40))),
                              SizedBox(height: 4),
                              Text('Propose a fair trade for this item', style: TextStyle(fontSize: 14, color: Colors.black54)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // SECTION: เลือกสิ่งของของคุณ (Your Offer Item)
                        const Text('YOUR OFFER ITEM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        
                        FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance.collection('listings')
                              .where('owner_id', isEqualTo: currentUserId)
                              .where('status', isEqualTo: 'active').get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            var items = snapshot.data!.docs;
                            
                            if (items.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                                child: const Center(child: Text('คุณยังไม่มีสิ่งของให้แลก', style: TextStyle(color: Colors.black54))),
                              );
                            }
                            
                            if (selectedMyItemId == null && items.isNotEmpty) {
                              selectedMyItemId = items.first.id;
                              selectedMyItemData = items.first.data() as Map<String, dynamic>;
                              selectedMyItemData!['listing_id'] = items.first.id;
                            }

                            return GestureDetector(
                              onTap: () {},
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF00C853).withOpacity(0.5), width: 1.5),
                                  boxShadow: [BoxShadow(color: const Color(0xFF00C853).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50, height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                        image: selectedMyItemData?['thumbnail_url'] != null && selectedMyItemData!['thumbnail_url'].isNotEmpty
                                            ? DecorationImage(image: NetworkImage(selectedMyItemData!['thumbnail_url']), fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: selectedMyItemData?['thumbnail_url'] == null || selectedMyItemData!['thumbnail_url'].isEmpty
                                          ? const Icon(Icons.image, color: Colors.grey) : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(selectedMyItemData?['title'] ?? 'ไม่ระบุชื่อ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFF00C853).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.layers, size: 10, color: Color(0xFF00C853)),
                                                    const SizedBox(width: 4),
                                                    Text('~${selectedMyItemData?['estimated_coins'] ?? 0} Coins', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedMyItemId,
                                                  icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                                  style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                                                  isDense: true,
                                                  items: items.map((doc) => DropdownMenuItem(value: doc.id, child: Text((doc.data() as Map)['title']))).toList(),
                                                  onChanged: (val) {
                                                    setModalState(() {
                                                      selectedMyItemId = val;
                                                      var selectedDoc = items.firstWhere((doc) => doc.id == val);
                                                      selectedMyItemData = selectedDoc.data() as Map<String, dynamic>;
                                                      selectedMyItemData!['listing_id'] = selectedDoc.id;
                                                    });
                                                  },
                                                ),
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
                        ),
                        const SizedBox(height: 24),

                        // SECTION: BALANCE THE TRADE
                        const Text('BALANCE THE TRADE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        
                        // ปุ่มสลับรูปแบบการแลกเปลี่ยน 3 แบบ
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => offerType = 'give'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: offerType == 'give' ? const Color(0xFF00C853) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.arrow_upward, size: 18, color: offerType == 'give' ? Colors.white : Colors.grey.shade500),
                                      const SizedBox(height: 4),
                                      Text('แถมเหรียญ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: offerType == 'give' ? Colors.white : Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() { offerType = 'none'; coinOffset = 0; }), 
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: offerType == 'none' ? const Color(0xFF008080) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.sync_alt, size: 18, color: offerType == 'none' ? Colors.white : Colors.grey.shade500),
                                      const SizedBox(height: 4),
                                      Text('แลกของเท่านั้น', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: offerType == 'none' ? Colors.white : Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => offerType = 'ask'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: offerType == 'ask' ? const Color(0xFFFF5252) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.arrow_downward, size: 18, color: offerType == 'ask' ? Colors.white : Colors.grey.shade500),
                                      const SizedBox(height: 4),
                                      Text('ขอเหรียญเพิ่ม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: offerType == 'ask' ? Colors.white : Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ซ่อนช่องกรอกถ้าเลือกแบบไม่ใช้เหรียญ
                        if (offerType != 'none')
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200)
                            ),
                            child: TextField(
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 20, right: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 4)]),
                                    child: const Icon(Icons.layers, size: 16, color: Colors.white),
                                  ),
                                ),
                                suffixIcon: const Padding(
                                  padding: EdgeInsets.only(right: 20, top: 12),
                                  child: Text('coins', style: TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                )
                              ),
                              onChanged: (val) => coinOffset = int.tryParse(val) ?? 0,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('ใช้สิ่งของแลกเปลี่ยนกันโดยตรง ไม่มีการใช้เหรียญ', style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
                            ),
                          ),
                          
                        const SizedBox(height: 32),

                        // ปุ่ม Confirm
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (selectedMyItemId == null) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกสิ่งของของคุณก่อนยื่นข้อเสนอครับ')));
                               return;
                            }

                            String coinText = "";
                            int finalCoinOffset = 0;
                            
                            if (offerType != 'none' && coinOffset > 0) {
                              finalCoinOffset = offerType == 'ask' ? -coinOffset : coinOffset;
                              coinText = " และยินดี${offerType == 'ask' ? 'ขอรับเหรียญเพิ่ม' : 'แถมเหรียญให้'} $coinOffset Coins";
                            }
                            
                            final offerRef = await FirebaseFirestore.instance.collection('offers').add({
                              'sender_id': currentUserId,
                              'target_user_id': ownerId,
                              'target_listing_id': itemData['listing_id'] ?? '', 
                              'offered_listing_id': selectedMyItemId,
                              'coin_offset': finalCoinOffset, 
                              'status': 'pending',
                              'created_at': FieldValue.serverTimestamp(),
                            });

                            final roomRef = await FirebaseFirestore.instance.collection('chat_rooms').add({
                              'participants': [currentUserId, ownerId],
                              'active_offer_id': offerRef.id,
                              'last_message_text': 'ยื่นข้อเสนอแลกเปลี่ยนสิ่งของใหม่',
                              'last_message_type': 'system_offer', 
                              'last_sender_id': currentUserId,
                              'read_by': [currentUserId], 
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
                          icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                          label: const Text('Confirm & Start Chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008080), 
                            minimumSize: const Size(double.infinity, 56), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: const Color(0xFF008080).withOpacity(0.5)
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}