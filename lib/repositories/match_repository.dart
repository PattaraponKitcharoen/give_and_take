import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants/firebase_config.dart';
import '../models/listing_model.dart';
import '../models/match_model.dart';

/// Wants, two-way matches and the on/off switch for "แลกตามความต้องการ".
/// Matching itself runs in Cloud Functions (functions/matching.js).
class MatchRepository {
  static const int maxWants = 10; // same limit as the Cloud Function

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  MatchRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? appFunctions();

  Stream<List<WantModel>> wantsStream(String userId) {
    return _firestore
        .collection('wants')
        .where('owner_id', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final wants = snap.docs.map(WantModel.fromDoc).toList();
      // Newest first; a just-added want has no server time yet.
      wants.sort((a, b) => (b.createdAt ?? DateTime(9999))
          .compareTo(a.createdAt ?? DateTime(9999)));
      return wants;
    });
  }

  Future<void> addWant(String userId, String text) {
    return _firestore.collection('wants').add({
      'owner_id': userId,
      'text': text,
      'status': 'active',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteWant(String wantId) =>
      _firestore.collection('wants').doc(wantId).delete();

  Stream<List<MatchModel>> matchesStream(String userId) {
    return _firestore
        .collection('matches')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MatchModel.fromDoc(doc, userId))
            .whereType<MatchModel>()
            .toList());
  }

  Future<void> markSeen(Iterable<String> matchIds, String userId) async {
    final batch = _firestore.batch();
    for (final id in matchIds) {
      batch.update(_firestore.collection('matches').doc(id), {
        'seen_by': FieldValue.arrayUnion([userId]),
      });
    }
    await batch.commit();
  }

  /// Missing field = on.
  Stream<bool> matchEnabledStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['match_enabled'] != false);
  }

  Future<void> setMatchEnabled(String userId, bool enabled) {
    return _firestore
        .collection('users')
        .doc(userId)
        .update({'match_enabled': enabled});
  }

  Future<ListingModel?> getListing(String listingId) async {
    final doc = await _firestore.collection('listings').doc(listingId).get();
    if (!doc.exists) return null;
    return ListingModel.fromJson(doc.data()!, doc.id);
  }

  /// Asks the server to look again for the caller's wants. Allowed once an
  /// hour; returns how many minutes to wait when called sooner, else null.
  Future<int?> rescan() async {
    final result = await _functions.httpsCallable('rescanMatches').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['throttled'] == true) {
      return (data['retry_after_minutes'] as num?)?.toInt() ?? 60;
    }
    return null;
  }
}
