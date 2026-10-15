import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/report_repository.dart';
import '../widgets/report_sheet.dart';
import '../cubits/location/location_cubit.dart';
import '../models/place_location.dart';
import '../models/listing_model.dart';
import '../models/offer_model.dart';
import '../models/user_model.dart';
import '../repositories/listing_repository.dart';
import '../repositories/offer_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../cubits/offer/offer_cubit.dart';
import '../cubits/offer/offer_state.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';
import '../widgets/email_verification_dialog.dart';
import '../widgets/ui/glass.dart';
import '../theme/app_theme.dart';

/// [BouncingScrollPhysics] that hard-caps how far the user can pull down
/// past the top, while leaving the bottom bounce completely normal.
class CappedTopBouncingScrollPhysics extends BouncingScrollPhysics {
  final double maxTopOverscroll;

  const CappedTopBouncingScrollPhysics({
    this.maxTopOverscroll = 60.0,
    super.parent,
  });

  @override
  CappedTopBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CappedTopBouncingScrollPhysics(
      maxTopOverscroll: maxTopOverscroll,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Apply a hard cap only when overscrolling at the top.
    if (position.pixels <= 0 && offset > 0) {
      if (position.pixels < -maxTopOverscroll) {
        return 0.0; // Stop allowing downward stretch beyond the limit.
      }
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }
}

class ItemDetailScreen extends StatefulWidget {
  final ListingModel listing;
  // Opened from a match: the offer sheet starts with this item of mine
  // selected (the one the other side wants) instead of my first item.
  final String? preselectedOfferListingId;

