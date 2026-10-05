import 'package:flutter/material.dart';
import '../models/listing_model.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../screens/item_detail_screen.dart';

/// The item card used by both the main feed grid (home_screen.dart) and the
/// student-only listings screen — pulled out once both needed the exact same
/// card so a future tweak doesn't have to be made twice.
class ListingGridCard extends StatelessWidget {
  final ListingModel item;
  final bool isWishlisted;
  final Future<void> Function(ListingModel item) onToggleWishlist;
  final Color accentColor;

  const ListingGridCard({
    super.key,
    required this.item,
    required this.isWishlisted,
    required this.onToggleWishlist,
    this.accentColor = const Color(0xFF008080),
  });

  Future<void> _handleToggleWishlist(BuildContext context) async {
    try {
      await onToggleWishlist(item);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกรายการโปรดไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
            backgroundColor: Colors.red,
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

    return InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ItemDetailScreen(listing: item)));
      },
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16))),
                    child: thumbnail.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            child: Image.network(thumbnail, fit: BoxFit.cover))
                        : const Center(
                            child: Icon(Icons.image,
                                size: 40, color: Colors.black12)),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.monetization_on,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text('$coins',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold))
                      ]),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _handleToggleWishlist(context),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: Icon(
                            isWishlisted
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: isWishlisted
                                ? Colors.red
                                : Colors.grey.shade400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage: profileImg.isNotEmpty
                                        ? NetworkImage(profileImg)
                                        : null,
                                    child: profileImg.isEmpty
                                        ? const Icon(Icons.person,
                                            size: 10, color: Colors.white)
                                        : null);
                              },
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(ownerName,
                                    maxLines: 1,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700),
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      Row(children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                            ratingScore > 0
                                ? ratingScore.toStringAsFixed(1)
                                : 'New',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800))
                      ]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.swap_horiz, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Swap',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12))
                        ]),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
