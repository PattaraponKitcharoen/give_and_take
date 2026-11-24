import '../models/listing_model.dart';

/// Finds listings whose title, category or description contain every word
/// of [query] (case-insensitive; Thai has no spaces, so a Thai query is
/// usually one "word"). Runs on listings already loaded in the app, so
/// searching the description too costs no extra Firestore reads.
///
/// Best matches first: the whole query in the title, then every word in the
/// title, then in the category, then only in the description; newest first
/// within each group. [excludeOwnerId]'s own listings are left out.
List<ListingModel> searchListings(
  List<ListingModel> listings,
  String query, {
  String? excludeOwnerId,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final words = q.split(RegExp(r'\s+'));

  final ranked = <(int, ListingModel)>[];
  for (final item in listings) {
    if (excludeOwnerId != null && item.ownerId == excludeOwnerId) continue;
    final title = item.title.toLowerCase();
    final category = item.category.toLowerCase();
    final all = '$title\n$category\n${item.description.toLowerCase()}';
    if (!words.every(all.contains)) continue;

    final int rank;
    if (title.contains(q)) {
      rank = 0;
    } else if (words.every(title.contains)) {
      rank = 1;
    } else if (words.every('$title\n$category'.contains)) {
      rank = 2;
    } else {
      rank = 3;
    }
    ranked.add((rank, item));
  }

  ranked.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    if (byRank != 0) return byRank;
    final at = a.$2.createdAt, bt = b.$2.createdAt;
    if (at == null || bt == null) return 0;
    return bt.compareTo(at);
  });
  return [for (final r in ranked) r.$2];
}
