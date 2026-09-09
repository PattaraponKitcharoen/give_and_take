import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<UserModel> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromJson(snapshot.data()!, snapshot.id);
      }
      throw Exception('User not found');
    });
  }

  Future<UserModel> getUser(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (snapshot.exists && snapshot.data() != null) {
      return UserModel.fromJson(snapshot.data()!, snapshot.id);
    }
    throw Exception('User not found');
  }

  Future<void> updateUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).update(user.toJson());
  }

  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toJson());
  }

  Future<int> getTradeCount(String userId) async {
    try {
      final sentSnap = await _firestore
          .collection('offers')
          .where('sender_id', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      final receivedSnap = await _firestore
          .collection('offers')
          .where('target_user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      return sentSnap.docs.length + receivedSnap.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getEnrichedReviews(String userId) async {
    try {
      final reviewSnap = await _firestore
          .collection('reviews')
          .where('target_id', isEqualTo: userId)
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
          final userDoc = await _firestore.collection('users').doc(reviewerId).get();
          if (userDoc.exists) {
            final uData = userDoc.data()!;
            name = uData['name'] ?? 'ผู้ใช้งาน';
            img = uData['profile_img_url'] ?? '';
          }
        }
        
        if (transactionId.isNotEmpty) {
          final txDoc = await _firestore.collection('transactions').doc(transactionId).get();
          if (txDoc.exists) {
            final offerId = txDoc.data()?['offer_id'];
            if (offerId != null && offerId.toString().isNotEmpty) {
              final offerDoc = await _firestore.collection('offers').doc(offerId).get();
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
                  final myDoc = await _firestore.collection('listings').doc(myItemId).get();
                  if (myDoc.exists) {
                    myItemData = myDoc.data();
                    myItemData!['listing_id'] = myDoc.id;
                  }
                }

                if (theirItemId.isNotEmpty) {
                  final theirDoc = await _firestore.collection('listings').doc(theirItemId).get();
                  if (theirDoc.exists) {
                    theirItemData = theirDoc.data();
                    theirItemData!['listing_id'] = theirDoc.id;
                  }
                }
              }
            }
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

  Future<void> updateUserLocation(String uid, double lat, double lng, String district, String province) async {
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
