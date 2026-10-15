import 'package:cloud_firestore/cloud_firestore.dart';
import 'listing_model.dart';

/// Something a user wants (wants/{id}). The Cloud Function adds an
/// embedding to it; the app only ever reads/writes the text.
class WantModel {
  final String id;
  final String text;
  final DateTime? createdAt;

  const WantModel({required this.id, required this.text, this.createdAt});

  factory WantModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return WantModel(
      id: doc.id,
      text: d['text'] ?? '',
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
    );
  }
}

/// A two-way match (matches/{id}) seen from one user's side: my item that
/// they want, and their item that matches one of my wants.
class MatchModel {
  final String id;
  final String partnerId;
  final String myListingId;
  final String theirListingId;
  final String myWantText; // my want their item matched
  final String theirWantText; // their want my item matched
  final double score;
  final bool seen;
  final DateTime? createdAt;

  // Filled in by the cubit from the listings themselves.
  final ListingModel? myListing;
  final ListingModel? theirListing;

  const MatchModel({
    required this.id,
    required this.partnerId,
    required this.myListingId,
    required this.theirListingId,
    required this.myWantText,
    required this.theirWantText,
    required this.score,
    required this.seen,
    this.createdAt,
    this.myListing,
    this.theirListing,
  });

  /// Null when the doc has no side for [userId] (should not happen).
  static MatchModel? fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, String userId) {
    final d = doc.data() ?? const {};
    final sides = (d['sides'] as Map?)?.cast<String, dynamic>() ?? const {};
    final mine = (sides[userId] as Map?)?.cast<String, dynamic>();
    if (mine == null) return null;
    final partnerId = (d['members'] as List? ?? const [])
        .cast<String>()
        .firstWhere((m) => m != userId, orElse: () => '');
    final theirs = (sides[partnerId] as Map?)?.cast<String, dynamic>();
    return MatchModel(
      id: doc.id,
      partnerId: partnerId,
      myListingId: mine['give_listing_id'] ?? '',
      theirListingId: mine['get_listing_id'] ?? '',
      myWantText: mine['want_text'] ?? '',
      theirWantText: theirs?['want_text'] ?? '',
      score: (d['score'] as num? ?? 0).toDouble(),
      seen: (d['seen_by'] as List? ?? const []).contains(userId),
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
    );
  }

  MatchModel withListings(ListingModel? mine, ListingModel? theirs) =>
      MatchModel(
        id: id,
        partnerId: partnerId,
        myListingId: myListingId,
        theirListingId: theirListingId,
        myWantText: myWantText,
        theirWantText: theirWantText,
        score: score,
        seen: seen,
        createdAt: createdAt,
        myListing: mine,
        theirListing: theirs,
      );
}
