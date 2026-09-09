import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // 🟢 เพิ่ม BLoC
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp in reviews
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'wallet_history_screen.dart';
import 'item_detail_screen.dart';
import '../cubits/profile/profile_cubit.dart';
import '../cubits/profile/profile_state.dart';
import '../repositories/user_repository.dart';
import '../repositories/listing_repository.dart';
import '../repositories/auth_repository.dart';
import '../models/listing_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF8FAFC);
  User? get currentUser => context.read<AuthRepository>().currentUser;

  String _selectedTab = 'Active Items';

  Future<void> _logout() async {
    await context.read<AuthRepository>().signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false);
    }
  }

  double _calculateRating(List<Map<String, dynamic>> enrichedReviews) {
    if (enrichedReviews.isEmpty) return 0.0;
    double sum = 0;
    for (var r in enrichedReviews) {
      sum += ((r['review']?['rating'] ?? 0) as num).toDouble();
    }
    return sum / enrichedReviews.length;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('กรุณาล็อกอิน')));
    }

    return BlocProvider(
      create: (context) => ProfileCubit(
        userRepository: context.read<UserRepository>(),
        listingRepository: context.read<ListingRepository>(),
        authRepository: context.read<AuthRepository>(),
        userId: currentUser?.uid ?? '',
      ),
      child: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded && state.verificationMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.verificationMessage!),
                backgroundColor: state.isVerificationError ? Colors.red : tealColor,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<ProfileCubit>().clearVerificationMessage();
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading) {
            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                title: const Text('โปรไฟล์ของฉัน', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                centerTitle: true,
              ),
              body: Center(child: CircularProgressIndicator(color: tealColor)),
            );
          }

          if (state is ProfileError) {
            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(title: const Text('โปรไฟล์ของฉัน')),
              body: Center(child: Text('Error: ${state.message}')),
            );
          }

          if (state is ProfileLoaded) {
            final user = state.user;
            final name = user.name;
            final bio = user.bio;
            final coins = user.coinsBalance.toInt();
            final rating = _calculateRating(state.enrichedReviews);
            final profileImg = user.profileImgUrl;
            final isEmailVerified = user.isEmailVerified;
            final isSendingEmail = state.isSendingVerification;

            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                title: const Text('โปรไฟล์ของฉัน', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                centerTitle: true,
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.black87),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(currentUser: user)));
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
                  ),
                ],
              ),
              body: NestedScrollView(
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
                                  onTap: isSendingEmail
                                      ? null
                                      : () => context.read<ProfileCubit>().sendVerificationEmail(),
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
                                        isSendingEmail
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
                                          isSendingEmail
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
                                _buildStatPill(Icons.inventory_2_outlined, '${state.userListings.length} Items'),
                                const SizedBox(width: 8),
                                _buildStatPill(Icons.swap_horiz, '${state.tradeCount} Trades'),
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
                    ? _buildActiveItemsGrid(context, state)
                    : _buildReviewsList(context, state),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
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

  Widget _buildActiveItemsGrid(BuildContext context, ProfileLoaded state) {
    final listings = state.userListings;

    if (listings.isEmpty) {
      return Center(
          child: Text('คุณยังไม่มีสิ่งของ',
              style: TextStyle(color: Colors.grey.shade500)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final item = listings[index];
        return InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      ItemDetailScreen(listing: item))),
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
                      image: item.thumbnailUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(item.thumbnailUrl),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: item.thumbnailUrl.isEmpty
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
                      Text(item.title,
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
                            Text('${item.estimatedCoins}',
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
          final listing = ListingModel.fromJson(item, item['listing_id'] ?? '');
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ItemDetailScreen(listing: listing)));
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

  Widget _buildReviewsList(BuildContext context, ProfileLoaded state) {
    final reviews = state.enrichedReviews;

    if (reviews.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final data = reviews[index];
        final reviewData = data['review'] as Map<String, dynamic>;
        final reviewerName = data['name'] ?? 'ผู้ใช้งาน';
        final reviewerImg = data['img'] ?? '';
        final myItem = data['myItem'];
        final theirItem = data['theirItem'];
        
        final double rating = (reviewData['rating'] ?? 0).toDouble();
        final String comment = reviewData['comment'] ?? '';
        final Timestamp? time = reviewData['created_at'];

        String timeText = '';
        if (time != null) {
          final date = time.toDate();
          timeText = '${date.day}/${date.month}/${date.year}';
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              if (myItem != null || theirItem != null)
                _buildTradedItemBox(context, myItem, theirItem),
            ],
          ),
        );
      },
    );
  }
}
