import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../repositories/report_repository.dart';
import '../widgets/report_sheet.dart';
import '../widgets/star_rating.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/user_repository.dart';
import '../repositories/listing_repository.dart';
import '../models/user_model.dart';
import '../models/listing_model.dart';
import 'item_detail_screen.dart';
import '../theme/app_theme.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final Color tealColor = AppColors.primary;
  final Color bgColor = AppColors.background;

  String _selectedTab = 'Active';
  List<Map<String, dynamic>> _reviewsData = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _fetchReviewDetails();
  }

  Future<void> _fetchReviewDetails() async {
    try {
      final reviews = await context
          .read<UserRepository>()
          .getEnrichedReviews(widget.userId);
      if (mounted) {
        setState(() {
          _reviewsData = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        actions: [
          if (widget.userId !=
              context.read<AuthRepository>().currentUser?.uid)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (_) => showReportSheet(context,
                  type: ReportTarget.user, targetId: widget.userId),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'report',
                  child: Row(children: [
                    Icon(Icons.flag_outlined, color: AppColors.danger, size: 20),
                    SizedBox(width: 10),
                    Text('รายงานผู้ใช้นี้'),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: StreamBuilder<UserModel>(
          stream: context.read<UserRepository>().getUserStream(widget.userId),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError)
              return const Center(child: Text('เกิดข้อผิดพลาด'));
            if (userSnapshot.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator(color: tealColor));

            final userData = userSnapshot.data;
            if (userData == null)
              return const Center(child: Text('ไม่พบข้อมูลผู้ใช้'));

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.hairline,
                                  border:
                                      Border.all(color: Colors.white, width: 4),
                                  image: userData.profileImgUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(
                                              userData.profileImgUrl),
                                          fit: BoxFit.cover)
                                      : null,
                                  boxShadow: AppShadows.lifted,
                                ),
                                child: userData.profileImgUrl.isEmpty
                                    ? const Icon(Icons.person,
                                        size: 50, color: Colors.white)
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: AppShadows.raised),
                                child: const Icon(Icons.verified_rounded,
                                    color: AppColors.primary, size: 18),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(userData.name, style: AppText.display),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: userData.bio.trim().isEmpty
                                ? Text('ผู้ใช้นี้ยังไม่ได้เพิ่มไบโอ',
                                    textAlign: TextAlign.center,
                                    style: AppText.bodySecondary
                                        .copyWith(color: AppColors.inkTertiary))
                                : Text(userData.bio,
                                    textAlign: TextAlign.center,
                                    style: AppText.bodySecondary),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FutureBuilder<int>(
                                  future: context
                                      .read<ListingRepository>()
                                      .getActiveListingCount(widget.userId),
                                  builder: (context, itemSnap) {
                                    int itemCount = itemSnap.data ?? 0;
                                    return _buildStatPill(
                                        Icons.inventory_2_outlined,
                                        '$itemCount Items');
                                  }),
                              const SizedBox(width: 8),
                              FutureBuilder<int>(
                                  future: context
                                      .read<UserRepository>()
                                      .getTradeCount(widget.userId),
                                  builder: (context, tradeSnap) {
                                    int tradeCount = tradeSnap.data ?? 0;
                                    return _buildStatPill(
                                        Icons.swap_horiz, '$tradeCount Trades');
                                  }),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildRatingCard(userData.rating),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: _buildTabButton('Active')),
                                  Expanded(child: _buildTabButton('Reviews')),
                                  Expanded(child: _buildTabButton('Traded')),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ];
              },
              body: switch (_selectedTab) {
                'Active' => _buildListingsGrid(
                    context
                        .read<ListingRepository>()
                        .getUserActiveListingsStream(widget.userId),
                    'ผู้ใช้นี้ยังไม่มีสิ่งของ'),
                'Reviews' => _buildReviewsList(),
                // Items this user has already traded away — public, so anyone
                // can check their history before making an offer.
                _ => _buildListingsGrid(
                    context
                        .read<ListingRepository>()
                        .getUserListings(widget.userId, status: 'completed'),
                    'ยังไม่มีประวัติการแลกเปลี่ยน',
                    traded: true),
              },
            );
          }),
    );
  }

  Widget _buildStatPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: AppText.label.copyWith(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRatingCard(double rating) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                gradient: AppGradients.of(AppColors.gold),
                shape: BoxShape.circle,
                boxShadow: AppShadows.glow(AppColors.gold)),
            child:
                const Icon(Icons.star_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(rating > 0 ? rating.toStringAsFixed(1) : 'New',
                        style: AppText.title),
                    const SizedBox(width: 8),
                    StarRating(rating: rating),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Based on user reviews', style: AppText.caption),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Row(
              children: [
                Icon(Icons.help_outline, size: 12, color: AppColors.success),
                const SizedBox(width: 4),
                Text('Verified',
                    style: AppText.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: isSelected ? AppShadows.raised : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                switch (title) {
                  'Active' => Icons.inventory_2,
                  'Reviews' => Icons.chat_bubble_outline,
                  _ => Icons.history,
                },
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.inkTertiary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(
                      color:
                          isSelected ? AppColors.ink : AppColors.inkSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  // [traded] greys the cards out with a "แลกไปแล้ว" badge — same look as
  // the Traded tab on your own profile (ProfileScreen._buildTradeHistoryGrid).
  Widget _buildListingsGrid(Stream<List<ListingModel>> stream, String emptyText,
      {bool traded = false}) {
    return StreamBuilder<List<ListingModel>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return Center(
                child: Text(emptyText,
                    style: TextStyle(color: AppColors.inkTertiary)));

          final listings = snapshot.data!;
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
                        builder: (context) => ItemDetailScreen(listing: item))),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border:
                        Border.all(color: AppColors.hairline.withOpacity(0.6)),
                    boxShadow: AppShadows.raised,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16)),
                                image: item.thumbnailUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(item.thumbnailUrl),
                                        fit: BoxFit.cover,
                                        colorFilter: traded
                                            ? ColorFilter.mode(
                                                Colors.black.withOpacity(0.35),
                                                BlendMode.darken)
                                            : null)
                                    : null,
                              ),
                              child: item.thumbnailUrl.isEmpty
                                  ? const Center(
                                      child: Icon(Icons.image,
                                          color: AppColors.inkTertiary))
                                  : null,
                            ),
                            if (traded)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Text('แลกไปแล้ว',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
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
                                  color: traded
                                      ? AppColors.surfaceMuted
                                      : AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.toll_rounded,
                                      color: traded
                                          ? AppColors.inkSecondary
                                          : AppColors.primaryDark,
                                      size: 10),
                                  const SizedBox(width: 4),
                                  Text('${item.estimatedCoins}',
                                      style: TextStyle(
                                          color: traded
                                              ? AppColors.inkSecondary
                                              : AppColors.primaryDark,
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
        color: AppColors.hairline,
        image: img.isNotEmpty
            ? DecorationImage(image: NetworkImage(img), fit: BoxFit.cover)
            : null,
        border: Border.all(color: AppColors.hairline),
      ),
      child: img.isEmpty
          ? const Icon(Icons.image, size: 16, color: AppColors.inkTertiary)
          : null,
    );

    Widget textWidget = Expanded(
      child: Column(
        crossAxisAlignment:
            isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(fontSize: 9, color: AppColors.inkTertiary)),
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item == null ? AppColors.danger : AppColors.ink),
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

  Widget _buildTradedItemBox(BuildContext context,
      Map<String, dynamic>? ownerItem, Map<String, dynamic>? reviewerItem) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(child: _buildItemSide(context, reviewerItem, 'ของคู่เทรด')),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: tealColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.hairline)),
            child: Icon(Icons.swap_horiz, size: 16, color: tealColor),
          ),
          Expanded(
              child: _buildItemSide(context, ownerItem, 'ของเจ้าของโปรไฟล์',
                  isRight: true)),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_isLoadingReviews) {
      return Center(child: CircularProgressIndicator(color: tealColor));
    }

    if (_reviewsData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 40, color: AppColors.hairline),
            const SizedBox(height: 12),
            Text('ยังไม่มีรีวิว',
                style: TextStyle(color: AppColors.inkTertiary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviewsData.length,
      itemBuilder: (context, index) {
        final entry = _reviewsData[index];
        // getEnrichedReviews returns {review, name, img, myItem, theirItem};
        // this screen used to read rating/comment/reviewer_name off the top
        // level, so every review showed 0 stars, no text and "ผู้ใช้งาน".
        final data = Map<String, dynamic>.from(entry['review'] ?? {});
        final double rating = (data['rating'] ?? 0).toDouble();
        final String comment = data['comment'] ?? '';
        final DateTime? time = data['created_at'] != null
            ? (data['created_at'] is DateTime
                ? data['created_at']
                : (data['created_at']).toDate())
            : null;

        String timeText = '';
        if (time != null) {
          timeText = '${time.day}/${time.month}/${time.year}';
        }

        String reviewerName = entry['name'] ?? 'ผู้ใช้งาน';
        String reviewerImg = entry['img'] ?? '';
        Map<String, dynamic>? ownerItem = entry['myItem'];
        Map<String, dynamic>? reviewerItem = entry['theirItem'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.hairline.withOpacity(0.6)),
            boxShadow: AppShadows.raised,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primarySoft,
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
                                    color: AppColors.inkTertiary,
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
                                    color: AppColors.warning,
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
                        color: AppColors.inkSecondary,
                        fontSize: 13,
                        height: 1.4)),
              ],
              if (ownerItem != null || reviewerItem != null)
                _buildTradedItemBox(context, ownerItem, reviewerItem),
            ],
          ),
        );
      },
    );
  }
}
