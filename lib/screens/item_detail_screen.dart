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
    final Color tealColor = const Color(0xFF004D40); 
    final Color lightTeal = const Color(0xFFE0F2F1);
    final Color coinGreen = const Color(0xFF00C853);
    
    final String listingId = itemData['listing_id'] ?? '';
    final String title = itemData['title'] ?? 'ไม่มีชื่อสินค้า';
    final String description = itemData['description'] ?? 'ไม่มีรายละเอียด';
    final String category = itemData['category'] ?? 'ทั่วไป';
    final int coins = itemData['estimated_coins'] ?? 0;
    
    final Map<String, dynamic> metadata = itemData['metadata'] ?? {};
    final String condition = metadata['condition'] ?? 'Like New';
    final String ownerId = itemData['owner_id'] ?? ''; 
    final String thumbnail = itemData['thumbnail_url'] ?? '';

    String listedText = 'Listed recently';
    if (itemData['created_at'] != null) {
      final Timestamp createdAt = itemData['created_at'];
      final int days = DateTime.now().difference(createdAt.toDate()).inDays;
      if (days == 0) {
        listedText = 'Listed today';
      } else {
        listedText = 'Listed $days days ago';
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🟢 1. ลดความสูงรูปลงเหลือ 320
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
            
            // 🟢 2. บีบช่องว่าง Padding และ SizedBox ต่างๆ ให้แคบลง
            Padding(
              padding: const EdgeInsets.all(16.0), // ลดขอบซ้ายขวาลงนิดนึง
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
                  const SizedBox(height: 12), // บีบขึ้น

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
                  const SizedBox(height: 16), // บีบขึ้น

                  _buildOwnerProfileCard(context, ownerId, tealColor),

                  const SizedBox(height: 16), // บีบขึ้น

                  const Text('About This Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                  const SizedBox(height: 8), // บีบขึ้น
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
      
      // 🟢 3. จัดระเบียบ Bottom Navigation Bar ใหม่ ลดความอ้วน
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
              top: false, // ป้องกัน SafeArea ด้านบน
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // บีบช่องว่างด้านบน-ล่างให้บางลง
                child: Row(
                  children: [
                    Container(
                      height: 52, width: 52, // ลดขนาดปุ่มลงนิดนึง
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
                      child: ElevatedButton(
                        onPressed: isActive ? () {
                          if (currentUserId.isEmpty) return;

                          if (currentUserId == ownerId) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('แจ้งเตือน', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                                content: const Text('คุณไม่สามารถยื่นข้อเสนอให้กับสิ่งของของตัวเองได้ครับ'),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('เข้าใจแล้ว', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)))],
                              ),
                            );
                            return;
                          }
                          _showOfferBottomSheet(context, tealColor, currentUserId, ownerId);
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tealColor,
                          disabledBackgroundColor: Colors.grey.shade400,
                          minimumSize: const Size(double.infinity, 52), // ลดความสูงปุ่มลงนิดนึง
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        mainAxisSize: MainAxisSize.min, // ให้ป้ายขยายตามตัวอักษร
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
          padding: const EdgeInsets.all(12), // 🟢 1. บีบ Padding ของการ์ดให้แคบลง
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
                  // 🟢 2. รูปโปรไฟล์ (เอาไอคอน Verified สีเขียวออกแล้ว)
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
                        // 🟢 3. ชื่อผู้ใช้ (เอาป้าย Verified ออกแล้ว)
                        Text(ownerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2), // 🟢 4. ลดช่องว่างบรรทัดให้ชิดขึ้น
                        
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
                                // 🟢 5. ลดขนาดฟอนต์เป็น 11 และใส่ height ให้บรรทัดชิดกัน
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
              const SizedBox(height: 12), // 🟢 6. ลดช่องว่างระหว่างข้อมูลด้านบนกับปุ่มด้านล่าง
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {}, 
                      icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.black87),
                      label: const Text('Message', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: ownerId))),
                      icon: Icon(Icons.person_outline, size: 16, color: tealColor),
                      label: Text('View Profile', style: TextStyle(color: tealColor, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: tealColor.withOpacity(0.05),
                        side: BorderSide(color: tealColor.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        );
      }
    );
  }

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