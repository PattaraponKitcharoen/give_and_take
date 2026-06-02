import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_detail_screen.dart'; // ดึงมาใช้เพื่อให้กดดูของจากหน้าโปรไฟล์ได้

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  // 🟢 ฟังก์ชันช่วยดึงข้อมูลไอเทมที่ถูกแลกเปลี่ยนในรีวิวนี้
  Future<Map<String, dynamic>?> _getExchangedItem(String transactionId) async {
    try {
      final txDoc = await FirebaseFirestore.instance.collection('transactions').doc(transactionId).get();
      if (!txDoc.exists) return null;
      
      List<dynamic> listings = txDoc.data()?['listings'] ?? [];
      if (listings.isEmpty) return null;

      final itemsQuery = await FirebaseFirestore.instance.collection('listings')
          .where(FieldPath.documentId, whereIn: listings).get();

      for (var doc in itemsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // หาว่าชิ้นไหนเป็นของเจ้าของโปรไฟล์นี้ (เพื่อให้โชว์ของถูกชิ้น)
        if (data['owner_id'] == userId) {
          data['listing_id'] = doc.id;
          return data;
        }
      }
    } catch (e) {
      debugPrint('Error fetching exchanged item: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tealColor = const Color(0xFF008080);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('โปรไฟล์ผู้ใช้', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0.5,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('ไม่พบข้อมูลผู้ใช้'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String name = userData['name'] ?? 'ผู้ใช้งาน';
          final String bio = userData['bio'] ?? 'ยังไม่มีคำอธิบายโปรไฟล์'; 
          final double rating = (userData['rating_scores'] ?? 0.0).toDouble();
          final int reviewCount = userData['rating_count'] ?? 0;
          final String profileImg = userData['profile_img_url'] ?? '';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // โซนหัวโปรไฟล์
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                        child: profileImg.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.grey) : null, 
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  rating > 0 ? rating.toStringAsFixed(1) : 'New',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(' ($reviewCount รีวิว)', style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(bio, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // โซนสิ่งของทั้งหมดของผู้ใช้ (พับเก็บได้)
                Container(
                  color: Colors.white,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true, 
                      title: const Text('สิ่งของที่ลงแลกเปลี่ยน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('listings')
                              .where('owner_id', isEqualTo: userId)
                              .where('status', isEqualTo: 'active')
                              .snapshots(),
                          builder: (context, itemSnap) {
                            if (itemSnap.connectionState == ConnectionState.waiting) {
                              return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
                            }
                            if (!itemSnap.hasData || itemSnap.data!.docs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('ยังไม่มีสิ่งของที่กำลังแลกเปลี่ยน', style: TextStyle(color: Colors.grey)),
                              );
                            }

                            final items = itemSnap.data!.docs;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.8,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final itemData = items[index].data() as Map<String, dynamic>;
                                  itemData['listing_id'] = items[index].id;
                                  
                                  final String title = itemData['title'] ?? 'ไม่มีชื่อ';
                                  final int coins = itemData['estimated_coins'] ?? 0;
                                  final String thumbnail = itemData['thumbnail_url'] ?? '';

                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(itemData: itemData)));
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                              ),
                                              child: thumbnail.isNotEmpty 
                                                ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(11)), child: Image.network(thumbnail, fit: BoxFit.cover))
                                                : const Icon(Icons.image, size: 40, color: Colors.black12),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.monetization_on, size: 12, color: tealColor),
                                                    const SizedBox(width: 4),
                                                    Text('$coins Coins', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold, fontSize: 12)),
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
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // โซนรายการรีวิวของจริง (พับเก็บได้)
                Container(
                  color: Colors.white,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true, 
                      title: const Text('รีวิวจากผู้ใช้งาน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('reviews')
                              .where('target_id', isEqualTo: userId)
                              .snapshots(),
                          builder: (context, reviewSnap) {
                            if (reviewSnap.hasError) {
                              return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดรีวิว', style: TextStyle(color: Colors.red)));
                            }
                            if (reviewSnap.connectionState == ConnectionState.waiting) {
                              return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
                            }
                            if (!reviewSnap.hasData || reviewSnap.data!.docs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('ยังไม่มีรีวิว', style: TextStyle(color: Colors.grey)),
                              );
                            }

                            final reviews = reviewSnap.data!.docs;
                            reviews.sort((a, b) {
                              Timestamp timeA = (a.data() as Map<String, dynamic>)['created_at'] ?? Timestamp.now();
                              Timestamp timeB = (b.data() as Map<String, dynamic>)['created_at'] ?? Timestamp.now();
                              return timeB.compareTo(timeA);
                            });

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16), 
                              itemCount: reviews.length,
                              itemBuilder: (context, index) {
                                final reviewData = reviews[index].data() as Map<String, dynamic>;
                                final int star = reviewData['rating'] ?? 5;
                                final String comment = reviewData['comment'] ?? '';
                                final String reviewerId = reviewData['reviewer_id'] ?? '';
                                final String transactionId = reviewData['transaction_id'] ?? '';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance.collection('users').doc(reviewerId).get(),
                                        builder: (context, userSnap) {
                                          String reviewerName = 'ผู้ใช้งาน';
                                          if (userSnap.hasData && userSnap.data!.exists) {
                                            reviewerName = (userSnap.data!.data() as Map<String, dynamic>)['name'] ?? 'ผู้ใช้งาน';
                                          }
                                          return Row(
                                            children: [
                                              CircleAvatar(radius: 14, backgroundColor: tealColor.withOpacity(0.1), child: Icon(Icons.person, size: 16, color: tealColor)),
                                              const SizedBox(width: 8),
                                              Text(reviewerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            ],
                                          );
                                        }
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: List.generate(5, (starIndex) {
                                          return Icon(
                                            starIndex < star ? Icons.star : Icons.star_border,
                                            color: Colors.amber,
                                            size: 16,
                                          );
                                        }),
                                      ),
                                      if (comment.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(comment, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                      ],
                                      
                                      // 🟢 แสดงการ์ดสิ่งของที่ได้แลกเปลี่ยนไป
                                      if (transactionId.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        FutureBuilder<Map<String, dynamic>?>(
                                          future: _getExchangedItem(transactionId),
                                          builder: (context, itemSnap) {
                                            if (!itemSnap.hasData || itemSnap.data == null) return const SizedBox();
                                            
                                            final itemData = itemSnap.data!;
                                            final itemTitle = itemData['title'] ?? 'ไม่มีชื่อสินค้า';
                                            final itemThumb = itemData['thumbnail_url'] ?? '';

                                            return GestureDetector(
                                              onTap: () {
                                                // พอกดก็จะเด้งไปหน้า Detail ซึ่งปุ่มด้านล่างจะเทาและกดไม่ได้อัตโนมัติ
                                                Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(itemData: itemData)));
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey.shade300)
                                                ),
                                                child: Row(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: itemThumb.isNotEmpty 
                                                        ? Image.network(itemThumb, width: 40, height: 40, fit: BoxFit.cover)
                                                        : Container(width: 40, height: 40, color: Colors.grey.shade300, child: const Icon(Icons.image, size: 20, color: Colors.grey)),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Text('แลกเปลี่ยนสิ่งของ:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                          Text(itemTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF008080)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                        ]
                                                      )
                                                    ),
                                                    const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)
                                                  ]
                                                )
                                              )
                                            );
                                          }
                                        ),
                                      ],

                                      const SizedBox(height: 16),
                                      const Divider(height: 1),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40), 
              ],
            ),
          );
        },
      ),
    );
  }
}