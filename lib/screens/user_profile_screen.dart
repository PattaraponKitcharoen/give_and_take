import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

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
        // ดึงข้อมูลผู้ใช้
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
          final String bio = userData['bio'] ?? 'ยังไม่มีคำอธิบายโปรไฟล์'; // ดักเผื่อไม่มีฟิลด์ bio
          final double rating = (userData['rating_scores'] ?? 0.0).toDouble();
          final int reviewCount = userData['rating_count'] ?? 0;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟢 โซนหัวโปรไฟล์
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade200,
                        child: const Icon(Icons.person, size: 40, color: Colors.grey), // Mockup รูปโปรไฟล์
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

                // 🟢 โซนรายการรีวิว (ดึงจากคอลเลกชัน reviews)
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('รีวิวจากผู้ใช้งาน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Divider(height: 30),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('reviews')
                            .where('target_id', isEqualTo: userId)
                            .orderBy('created_at', descending: true)
                            .snapshots(),
                        builder: (context, reviewSnap) {
                          if (reviewSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                          }
                          if (!reviewSnap.hasData || reviewSnap.data!.docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('ยังไม่มีรีวิว', style: TextStyle(color: Colors.grey))),
                            );
                          }

                          final reviews = reviewSnap.data!.docs;

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(), // ปิดการสกรอล์ซ้อนกัน
                            itemCount: reviews.length,
                            itemBuilder: (context, index) {
                              final reviewData = reviews[index].data() as Map<String, dynamic>;
                              final int star = reviewData['rating'] ?? 5;
                              final String comment = reviewData['comment'] ?? '';
                              final String reviewerId = reviewData['reviewer_id'] ?? '';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // FutureBuilder ยิงไปดึงชื่อคนให้คะแนน
                                    FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance.collection('users').doc(reviewerId).get(),
                                      builder: (context, userSnap) {
                                        String reviewerName = 'ผู้ใช้งาน';
                                        if (userSnap.hasData && userSnap.data!.exists) {
                                          reviewerName = (userSnap.data!.data() as Map<String, dynamic>)['name'] ?? 'ผู้ใช้งาน';
                                        }
                                        return Row(
                                          children: [
                                            CircleAvatar(radius: 12, backgroundColor: tealColor.withOpacity(0.2), child: Icon(Icons.person, size: 14, color: tealColor)),
                                            const SizedBox(width: 8),
                                            Text(reviewerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          ],
                                        );
                                      }
                                    ),
                                    const SizedBox(height: 6),
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
                                    const SizedBox(height: 8),
                                    const Divider(),
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
              ],
            ),
          );
        },
      ),
    );
  }
}