  const ItemDetailScreen(
      {super.key, required this.listing, this.preselectedOfferListingId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  // Optimistic override for the wishlist heart: set on tap so it flips
  // instantly instead of waiting on the user-doc stream's round-trip, then
  // cleared once that stream confirms it (or reverted on a failed write).
  bool? _optimisticWishlisted;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;

    // 🟢 แก้รหัสสีให้ตรงกับหน้า Add Item (0xFF008080)
    const Color tealColor = AppColors.primary;
    const Color lightTeal = AppColors.primarySoft;
    const Color coinGreen = AppColors.primary;

    final String listingId = listing.listingId;
    final String title = listing.title;
    final String description = listing.description;
    final String category = listing.category;
    final int coins = listing.estimatedCoins;

    final String condition =
        listing.condition.isEmpty ? 'ไม่ระบุสภาพ' : listing.condition;
    final String ownerId = listing.ownerId;
    final String thumbnail = listing.thumbnailUrl;

    // Unified gallery source: the new per-image metadata list, falling back
    // to the legacy single thumbnailUrl for listings saved before it existed
    // (no camera metadata available for that fallback case).
    final List<ListingImage> galleryImages = listing.images.isNotEmpty
        ? listing.images
        : (thumbnail.isNotEmpty
            ? [ListingImage(url: thumbnail)]
            : const <ListingImage>[]);
    final int imageCount = galleryImages.length;
    final int safeIndex =
        imageCount == 0 ? 0 : _currentImageIndex.clamp(0, imageCount - 1);
    final bool currentIsFromCamera =
        imageCount > 0 && galleryImages[safeIndex].isFromCamera;

    // 🟢 แก้ไขการแสดงเวลาให้เป็นภาษาไทย
    String listedText = 'โพสต์เมื่อไม่นานมานี้';
    if (listing.createdAt != null) {
      final int days = DateTime.now().difference(listing.createdAt!).inDays;
      if (days == 0) {
        listedText = 'โพสต์วันนี้';
      } else {
        listedText = 'โพสต์เมื่อ $days วันที่แล้ว';
      }
    }

    // A minimal, zero-height AppBar occupies the status bar strip solidly
    // in teal (no extendBodyBehindAppBar, so the body — including the
    // image — is laid out starting right after it, not behind it).
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      // Root Stack: the gradient and Back button below are siblings of the
      // scroll view, not descendants of it, so they stay fixed at the top
      // of the body while everything inside the ScrollView scrolls past
      // them underneath.
      body: Stack(
        children: [
          // Absolute background behind the scroll viewport: a hard-stop
          // 50/50 split so top overscroll reveals teal and bottom
          // overscroll reveals white, matching the details section below.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.background, AppColors.surface],
                stops: const [0.5, 0.5],
              ),
            ),
            child: SingleChildScrollView(
              physics: const CappedTopBouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Solid base canvas behind the PageView: covers the
                        // frame-or-two gap while a lazily-built page has
                        // nothing painted yet, so fast swipes never flash
                        // the teal/white background through instead.
                        Container(
                          color: AppColors.hairline,
                          child: PageView.builder(
                            controller: _pageController,
                            // Stops exactly at the first/last image instead
                            // of bouncing past the edge and revealing
                            // whatever is behind the PageView.
                            physics: const ClampingScrollPhysics(),
                            itemCount: imageCount == 0 ? 1 : imageCount,
                            onPageChanged: (index) =>
                                setState(() => _currentImageIndex = index),
                            itemBuilder: (context, index) {
                              if (imageCount == 0) {
                                return Container(
                                  color: AppColors.hairline,
                                  child: const Icon(Icons.image,
                                      size: 80, color: Colors.black12),
                                );
                              }
                              return Image.network(
                                galleryImages[index].url,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: AppColors.hairline,
                                    child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: AppColors.hairline,
                                  child: const Icon(Icons.broken_image_outlined,
                                      size: 60, color: Colors.black12),
                                ),
                              );
                            },
                          ),
                        ),
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.4),
                                Colors.transparent,
                                Colors.black.withOpacity(0.4)
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            )),
                          ),
                        ),
                        if (currentIsFromCamera)
                          Positioned(
                            bottom: 40,
                            left: 16,
                            child: Glass(
                              tint: AppColors.ink,
                              opacity: 0.4,
                              blur: 12,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt,
                                      size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Camera',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        if (imageCount > 1)
                          Positioned(
                            bottom: 40,
                            right: 16,
                            child: Glass(
                              tint: AppColors.ink,
                              opacity: 0.4,
                              blur: 12,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Text('${safeIndex + 1}/$imageCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ),
                        if (imageCount > 1)
                          Positioned(
                            bottom: 48,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                imageCount,
                                (index) => _buildDot(index == safeIndex),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Rounded sheet pulled up over the bottom of the photo.
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(28)),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x1414171A),
                              blurRadius: 20,
                              offset: Offset(0, -6)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpace.page, 22, AppSpace.page, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildBadge(Icons.laptop_mac, category,
                                    lightTeal, tealColor),
                                _buildBadge(Icons.star, condition, lightTeal,
                                    tealColor),
                                if (listing.location != null)
                                  BlocBuilder<LocationCubit, LocationState>(
                                    builder: (context, loc) {
                                      final there = listing.location!;
                                      final here = loc.location;
                                      final parts = [
                                        if (here != null)
                                          PlaceLocation.formatDistance(
                                              there.distanceKmTo(here)),
                                        if (there.displayName.isNotEmpty)
                                          there.displayName,
                                      ];
                                      if (parts.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return _buildBadge(Icons.place_outlined,
                                          parts.join(' · '), lightTeal, tealColor);
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title,
                                          style: AppText.display
                                              .copyWith(fontSize: 24)),
                                      const SizedBox(height: 6),
                                      Text(listedText,
                                          style: AppText.caption
                                              .copyWith(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                          gradient: AppGradients.of(coinGreen),
                                          boxShadow: AppShadows.glow(coinGreen),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.pill)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.toll_rounded,
                                              color: Colors.white, size: 16),
                                          const SizedBox(width: 4),
                                          Text('$coins',
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Coin Value',
                                        style: AppText.caption
                                            .copyWith(fontSize: 11)),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildOwnerProfileCard(context, listing, tealColor),
                            const SizedBox(height: 24),
                            const Text('About This Item', style: AppText.title),
                            const SizedBox(height: 10),
                            Text(
                              description,
                              style: AppText.body.copyWith(
                                  color: AppColors.inkSecondary, height: 1.65),
                            ),
                            const SizedBox(height: 56),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Fixed overlay: sibling of the ScrollView above, so it never
          // scrolls — painted after it, so it's on top and tappable.
          Positioned(
            top: 8,
            left: 16,
            child: _buildFloatingIcon(
                Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
          ),
          // Report menu, only on other people's listings.
          if (listing.ownerId.isNotEmpty &&
              listing.ownerId != context.read<AuthRepository>().currentUser?.uid)
            Positioned(
              top: 8,
              right: 16,
              child: _buildFloatingIcon(Icons.more_horiz_rounded,
                  () => _showReportMenu(context, listing)),
            ),
        ],
      ),

      // 🟢 ดักจับกรณีที่แอปยังโหลด ID ไม่ทัน เพื่อไม่ให้ StreamBuilder พัง
      bottomNavigationBar: listingId.isEmpty
          ? const SizedBox.shrink()
          : StreamBuilder<ListingModel?>(
              stream:
                  context.read<ListingRepository>().getListingStream(listingId),
              builder: (context, snapshot) {
                bool isActive = false;

                final currentUser = context.read<AuthRepository>().currentUser;
                final currentUserId = currentUser?.uid ?? '';

                if (snapshot.hasData && snapshot.data != null) {
                  final latestData = snapshot.data!;
                  if (latestData.status == 'active') {
                    isActive = true;
                  }
                }

                // The wishlist now lives on the user doc, not the listing,
                // so a second stream (scoped to the signed-in user) drives
                // the heart instead of `latestData.likedBy`.
                return StreamBuilder<UserModel>(
                  stream: currentUserId.isEmpty
                      ? const Stream<UserModel>.empty()
                      : context
                          .read<UserRepository>()
                          .getUserStream(currentUserId),
                  builder: (context, userSnapshot) {
                    final actualIsWishlisted =
                        userSnapshot.data?.wishlist.contains(listingId) ??
                            false;
                    final isLiked = _optimisticWishlisted ?? actualIsWishlisted;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -5))
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              Container(
                                height: 52,
                                width: 52,
                                decoration: BoxDecoration(
                                  color: isLiked
                                      ? AppColors.dangerSoft
                                      : AppColors.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                      color: isLiked
                                          ? AppColors.danger.withOpacity(0.25)
                                          : AppColors.hairline),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isLiked
                                        ? AppColors.danger
                                        : AppColors.ink,
                                  ),
                                  onPressed: () async {
                                    if (currentUserId.isEmpty) return;

                                    final wasLiked = isLiked;
                                    setState(() =>
                                        _optimisticWishlisted = !wasLiked);

                                    try {
                                      await context
                                          .read<UserRepository>()
                                          .toggleWishlist(currentUserId,
                                              listingId, wasLiked);
                                      if (mounted) {
                                        setState(
                                            () => _optimisticWishlisted = null);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() =>
                                            _optimisticWishlisted = wasLiked);
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'บันทึกรายการโปรดไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
                                            backgroundColor: AppColors.danger,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                // 🟢 เพิ่ม Container ห่อปุ่มไว้เพื่อทำเอฟเฟกต์เงาแบบเดียวกับหน้า Add Item
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    gradient: isActive
                                        ? AppGradients.of(tealColor)
                                        : null,
                                    boxShadow: isActive
                                        ? AppShadows.glow(tealColor)
                                        : [],
                                  ),
                                  child: ElevatedButton(
                                      onPressed: isActive
                                          ? () async {
                                              bool isVerified = await context
                                                  .read<AuthRepository>()
                                                  .isEmailVerified();
                                              if (!isVerified) {
                                                if (context.mounted)
                                                  showEmailVerificationDialog(
                                                    context,
                                                    message:
                                                        'คุณต้องยืนยันอีเมลก่อนจึงจะสามารถยื่นข้อเสนอได้ กรุณาตรวจสอบกล่องจดหมายของคุณ',
                                                    themeColor: tealColor,
                                                  );
                                                return;
                                              }

                                              if (currentUserId.isEmpty) return;

                                              if (currentUserId == ownerId) {
                                                if (context.mounted) {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          16)),
                                                      title: const Text(
                                                          'แจ้งเตือน',
                                                          style: TextStyle(
                                                              color: tealColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                      content: const Text(
                                                          'คุณไม่สามารถยื่นข้อเสนอให้กับสิ่งของของตัวเองได้ครับ'),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context),
                                                            child: const Text(
                                                                'เข้าใจแล้ว',
                                                                style: TextStyle(
                                                                    color:
                                                                        tealColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold)))
                                                      ],
                                                    ),
                                                  );
                                                }
                                                return;
                                              }
                                              if (context.mounted)
                                                _showOfferBottomSheet(
                                                    context,
                                                    tealColor,
                                                    currentUserId,
                                                    listing);
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        disabledBackgroundColor:
                                            AppColors.hairline,
                                        minimumSize:
                                            const Size(double.infinity, 54),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                AppRadius.md)),
                                        elevation:
                                            0, // ปิด elevation เดิมทิ้ง เพราะเราใช้ BoxShadow จาก Container แทนแล้ว
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.swap_horiz_rounded,
                                              color: isActive
                                                  ? Colors.white
                                                  : AppColors.inkTertiary),
                                          const SizedBox(width: 8),
                                          Text(
                                              isActive
                                                  ? 'Make an Offer'
                                                  : 'Item Unavailable',
                                              style: AppText.subtitle.copyWith(
                                                  color: isActive
                                                      ? Colors.white
                                                      : AppColors.inkTertiary)),
                                        ],
                                      )),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
    );
  }

  void _showReportMenu(BuildContext context, ListingModel listing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.danger),
                title: const Text('รายงานประกาศนี้'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showReportSheet(context,
                      type: ReportTarget.listing, targetId: listing.listingId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_off_outlined,
                    color: AppColors.danger),
                title: const Text('รายงานผู้ลงประกาศ'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showReportSheet(context,
                      type: ReportTarget.user, targetId: listing.ownerId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Glass(
        opacity: 0.6,
        blur: 16,
        shadows: AppShadows.raised,
        padding: const EdgeInsets.all(11),
        child: Icon(icon, color: AppColors.ink, size: 18),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white54,
          borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _buildBadge(
      IconData icon, String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(text,
              style: AppText.caption.copyWith(
                  color: textColor, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildOwnerProfileCard(
      BuildContext context, ListingModel listing, Color tealColor) {
    if (listing.ownerId.isEmpty) return const SizedBox();

    String ownerName =
        listing.ownerName.trim().isEmpty ? 'ผู้ใช้งาน' : listing.ownerName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline.withOpacity(0.6)),
        boxShadow: AppShadows.raised,
      ),
      child: Column(
        children: [
          StreamBuilder<UserModel>(
            stream:
                context.read<UserRepository>().getUserStream(listing.ownerId),
            builder: (context, ownerSnapshot) {
              // Falls back to the listing's own (possibly stale, snapshotted
              // at creation time) owner_profile_img / owner_rating_scores
              // until the live user doc loads, so this reflects the owner's
              // current profile picture and rating rather than the ones they
              // had when they posted the listing.
              final profileImg =
                  ownerSnapshot.data?.profileImgUrl ?? listing.ownerProfileImg;
              final ratingScore =
                  ownerSnapshot.data?.rating ?? listing.ownerRatingScores;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      shape: BoxShape.circle,
                      image: profileImg.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(profileImg),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: profileImg.isEmpty
                        ? const Icon(Icons.person, color: AppColors.inkTertiary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ownerName,
                            style: AppText.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        FutureBuilder<int>(
                            future: context
                                .read<OfferRepository>()
                                .getSuccessfulTradesCount(listing.ownerId),
                            builder: (context, tradeSnap) {
                              int tradeCount = tradeSnap.data ?? 0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$tradeCount successful trades',
                                      style: TextStyle(
                                          color: AppColors.inkTertiary,
                                          fontSize: 11,
                                          height: 1.2)),
                                ],
                              );
                            }),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.gold, size: 15),
                        const SizedBox(width: 4),
                        Text(
                            ratingScore > 0
                                ? ratingScore.toStringAsFixed(1)
                                : 'New',
                            style: AppText.label
                                .copyWith(color: AppColors.ink, fontSize: 13)),
                      ],
                    ),
                  )
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          UserProfileScreen(userId: listing.ownerId))),
              icon: const Icon(Icons.person_outline_rounded,
                  size: 17, color: AppColors.ink),
              label: Text('View Profile',
                  style: AppText.label.copyWith(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: AppColors.surfaceMuted,
                  side: BorderSide.none),
            ),
          )
        ],
      ),
    );
  }

  void _showOfferBottomSheet(BuildContext context, Color tealColor,
      String currentUserId, ListingModel listing) {
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
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.only(top: 80),
                    decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppRadius.xl)),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x2414171A),
                              blurRadius: 30,
                              offset: Offset(0, -8))
                        ]),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: AppColors.hairline,
                                    borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 24),
                        const Center(
                          child: Column(
                            children: [
                              Text('Make an Offer', style: AppText.display),
                              SizedBox(height: 4),
                              Text('Propose a fair trade for this item',
                                  style: AppText.bodySecondary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text('YOUR OFFER ITEM', style: AppText.overline),
                        const SizedBox(height: 12),
                        FutureBuilder<List<ListingModel>>(
                          future: context
                              .read<ListingRepository>()
                              .getUserActiveListings(currentUserId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const Center(
                                  child: CircularProgressIndicator());
                            var items = snapshot.data!;

                            if (items.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.lg)),
                                child: const Center(
                                    child: Text('คุณยังไม่มีสิ่งของให้แลก',
                                        style: TextStyle(
                                            color: AppColors.inkSecondary))),
                              );
                            }

                            if (selectedMyItemId == null && items.isNotEmpty) {
                              final initial = items.firstWhere(
                                  (item) =>
                                      item.listingId ==
                                      widget.preselectedOfferListingId,
                                  orElse: () => items.first);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                setModalState(() {
                                  selectedMyItemId = initial.listingId;
                                  selectedMyItemData = initial.toJson();
                                  selectedMyItemData!['listing_id'] =
                                      initial.listingId;
                                });
                              });
                            }

                            return GestureDetector(
                              onTap: () {},
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.lg),
                                    border: Border.all(
                                        color: AppColors.primary
                                            .withOpacity(0.35)),
                                    boxShadow: AppShadows.raised),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceMuted,
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.sm),
                                        image: selectedMyItemData?[
                                                        'thumbnail_url'] !=
                                                    null &&
                                                selectedMyItemData![
                                                        'thumbnail_url']
                                                    .isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                    selectedMyItemData![
                                                        'thumbnail_url']),
                                                fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: selectedMyItemData?[
                                                      'thumbnail_url'] ==
                                                  null ||
                                              selectedMyItemData![
                                                      'thumbnail_url']
                                                  .isEmpty
                                          ? const Icon(Icons.image,
                                              color: AppColors.inkTertiary)
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              selectedMyItemData?['title'] ??
                                                  'ไม่ระบุชื่อ',
                                              style: AppText.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                    color:
                                                        AppColors.primarySoft,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            AppRadius.pill)),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.toll_rounded,
                                                        size: 11,
                                                        color: AppColors
                                                            .primaryDark),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                        '~${selectedMyItemData?['estimated_coins'] ?? 0} Coins',
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .primaryDark)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child:
                                                    DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedMyItemId,
                                                  // Fill the remaining width so
                                                  // long titles ellipsize
                                                  // instead of overflowing.
                                                  isExpanded: true,
                                                  icon: const Icon(
                                                      Icons.keyboard_arrow_down,
                                                      size: 16),
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .inkSecondary),
                                                  isDense: true,
                                                  items: items
                                                      .map((item) =>
                                                          DropdownMenuItem(
                                                              value: item
                                                                  .listingId,
                                                              child: Text(
                                                                  item.title,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis)))
                                                      .toList(),
                                                  onChanged: (val) {
                                                    setModalState(() {
                                                      selectedMyItemId = val;
                                                      var selectedItem = items
                                                          .firstWhere((item) =>
                                                              item.listingId ==
                                                              val);
                                                      selectedMyItemData =
                                                          selectedItem.toJson();
                                                      selectedMyItemData![
                                                              'listing_id'] =
                                                          selectedItem
                                                              .listingId;
                                                    });
                                                  },
                                                ),
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
                        const Text('BALANCE THE TRADE',
                            style: AppText.overline),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setModalState(() => offerType = 'give'),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: offerType == 'give'
                                        ? AppGradients.of(AppColors.success)
                                        : null,
                                    color: offerType == 'give'
                                        ? null
                                        : AppColors.surfaceMuted,
                                    boxShadow: offerType == 'give'
                                        ? AppShadows.glow(AppColors.success)
                                        : null,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.arrow_upward,
                                          size: 18,
                                          color: offerType == 'give'
                                              ? Colors.white
                                              : AppColors.inkTertiary),
                                      const SizedBox(height: 4),
                                      Text('แถมเหรียญ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: offerType == 'give'
                                                  ? Colors.white
                                                  : AppColors.inkSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() {
                                  offerType = 'none';
                                  coinOffset = 0;
                                }),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: offerType == 'none'
                                        ? AppGradients.of(AppColors.primary)
                                        : null,
                                    color: offerType == 'none'
                                        ? null
                                        : AppColors.surfaceMuted,
                                    boxShadow: offerType == 'none'
                                        ? AppShadows.glow(AppColors.primary)
                                        : null,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.sync_alt,
                                          size: 18,
                                          color: offerType == 'none'
                                              ? Colors.white
                                              : AppColors.inkTertiary),
                                      const SizedBox(height: 4),
                                      Text('แลกของเท่านั้น',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: offerType == 'none'
                                                  ? Colors.white
                                                  : AppColors.inkSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setModalState(() => offerType = 'ask'),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: offerType == 'ask'
                                        ? AppGradients.of(AppColors.danger)
                                        : null,
                                    color: offerType == 'ask'
                                        ? null
                                        : AppColors.surfaceMuted,
                                    boxShadow: offerType == 'ask'
                                        ? AppShadows.glow(AppColors.danger)
                                        : null,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.arrow_downward,
                                          size: 18,
                                          color: offerType == 'ask'
                                              ? Colors.white
                                              : AppColors.inkTertiary),
                                      const SizedBox(height: 4),
                                      Text('ขอเหรียญเพิ่ม',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: offerType == 'ask'
                                                  ? Colors.white
                                                  : AppColors.inkSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (offerType != 'none')
                          Container(
                            decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg)),
                            child: TextField(
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink),
                              decoration: InputDecoration(
                                  hintText: '0',
                                  hintStyle:
                                      TextStyle(color: AppColors.inkTertiary),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 16),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 20, right: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          gradient:
                                              AppGradients.of(AppColors.gold),
                                          shape: BoxShape.circle,
                                          boxShadow:
                                              AppShadows.glow(AppColors.gold)),
                                      child: const Icon(Icons.toll_rounded,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                  suffixIcon: const Padding(
                                    padding:
                                        EdgeInsets.only(right: 20, top: 12),
                                    child: Text('coins',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.inkSecondary,
                                            fontWeight: FontWeight.bold)),
                                  )),
                              onChanged: (val) =>
                                  coinOffset = int.tryParse(val) ?? 0,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: Text(
                                    'ใช้สิ่งของแลกเปลี่ยนกันโดยตรง ไม่มีการใช้เหรียญ',
                                    style: TextStyle(
                                        color: AppColors.inkTertiary,
                                        fontSize: 13))),
                          ),
                        const SizedBox(height: 32),
                        BlocConsumer<OfferCubit, OfferState>(
                            listener: (context, state) {
                          if (state is OfferSuccess &&
                              state.message != 'ส่งข้อเสนอเรียบร้อยแล้ว' &&
                              state.message != 'ตกลงรับข้อเสนอเรียบร้อยแล้ว!') {
                            final navigator = Navigator.of(context);
                            if (context.mounted) {
                              navigator.pop();
                              navigator.push(MaterialPageRoute(
                                  builder: (context) =>
                                      ChatScreen(roomId: state.message)));
                            }
                          } else if (state is OfferError) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(state.error),
                                backgroundColor: AppColors.danger,
                                behavior: SnackBarBehavior.floating));
                          }
                        }, builder: (context, state) {
                          bool isSubmitting = state is OfferSubmitting;
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: AppShadows.glow(AppColors.primary),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      bool isVerified = await context
                                          .read<AuthRepository>()
                                          .isEmailVerified();
                                      if (!context.mounted) return;

                                      if (!isVerified) {
                                        showEmailVerificationDialog(
                                          context,
                                          message:
                                              'คุณต้องยืนยันอีเมลก่อนจึงจะสามารถยื่นข้อเสนอได้ กรุณาตรวจสอบกล่องจดหมายของคุณ',
                                          themeColor: tealColor,
                                        );
                                        return;
                                      }

                                      if (selectedMyItemId == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'กรุณาเลือกสิ่งของของคุณก่อนยื่นข้อเสนอครับ'),
                                                behavior:
                                                    SnackBarBehavior.floating));
                                        return;
                                      }

                                      String coinText = "";
                                      int finalCoinOffset = 0;

                                      if (offerType != 'none' &&
                                          coinOffset > 0) {
                                        finalCoinOffset = offerType == 'ask'
                                            ? -coinOffset
                                            : coinOffset;
                                        coinText =
                                            " และยินดี${offerType == 'ask' ? 'ขอรับเหรียญเพิ่ม' : 'แถมเหรียญให้'} $coinOffset Coins";
                                      }

                                      final offer = OfferModel(
                                        offerId: '',
                                        senderId: currentUserId,
                                        targetUserId: listing.ownerId,
                                        targetListingId: listing.listingId,
                                        offeredListingId: selectedMyItemId!,
                                        coinOffset: finalCoinOffset,
                                        status: 'pending',
                                      );

                                      context.read<OfferCubit>().submitNewOffer(
                                          offer: offer,
                                          targetItemData: listing.toJson(),
                                          offeredItemData: selectedMyItemData!,
                                          coinText: coinText);
                                    },
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.chat_bubble_rounded,
                                      color: Colors.white, size: 20),
                              label: Text(
                                  isSubmitting
                                      ? 'กำลังส่งข้อเสนอ...'
                                      : 'Confirm & Start Chat',
                                  style: AppText.subtitle
                                      .copyWith(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md))),
                            ),
                          );
                        }),
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
