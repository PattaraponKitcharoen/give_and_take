import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'wallet_history_screen.dart';
import 'item_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF8FAFC);
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String _selectedTab = 'Active Items';
  bool _isSendingEmail = false;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false);
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (currentUser == null) return;

    setState(() => _isSendingEmail = true);
    try {
      await currentUser!.sendEmailVerification();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'ส่งลิงก์ไปยัง ${currentUser!.email} แล้ว กรุณาเช็กอีเมลของคุณ'),
          backgroundColor: tealColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'เกิดข้อผิดพลาดในการส่งอีเมล';
      if (e.code == 'too-many-requests') {
        message = 'ส่งถี่เกินไป กรุณารอสักครู่แล้วลองใหม่';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  Future<Map<String, dynamic>> _fetchReviewDetails(
      String reviewerId, String transactionId) async {
    String name = 'ผู้ใช้งาน';
    String img = '';
    Map<String, dynamic>? myItemData;
    Map<String, dynamic>? theirItemData;

    try {
      final userFuture =
          FirebaseFirestore.instance.collection('users').doc(reviewerId).get();

      Future<void> fetchItems() async {
        if (transactionId.isEmpty) return;
        final txDoc = await FirebaseFirestore.instance
            .collection('transactions')
            .doc(transactionId)
            .get();
        if (!txDoc.exists) return;

        final offerId = txDoc.data()?['offer_id'];
        if (offerId == null || offerId.isEmpty) return;

        final offerDoc = await FirebaseFirestore.instance
            .collection('offers')
            .doc(offerId)
            .get();
        if (!offerDoc.exists) return;

        final offerData = offerDoc.data() as Map<String, dynamic>;
        String myItemId = '';
        String theirItemId = '';

        if (offerData['target_user_id'] == currentUser!.uid) {
          myItemId = offerData['target_listing_id'] ?? '';
          theirItemId = offerData['offered_listing_id'] ?? '';
        } else {
          myItemId = offerData['offered_listing_id'] ?? '';
          theirItemId = offerData['target_listing_id'] ?? '';
        }

        if (myItemId.isNotEmpty) {
          final myDoc = await FirebaseFirestore.instance
              .collection('listings')
              .doc(myItemId)
              .get();
          if (myDoc.exists) {
            myItemData = myDoc.data() as Map<String, dynamic>;
            myItemData!['listing_id'] = myDoc.id;
          }
        }

        if (theirItemId.isNotEmpty) {
          final theirDoc = await FirebaseFirestore.instance
              .collection('listings')
              .doc(theirItemId)
              .get();
          if (theirDoc.exists) {
            theirItemData = theirDoc.data() as Map<String, dynamic>;
            theirItemData!['listing_id'] = theirDoc.id;
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
      'myItem': myItemData,
      'theirItem': theirItemData
    };
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null)
      return const Scaffold(body: Center(child: Text('กรุณาล็อกอิน')));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('โปรไฟล์ของฉัน',
            style: TextStyle(
                color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              Map<String, dynamic> userData = {};
              if (snapshot.hasData && snapshot.data!.exists) {
                userData = snapshot.data!.data() as Map<String, dynamic>;
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black87),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                EditProfileScreen(currentData: userData)));
                  } else if (value == 'logout') {
                    _logout();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('แก้ไขโปรไฟล์')
                      ])),
                  const PopupMenuItem(
                      value: 'logout',
                      child: Row(children: [
                        Icon(Icons.logout, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('ออกจากระบบ', style: TextStyle(color: Colors.red))
                      ])),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator(color: tealColor));

            Map<String, dynamic> userData = {};
            if (snapshot.hasData && snapshot.data!.exists) {
              userData = snapshot.data!.data() as Map<String, dynamic>;
            }

            final String name = userData['name'] ?? 'ผู้ใช้ใหม่';
            final String bio = userData['bio'] ?? 'ยังไม่มีคำอธิบายตัวเอง';
            final int coins = userData['coins_balance'] ?? 0;
            final double rating = (userData['rating_scores'] ?? 0.0).toDouble();
            final String profileImg = userData['profile_img_url'] ?? '';

            // 🟢 ดึงค่าสถานะการยืนยันอีเมลจาก Firestore มาใช้งานตรงๆ
            final bool isEmailVerified = userData['is_email_verified'] == true;

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
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: Colors.grey.shade200,
                                  image: profileImg.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(profileImg),
                                          fit: BoxFit.cover)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                        color: tealColor.withOpacity(0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10))
                                  ],
                                ),
                                child: profileImg.isEmpty
                                    ? const Icon(Icons.person,
                                        size: 50, color: Colors.white)
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2)),
                                child: Icon(Icons.verified,
                                    color: Colors.green.shade400, size: 16),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF004D40))),
                              const SizedBox(width: 8),
                              if (isEmailVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.blue.shade200)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.mark_email_read,
                                          size: 12,
                                          color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text('Email Verified',
                                          style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                            ],
                          ),
                          if (!isEmailVerified)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GestureDetector(
                                onTap: _isSendingEmail
                                    ? null
                                    : _sendVerificationEmail,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _isSendingEmail
                                          ? SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color:
                                                      Colors.orange.shade700))
                                          : Icon(Icons.warning_amber_rounded,
                                              size: 14,
                                              color: Colors.orange.shade700),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isSendingEmail
                                            ? 'กำลังส่ง...'
                                            : 'คลิกที่นี่เพื่อส่งอีเมลยืนยันตัวตน',
                                        style: TextStyle(
                                            color: Colors.orange.shade800,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(bio,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    height: 1.4)),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('listings')
                                      .where('owner_id',
                                          isEqualTo: currentUser!.uid)
                                      .where('status', isEqualTo: 'active')
                                      .snapshots(),
                                  builder: (context, itemSnap) {
                                    int itemCount = itemSnap.hasData
                                        ? itemSnap.data!.docs.length
                                        : 0;
                                    return _buildStatPill(
                                        Icons.inventory_2_outlined,
                                        '$itemCount Items');
                                  }),
                              const SizedBox(width: 8),
                              FutureBuilder<int>(future: () async {
                                try {
                                  final sentSnap = await FirebaseFirestore
                                      .instance
                                      .collection('offers')
                                      .where('sender_id',
                                          isEqualTo: currentUser!.uid)
                                      .where('status', isEqualTo: 'completed')
                                      .get();

                                  final receivedSnap = await FirebaseFirestore
                                      .instance
                                      .collection('offers')
                                      .where('target_user_id',
                                          isEqualTo: currentUser!.uid)
                                      .where('status', isEqualTo: 'completed')
                                      .get();

                                  return sentSnap.docs.length +
                                      receivedSnap.docs.length;
                                } catch (e) {
                                  return 0;
                                }
                              }(), builder: (context, tradeSnap) {
                                int tradeCount = tradeSnap.data ?? 0;
                                return _buildStatPill(
                                    Icons.swap_horiz, '$tradeCount Trades');
                              }),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const WalletHistoryScreen())),
                                child: _buildStatPill(
                                    Icons.monetization_on_outlined,
                                    '$coins Coins',
                                    isHighlight: true),
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
                                Expanded(
                                    child: _buildTabButton('Active Items')),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _buildTabButton('Peer Reviews')),
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
          }),
    );
  }

  Widget _buildStatPill(IconData icon, String text,
      {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.teal.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tealColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: tealColor),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: tealColor, fontWeight: FontWeight.bold, fontSize: 12)),
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
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.star, color: Colors.orange, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(rating > 0 ? rating.toStringAsFixed(1) : 'New',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF004D40))),
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(
                          5,
                          (index) => Icon(
                              index < rating.floor()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.orange,
                              size: 14)),
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Text('Based on user reviews',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.green.shade100.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200)),
            child: Row(
              children: [
                Icon(Icons.help_outline,
                    size: 12, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text('Verified',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
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
          border:
              Border.all(color: isSelected ? tealColor : Colors.grey.shade300),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: tealColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                title == 'Active Items'
                    ? Icons.inventory_2
                    : Icons.chat_bubble_outline,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveItemsGrid() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('listings')
            .where('owner_id', isEqualTo: currentUser!.uid)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return Center(
                child: Text('คุณยังไม่มีสิ่งของ',
                    style: TextStyle(color: Colors.grey.shade500)));

          final docs = snapshot.data!.docs;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              data['listing_id'] = docs[index].id;

              return InkWell(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ItemDetailScreen(itemData: data))),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            image: (data['thumbnail_url'] != null &&
                                    data['thumbnail_url'] != '')
                                ? DecorationImage(
                                    image: NetworkImage(data['thumbnail_url']),
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          child: (data['thumbnail_url'] == null ||
                                  data['thumbnail_url'] == '')
                              ? const Center(
                                  child: Icon(Icons.image, color: Colors.grey))
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['title'] ?? 'No Title',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.monetization_on,
                                      color: Colors.green.shade700, size: 10),
                                  const SizedBox(width: 4),
                                  Text('${data['estimated_coins'] ?? 0}',
                                      style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
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
        });
  }

  Widget _buildItemSide(
      BuildContext context, Map<String, dynamic>? item, String label,
      {bool isRight = false}) {
    final title = item?['title'] ?? 'ถูกลบไปแล้ว';
    final img = item?['thumbnail_url'] ?? '';

    Widget imageWidget = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
        image: img.isNotEmpty
            ? DecorationImage(image: NetworkImage(img), fit: BoxFit.cover)
            : null,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: img.isEmpty
          ? const Icon(Icons.image, size: 16, color: Colors.grey)
          : null,
    );

    Widget textWidget = Expanded(
      child: Column(
        crossAxisAlignment:
            isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item == null ? Colors.red : Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        if (item != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ItemDetailScreen(itemData: item)));
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment:
              isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: isRight
              ? [textWidget, const SizedBox(width: 8), imageWidget]
              : [imageWidget, const SizedBox(width: 8), textWidget],
        ),
      ),
    );
  }

  Widget _buildTradedItemBox(BuildContext context, Map<String, dynamic>? myItem,
      Map<String, dynamic>? theirItem) {
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
          Expanded(child: _buildItemSide(context, theirItem, 'ของคู่เทรด')),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200)),
            child: Icon(Icons.swap_horiz, size: 16, color: tealColor),
          ),
          Expanded(
              child: _buildItemSide(context, myItem, 'ของฉัน', isRight: true)),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('target_id', isEqualTo: currentUser!.uid)
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
                Icon(Icons.chat_bubble_outline,
                    size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('ยังไม่มีรีวิว',
                    style: TextStyle(color: Colors.grey.shade500)),
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
                Map<String, dynamic>? myItem;
                Map<String, dynamic>? theirItem;

                if (detailsSnap.hasData) {
                  reviewerName = detailsSnap.data!['name'] ?? 'ผู้ใช้งาน';
                  reviewerImg = detailsSnap.data!['img'] ?? '';
                  myItem = detailsSnap.data!['myItem'];
                  theirItem = detailsSnap.data!['theirItem'];
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
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
                            backgroundImage: reviewerImg.isNotEmpty
                                ? NetworkImage(reviewerImg)
                                : null,
                            child: reviewerImg.isEmpty
                                ? Icon(Icons.person, color: tealColor)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                        child: Text(reviewerName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                    Text(timeText,
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: List.generate(
                                      5,
                                      (starIndex) => Icon(
                                            starIndex < rating.floor()
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.orange,
                                            size: 14,
                                          )),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(comment,
                            style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                                height: 1.4)),
                      ],
                      if (detailsSnap.connectionState ==
                          ConnectionState.waiting)
                        const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Center(child: CircularProgressIndicator())),
                      if (detailsSnap.hasData &&
                          (myItem != null || theirItem != null))
                        _buildTradedItemBox(context, myItem, theirItem),
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
