import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  UserRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Uploads a (already-cropped) profile photo to Storage and returns its
  /// download URL. Does not touch Firestore — callers persist the URL via
  /// [updateUser] themselves, same two-step pattern as listing images.
  Future<String> uploadProfileImage(File imageFile, String uid) async {
    final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('profile_images/$fileName');
    final uploadTask = await ref.putFile(imageFile);
    return uploadTask.ref.getDownloadURL();
  }

  Stream<UserModel> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromJson(snapshot.data()!, snapshot.id);
      }
      throw Exception('User not found');
    });
  }

  // Not denormalized onto listings (unlike ownerName/ownerProfileImg) — a
  // listing's owner can become a verified student well after posting, and
  // fanning that write out to every one of their existing listings just to
  // support this one filter isn't worth the extra write complexity. Screens
  // that need "listings from student owners" combine this with the active
  // listings stream client-side instead (see StudentListingsCubit).
  Stream<Set<String>> getStudentUserIdsStream() {
    return _firestore
        .collection('users')
        .where('is_student', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  Future<UserModel> getUser(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (snapshot.exists && snapshot.data() != null) {
      return UserModel.fromJson(snapshot.data()!, snapshot.id);
    }
    throw Exception('User not found');
  }

  // Only the fields a user edits about themselves. This used to write
  // user.toJson() wholesale, which also carried coins_balance, status, role
  // and wishlist from whatever (possibly stale) UserModel the screen was
  // opened with — saving a profile could roll the coin balance back to its
  // value from before a trade that completed in the meantime. Those fields
  // are server-owned and the security rules now reject client writes to them.
  static const _profileFields = [
    'name',
    'tel',
    'bio',
    'profile_img_url',
    'faculty',
    'academic_year',
    'is_student',
  ];

  Future<void> updateUser(UserModel user) async {
    final json = user.toJson();
    await _firestore.collection('users').doc(user.uid).update({
      for (final field in _profileFields)
        if (json.containsKey(field)) field: json[field],
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Adds or removes [listingId] from [uid]'s `wishlist` array, depending
  /// on [isCurrentlyWishlisted] (the state before this call).
  Future<void> toggleWishlist(
      String uid, String listingId, bool isCurrentlyWishlisted) async {
    final docRef = _firestore.collection('users').doc(uid);
    if (isCurrentlyWishlisted) {
      await docRef.update({
        'wishlist': FieldValue.arrayRemove([listingId])
      });
    } else {
      await docRef.update({
        'wishlist': FieldValue.arrayUnion([listingId])
      });
    }
  }

  Future<void> createUser(UserModel user) async {
    final payload = user.toJson();
    // Ensure the initial payload explicitly includes these newly added fields
    payload['is_student'] = false;
    payload['faculty'] = "";
    payload['academic_year'] = "";

    await _firestore.collection('users').doc(user.uid).set(payload);
  }

  Future<int> getTradeCount(String userId) async {
    // Counted from the user's own listings rather than from offers: every
    // completed deal flips exactly one listing of each party to 'completed',
    // and listings are readable by any signed-in user — offers (and
    // transactions) are readable only by the two parties, so the old
    // offers-based count silently came back as 0 for anyone viewing someone
    // else's profile.
    try {
      final snap = await _firestore
          .collection('listings')
          .where('owner_id', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getEnrichedReviews(String userId) async {
    try {
      final reviewSnap = await _firestore
          .collection('reviews')
          .where('reviewee_id', isEqualTo: userId)
          .get();

      final docs = reviewSnap.docs;
      docs.sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();
        Timestamp timeA = dataA['created_at'] ?? Timestamp.now();
        Timestamp timeB = dataB['created_at'] ?? Timestamp.now();
        return timeB.compareTo(timeA);
      });

      List<Map<String, dynamic>> results = [];

      for (var doc in docs) {
        final data = doc.data();
        final String reviewerId = data['reviewer_id'] ?? '';
        final String transactionId = data['transaction_id'] ?? '';

        String name = 'ผู้ใช้งาน';
        String img = '';
        Map<String, dynamic>? myItemData;
        Map<String, dynamic>? theirItemData;

        if (reviewerId.isNotEmpty) {
          final userDoc =
              await _firestore.collection('users').doc(reviewerId).get();
          if (userDoc.exists) {
            final uData = userDoc.data()!;
            name = uData['name'] ?? 'ผู้ใช้งาน';
            img = uData['profile_img_url'] ?? '';
          }
        }

        // Reviews written by submitTradeReview (and older ones backfilled)
        // carry a snapshot of both traded items, so anyone can see them.
        final revieweeItem = data['reviewee_item'];
        final reviewerItem = data['reviewer_item'];
        if (revieweeItem is Map || reviewerItem is Map) {
          // On a profile, the reviewee is the profile owner ("my" item).
          myItemData = revieweeItem is Map
              ? Map<String, dynamic>.from(revieweeItem)
              : null;
          theirItemData = reviewerItem is Map
              ? Map<String, dynamic>.from(reviewerItem)
              : null;
        }
        // Fallback for reviews without the snapshot: the deal's
        // transaction/offer, which only the two parties may read. Anyone else
        // still gets the review (name, stars, comment) — just without the
        // item thumbnails — instead of the whole list failing on the first
        // unreadable deal.
        else if (transactionId.isNotEmpty) {
          try {
            final txDoc = await _firestore
                .collection('transactions')
                .doc(transactionId)
                .get();
            if (txDoc.exists) {
              final offerId = txDoc.data()?['offer_id'];
              if (offerId != null && offerId.toString().isNotEmpty) {
                final offerDoc =
                    await _firestore.collection('offers').doc(offerId).get();
                if (offerDoc.exists) {
                  final offerData = offerDoc.data()!;
                  String myItemId = '';
                  String theirItemId = '';

                  if (offerData['target_user_id'] == userId) {
                    myItemId = offerData['target_listing_id'] ?? '';
                    theirItemId = offerData['offered_listing_id'] ?? '';
                  } else {
                    myItemId = offerData['offered_listing_id'] ?? '';
                    theirItemId = offerData['target_listing_id'] ?? '';
                  }

                  if (myItemId.isNotEmpty) {
                    final myDoc = await _firestore
                        .collection('listings')
                        .doc(myItemId)
                        .get();
                    if (myDoc.exists) {
                      myItemData = myDoc.data();
                      myItemData!['listing_id'] = myDoc.id;
                    }
                  }

                  if (theirItemId.isNotEmpty) {
                    final theirDoc = await _firestore
                        .collection('listings')
                        .doc(theirItemId)
                        .get();
                    if (theirDoc.exists) {
                      theirItemData = theirDoc.data();
                      theirItemData!['listing_id'] = theirDoc.id;
                    }
                  }
                }
              }
            }
          } catch (_) {
            myItemData = null;
            theirItemData = null;
          }
        }

        results.add({
          'review': data,
          'name': name,
          'img': img,
          'myItem': myItemData,
          'theirItem': theirItemData,
        });
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  Future<void> updateUserLocation(String uid, double lat, double lng,
      String district, String province) async {
    await _firestore.collection('users').doc(uid).set({
      'location': {
        'latitude': lat,
        'longitude': lng,
        'district': district,
        'province': province,
        'display_name': '$district, $province',
      },
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
