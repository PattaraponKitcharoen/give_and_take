import 'package:flutter/material.dart';
import '../models/listing_model.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../screens/item_detail_screen.dart';
import '../theme/app_theme.dart';
import 'ui/glass.dart';

/// The item card used by both the main feed grid (home_screen.dart) and the
/// student-only listings screen — pulled out once both needed the exact same
/// card so a future tweak doesn't have to be made twice.
class ListingGridCard extends StatelessWidget {
  final ListingModel item;
  final bool isWishlisted;
  final Future<void> Function(ListingModel item) onToggleWishlist;
  final Color accentColor;
  // "~1.2 กม." from the viewer; shown on the photo when given.
  final String? distanceLabel;

  const ListingGridCard({
    super.key,
    required this.item,
    required this.isWishlisted,
    required this.onToggleWishlist,
    this.accentColor = AppColors.primary,
    this.distanceLabel,
  });

  Future<void> _handleToggleWishlist(BuildContext context) async {
    try {
      await onToggleWishlist(item);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกรายการโปรดไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = item.title;
    final coins = item.estimatedCoins;
    final thumbnail = item.thumbnailUrl;

    final ownerName =
        item.ownerName.trim().isEmpty ? 'ผู้ใช้งาน' : item.ownerName;
    final ratingScore = item.ownerRatingScores;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.raised,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ItemDetailScreen(listing: item)));
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.hairline.withOpacity(0.6)),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fills whatever height the grid cell leaves after the text
                // block, so the card never overflows on narrow/wide screens.
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: AppColors.surfaceMuted,
                          child: thumbnail.isNotEmpty
                              ? Image.network(thumbnail, fit: BoxFit.cover)
                              : const Center(
                                  child: Icon(Icons.image_outlined,
                                      size: 36, color: AppColors.inkTertiary)),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Glass(
                            tint: AppColors.ink,
                            opacity: 0.42,
                            blur: 12,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.toll_rounded,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text('$coins',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2))
                            ]),
                          ),
                        ),
                        if (distanceLabel != null)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Glass(
                              tint: AppColors.ink,
                              opacity: 0.42,
                              blur: 12,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 4),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.near_me_rounded,
                                        color: Colors.white, size: 11),
                                    const SizedBox(width: 3),
                                    Text(distanceLabel!,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                            ),
                          ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => _handleToggleWishlist(context),
                            child: Glass(
                              blur: 12,
                              opacity: 0.7,
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: Icon(
                                    isWishlisted
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 16,
                                    color: isWishlisted
                                        ? AppColors.danger
                                        : AppColors.ink),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppText.label.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                StreamBuilder<UserModel>(
                                  stream: context
                                      .read<UserRepository>()
                                      .getUserStream(item.ownerId),
                                  builder: (context, ownerSnapshot) {
                                    // Falls back to the listing's own (possibly
                                    // stale, snapshotted at creation time)
                                    // owner_profile_img until the live user doc
                                    // loads, so the avatar always reflects the
                                    // owner's current profile picture rather
                                    // than the one they had when they posted.
                                    final profileImg =
                                        ownerSnapshot.data?.profileImgUrl ??
                                            item.ownerProfileImg;
                                    return CircleAvatar(
                                        radius: 8,
                                        backgroundColor: AppColors.surfaceMuted,
                                        backgroundImage: profileImg.isNotEmpty
                                            ? NetworkImage(profileImg)
                                            : null,
                                        child: profileImg.isEmpty
                                            ? const Icon(Icons.person,
                                                size: 10,
                                                color: AppColors.inkTertiary)
                                            : null);
                                  },
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(ownerName,
                                        maxLines: 1,
                                        style: AppText.caption
                                            .copyWith(fontSize: 11),
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                          const Icon(Icons.star_rounded,
                              size: 13, color: AppColors.gold),
                          const SizedBox(width: 2),
                          Text(
                              ratingScore > 0
                                  ? ratingScore.toStringAsFixed(1)
                                  : 'New',
                              style: AppText.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 32,
                        decoration: BoxDecoration(
                            gradient: AppGradients.of(accentColor),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            boxShadow: [
                              BoxShadow(
                                  color: accentColor.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]),
                        child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.swap_horiz_rounded,
                                  color: Colors.white, size: 15),
                              SizedBox(width: 6),
                              Text('Swap',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                      letterSpacing: 0.2))
                            ]),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
