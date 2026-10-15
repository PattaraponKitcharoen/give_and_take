import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/star_rating.dart';
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
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color tealColor = AppColors.primary;
  final Color bgColor = AppColors.background;
  User? get currentUser => context.read<AuthRepository>().currentUser;

  String _selectedTab = 'Active';

  // The header is transparent so the avatar can rise into it; once the
  // page scrolls it turns solid so content doesn't run under the title.
  final ScrollController _scrollController = ScrollController();
  bool _headerSolid = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final solid = _scrollController.offset > 24;
      if (solid != _headerSolid) setState(() => _headerSolid = solid);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                backgroundColor:
                    state.isVerificationError ? AppColors.danger : tealColor,
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
                title: const Text('Profile', style: AppText.title),
                centerTitle: false,
              ),
              body: Center(child: CircularProgressIndicator(color: tealColor)),
            );
          }

          if (state is ProfileError) {
            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                  title: const Text('Profile', style: AppText.title),
                  centerTitle: false),
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
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                title: const Text('Profile', style: AppText.title),
                centerTitle: false,
                backgroundColor:
                    _headerSolid ? AppColors.background : Colors.transparent,
                // A transparent bar would otherwise get light status-bar
                // icons over the light page.
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: AppColors.ink),
                    color: AppColors.surface,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    EditProfileScreen(currentUser: user)));
                      } else if (value == 'logout') {
                        _logout();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_outlined,
                                color: AppColors.ink, size: 20),
                            SizedBox(width: 8),
                            Text('แก้ไขโปรไฟล์')
                          ])),
                      const PopupMenuItem(
                          value: 'logout',
                          child: Row(children: [
                            Icon(Icons.logout_rounded,
                                color: AppColors.danger, size: 20),
                            SizedBox(width: 8),
                            Text('ออกจากระบบ',
                                style: TextStyle(color: AppColors.danger))
                          ])),
                    ],
                  ),
                ],
              ),
              body: Builder(
                // Builder: the header reads MediaQuery padding from inside
                // this Scaffold (status bar + transparent app bar).
                builder: (context) => CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          children: [
                            // padding.top = status bar + toolbar here
                            // (extendBodyBehindAppBar); the avatar starts
                            // just below the "Profile" title, slightly
                            // overlapping the bottom of the header.
                            SizedBox(
                                height: MediaQuery.paddingOf(context).top - 8),
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.hairline,
                                border:
                                    Border.all(color: Colors.white, width: 4),
                                image: profileImg.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(profileImg),
                                        fit: BoxFit.cover)
                                    : null,
                                boxShadow: AppShadows.lifted,
                              ),
                              child: profileImg.isEmpty
                                  ? const Icon(Icons.person,
                                      size: 64, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(name, style: AppText.display),
                                if (isEmailVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded,
                                      color: AppColors.primary, size: 22),
                                ]
                              ],
                            ),
                            if (!isEmailVerified)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: GestureDetector(
                                  onTap: isSendingEmail
                                      ? null
                                      : () => context
                                          .read<ProfileCubit>()
                                          .sendVerificationEmail(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.warningSoft,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.pill),
                                      border: Border.all(
                                          color: AppColors.warning
                                              .withOpacity(0.35)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        isSendingEmail
                                            ? SizedBox(
                                                width: 12,
                                                height: 12,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors
                                                            .orange.shade700))
                                            : Icon(Icons.warning_amber_rounded,
                                                size: 14,
                                                color: AppColors.warning),
                                        const SizedBox(width: 6),
                                        Text(
                                          isSendingEmail
                                              ? 'กำลังส่ง...'
                                              : 'คลิกที่นี่เพื่อส่งอีเมลยืนยันตัวตน',
                                          style: AppText.caption.copyWith(
                                              color: AppColors.warning,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: bio.trim().isEmpty
                                  ? Text('คุณยังไม่ได้เพิ่มไบโอ',
                                      textAlign: TextAlign.center,
                                      style: AppText.bodySecondary.copyWith(
                                          color: AppColors.inkTertiary))
                                  : Text(bio,
                                      textAlign: TextAlign.center,
                                      style: AppText.bodySecondary),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatPill(Icons.inventory_2_outlined,
                                    '${state.userListings.length} Items'),
                                const SizedBox(width: 8),
                                _buildStatPill(Icons.swap_horiz,
                                    '${state.tradeCount} Trades'),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
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
                    ),
                    switch (_selectedTab) {
                      'Active' => _buildActiveItemsGrid(context, state),
                      'Reviews' => _buildReviewsList(context, state),
                      _ => _buildTradeHistoryGrid(context, state),
                    },
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isHighlight ? null : AppColors.surface,
        gradient: isHighlight ? AppGradients.primary : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: isHighlight
            ? AppShadows.glow(AppColors.primary)
            : AppShadows.raised,
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 15, color: isHighlight ? Colors.white : AppColors.primary),
          const SizedBox(width: 5),
          Text(text,
              style: AppText.label.copyWith(
                  color: isHighlight ? Colors.white : AppColors.ink,
                  fontSize: 12.5)),
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

  Widget _buildActiveItemsGrid(BuildContext context, ProfileLoaded state) {
    // Previously showed every listing regardless of status — now that
    // "already traded" items have their own tab (_buildTradeHistoryGrid),
    // this one should actually only show what's still active.
    final listings =
        state.userListings.where((item) => item.status == 'active').toList();

    if (listings.isEmpty) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
              child: Text('คุณยังไม่มีสิ่งของที่กำลังลงประกาศอยู่',
                  style: TextStyle(color: AppColors.inkTertiary))));
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
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
                                child: Icon(Icons.image,
                                    color: AppColors.inkTertiary))
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: AppText.label.copyWith(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.toll_rounded,
                                    color: AppColors.primaryDark, size: 10),
                                const SizedBox(width: 4),
                                Text('${item.estimatedCoins}',
                                    style: TextStyle(
                                        color: AppColors.primaryDark,
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
          childCount: listings.length,
        ),
      ),
    );
  }

  Widget _buildTradeHistoryGrid(BuildContext context, ProfileLoaded state) {
    // "Not active" covers both an in-progress handover (locked mid-trade)
    // and a fully completed one — either way, the listing is no longer
    // something you could offer on.
    final listings =
        state.userListings.where((item) => item.status != 'active').toList();

    if (listings.isEmpty) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
              child: Text('คุณยังไม่มีประวัติการแลกเปลี่ยน',
                  style: TextStyle(color: AppColors.inkTertiary))));
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = listings[index];
            final isCompleted = item.status == 'completed';
            final statusLabel = isCompleted ? 'แลกไปแล้ว' : 'กำลังแลกเปลี่ยน';

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
                                      // Greyed out so it visually reads as no
                                      // longer available, without needing a
                                      // separate "sold" placeholder image.
                                      colorFilter: ColorFilter.mode(
                                          Colors.black.withOpacity(0.35),
                                          BlendMode.darken))
                                  : null,
                            ),
                            child: item.thumbnailUrl.isEmpty
                                ? const Center(
                                    child: Icon(Icons.image,
                                        color: AppColors.inkTertiary))
                                : null,
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: isCompleted
                                      ? Colors.black.withOpacity(0.6)
                                      : AppColors.warning,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(statusLabel,
                                  style: const TextStyle(
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
                              style: AppText.label.copyWith(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.toll_rounded,
                                    color: AppColors.inkSecondary, size: 10),
                                const SizedBox(width: 4),
                                Text('${item.estimatedCoins}',
                                    style: TextStyle(
                                        color: AppColors.inkSecondary,
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
          childCount: listings.length,
        ),
      ),
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

  Widget _buildTradedItemBox(BuildContext context, Map<String, dynamic>? myItem,
      Map<String, dynamic>? theirItem) {
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
          Expanded(child: _buildItemSide(context, theirItem, 'ของคู่เทรด')),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.hairline)),
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
      return SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
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
          ));
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
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
                  if (myItem != null || theirItem != null)
                    _buildTradedItemBox(context, myItem, theirItem),
                ],
              ),
            );
          },
          childCount: reviews.length,
        ),
      ),
    );
  }
}
