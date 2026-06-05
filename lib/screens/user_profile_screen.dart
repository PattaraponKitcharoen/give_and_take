import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_detail_screen.dart'; 

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF8FAFC);

  String _selectedTab = 'Active Items'; 

  // 🟢 ฟังก์ชันดึงข้อมูลคนรีวิว + ข้อมูลของสิ่งของทั้ง 2 ฝั่ง
  Future<Map<String, dynamic>> _fetchReviewDetails(String reviewerId, String transactionId) async {
    String name = 'ผู้ใช้งาน';
    String img = '';
    Map<String, dynamic>? profileOwnerItemData;
    Map<String, dynamic>? reviewerItemData;

    try {
      final userFuture = FirebaseFirestore.instance.collection('users').doc(reviewerId).get();
      
      Future<void> fetchItems() async {
        if (transactionId.isEmpty) return;
        final txDoc = await FirebaseFirestore.instance.collection('transactions').doc(transactionId).get();
        if (!txDoc.exists) return;
        
        final offerId = txDoc.data()?['offer_id'];
        if (offerId == null || offerId.isEmpty) return;
        
        final offerDoc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
        if (!offerDoc.exists) return;
        
        final offerData = offerDoc.data() as Map<String, dynamic>;
        String profileOwnerItemId = '';
        String reviewerItemId = '';

        // เช็กว่าเจ้าของโปรไฟล์นี้ (widget.userId) อยู่ฝั่งไหนของข้อเสนอ
        if (offerData['target_user_id'] == widget.userId) {
          profileOwnerItemId = offerData['target_listing_id'] ?? '';
          reviewerItemId = offerData['offered_listing_id'] ?? '';
        } else {
          profileOwnerItemId = offerData['offered_listing_id'] ?? '';
          reviewerItemId = offerData['target_listing_id'] ?? '';
        }

        // ดึงข้อมูลไอเทมของเจ้าของโปรไฟล์
        if (profileOwnerItemId.isNotEmpty) {
          final pDoc = await FirebaseFirestore.instance.collection('listings').doc(profileOwnerItemId).get();
          if (pDoc.exists) {
            profileOwnerItemData = pDoc.data() as Map<String, dynamic>;
            profileOwnerItemData!['listing_id'] = pDoc.id; 
          }
        }

        // ดึงข้อมูลไอเทมของคนรีวิว
        if (reviewerItemId.isNotEmpty) {
          final rDoc = await FirebaseFirestore.instance.collection('listings').doc(reviewerItemId).get();
          if (rDoc.exists) {
            reviewerItemData = rDoc.data() as Map<String, dynamic>;
            reviewerItemData!['listing_id'] = rDoc.id;
          }
        }
      }

      await Future.wait([
        userFuture.then((snap) {
          if (snap.exists) {
            final data = snap.data() as Map<String, dynamic>;
            name = data['name'] ?? 'ผู้ใช้งาน';
            img = data['profile_img_url'] ?? '';
          }
        }),
        fetchItems()
      ]);

    } catch (e) {
      debugPrint('Error fetching review details: $e');
    }

    return {
      'name': name, 
      'img': img, 
      'profileOwnerItem': profileOwnerItemData, 
      'reviewerItem': reviewerItemData
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // 🟢 1. ปิดสีเคลือบสะท้อนของ Material 3
        scrolledUnderElevation: 0, // 🟢 2. ปิดเงาและการยกระดับตอนเลื่อนจอ
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        // 🟢 ไม่มี actions menu (ไม่สามารถแก้ไข หรือ logout ได้)
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: tealColor));
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('ไม่พบข้อมูลผู้ใช้'));

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String name = userData['name'] ?? 'ผู้ใช้ใหม่';
          final String bio = userData['bio'] ?? 'ยังไม่มีคำอธิบายตัวเอง';
          final double rating = (userData['rating_scores'] ?? 0.0).toDouble();
          final String profileImg = userData['profile_img_url'] ?? '';

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: Colors.grey.shade200,
                                image: profileImg.isNotEmpty ? DecorationImage(image: NetworkImage(profileImg), fit: BoxFit.cover) : null,
                                boxShadow: [BoxShadow(color: tealColor.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
                              ),
                              child: profileImg.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: Icon(Icons.verified, color: Colors.green.shade400, size: 16),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(bio, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
                        ),
                        const SizedBox(height: 20),

                        // 🟢 แถบสถิติ 2 ช่อง (ตัด Coins ออก)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('listings').where('owner_id', isEqualTo: widget.userId).where('status', isEqualTo: 'active').snapshots(),
                              builder: (context, itemSnap) {
                                int itemCount = itemSnap.hasData ? itemSnap.data!.docs.length : 0;
                                return _buildStatPill(Icons.inventory_2_outlined, '$itemCount Items');
                              }
                            ),
                            const SizedBox(width: 8),
                            FutureBuilder<int>(
                              future: () async {
                                try {
                                  final sentSnap = await FirebaseFirestore.instance.collection('offers')
                                      .where('sender_id', isEqualTo: widget.userId)
                                      .where('status', isEqualTo: 'completed')
                                      .get();
                                  
                                  final receivedSnap = await FirebaseFirestore.instance.collection('offers')
                                      .where('target_user_id', isEqualTo: widget.userId)
                                      .where('status', isEqualTo: 'completed')
                                      .get();
                                      
                                  return sentSnap.docs.length + receivedSnap.docs.length;
                                } catch (e) {
                                  return 0;
                                }
                              }(),
                              builder: (context, tradeSnap) {
                                int tradeCount = tradeSnap.data ?? 0;
                                return _buildStatPill(Icons.swap_horiz, '$tradeCount Trades');
                              }
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _buildRatingCard(rating),
                        const SizedBox(height: 20),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(child: _buildTabButton('Active Items')),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTabButton('Peer Reviews')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ];
            },
            body: _selectedTab == 'Active Items' 
                ? _buildActiveItemsGrid() 
                : _buildReviewsList(), 
          );
        }
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tealColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: tealColor),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: tealColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRatingCard(double rating) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.star, color: Colors.orange, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(rating > 0 ? rating.toStringAsFixed(1) : 'New', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(5, (index) => Icon(
                        index < rating.floor() ? Icons.star : Icons.star_border, 
                        color: Colors.orange, size: 14
                      )),
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Text('Based on user reviews', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.green.shade100.withOpacity(0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
            child: Row(
              children: [
                Icon(Icons.help_outline, size: 12, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text('Verified', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTabButton(String title) {
    bool isSelected = _selectedTab == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? tealColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? tealColor : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: tealColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(title == 'Active Items' ? Icons.inventory_2 : Icons.chat_bubble_outline, size: 16, color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveItemsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('listings').where('owner_id', isEqualTo: widget.userId).where('status', isEqualTo: 'active').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('ผู้ใช้นี้ยังไม่มีสิ่งของ', style: TextStyle(color: Colors.grey.shade500)));

        final docs = snapshot.data!.docs;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            data['listing_id'] = docs[index].id;
            
            return InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(itemData: data))),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          image: (data['thumbnail_url'] != null && data['thumbnail_url'] != '') 
                              ? DecorationImage(image: NetworkImage(data['thumbnail_url']), fit: BoxFit.cover) : null,
                        ),
                        child: (data['thumbnail_url'] == null || data['thumbnail_url'] == '') ? const Center(child: Icon(Icons.image, color: Colors.grey)) : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.monetization_on, color: Colors.green.shade700, size: 10),
                                const SizedBox(width: 4),
                                Text('${data['estimated_coins'] ?? 0}', style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
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
      }
    );
  }

  Widget _buildItemSide(BuildContext context, Map<String, dynamic>? item, String label, {bool isRight = false}) {
    final title = item?['title'] ?? 'ถูกลบไปแล้ว';
    final img = item?['thumbnail_url'] ?? '';

    Widget imageWidget = Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
        image: img.isNotEmpty ? DecorationImage(image: NetworkImage(img), fit: BoxFit.cover) : null,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: img.isEmpty ? const Icon(Icons.image, size: 16, color: Colors.grey) : null,
    );

    Widget textWidget = Expanded(
      child: Column(
        crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          Text(
            title, 
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: item == null ? Colors.red : Colors.black87), 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        if (item != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(itemData: item)));
        }
      },
      child: Container(
        color: Colors.transparent, 
        child: Row(
          mainAxisAlignment: isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: isRight ? [textWidget, const SizedBox(width: 8), imageWidget] : [imageWidget, const SizedBox(width: 8), textWidget],
        ),
      ),
    );
  }

  Widget _buildTradedItemBox(BuildContext context, Map<String, dynamic>? ownerItem, Map<String, dynamic>? reviewerItem) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(child: _buildItemSide(context, reviewerItem, 'ของคู่เทรด')),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
            child: Icon(Icons.swap_horiz, size: 16, color: tealColor),
          ),
          Expanded(child: _buildItemSide(context, ownerItem, 'ของเจ้าของโปรไฟล์', isRight: true)),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('target_id', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: tealColor));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('ยังไม่มีรีวิว', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          Timestamp timeA = dataA['created_at'] ?? Timestamp.now();
          Timestamp timeB = dataB['created_at'] ?? Timestamp.now();
          return timeB.compareTo(timeA);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String reviewerId = data['reviewer_id'] ?? '';
            final String transactionId = data['transaction_id'] ?? '';
            final double rating = (data['rating'] ?? 0).toDouble();
            final String comment = data['comment'] ?? '';
            final Timestamp? time = data['created_at'];
            
            String timeText = '';
            if (time != null) {
              final date = time.toDate();
              timeText = '${date.day}/${date.month}/${date.year}';
            }

            return FutureBuilder<Map<String, dynamic>>(
              future: _fetchReviewDetails(reviewerId, transactionId),
              builder: (context, detailsSnap) {
                String reviewerName = 'กำลังโหลด...';
                String reviewerImg = '';
                Map<String, dynamic>? ownerItem;
                Map<String, dynamic>? reviewerItem;

                if (detailsSnap.hasData) {
                  reviewerName = detailsSnap.data!['name'] ?? 'ผู้ใช้งาน';
                  reviewerImg = detailsSnap.data!['img'] ?? '';
                  ownerItem = detailsSnap.data!['profileOwnerItem']; 
                  reviewerItem = detailsSnap.data!['reviewerItem']; 
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.teal.shade50,
                            backgroundImage: reviewerImg.isNotEmpty ? NetworkImage(reviewerImg) : null,
                            child: reviewerImg.isEmpty ? Icon(Icons.person, color: tealColor) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(reviewerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    Text(timeText, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: List.generate(5, (starIndex) => Icon(
                                    starIndex < rating.floor() ? Icons.star : Icons.star_border,
                                    color: Colors.orange, size: 14,
                                  )),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          comment, 
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4)
                        ),
                      ],
                      if (detailsSnap.connectionState == ConnectionState.waiting)
                         const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator())),
                      if (detailsSnap.hasData && (ownerItem != null || reviewerItem != null))
                         _buildTradedItemBox(context, ownerItem, reviewerItem),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}