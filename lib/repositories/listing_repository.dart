import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/listing_model.dart';

class ListingRepository {
  final FirebaseFirestore _firestore;

  ListingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<int> getActiveListingCount(String userId) async {
    final snap = await _firestore.collection('listings')
      .where('owner_id', isEqualTo: userId)
      .where('status', isEqualTo: 'active')
      .count()
      .get();
    return snap.count ?? 0;
  }

  Stream<List<ListingModel>> getUserActiveListingsStream(String userId) {
    return _firestore.collection('listings')
      .where('owner_id', isEqualTo: userId)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ListingModel.fromJson(doc.data(), doc.id))
          .toList());
  }

  Stream<List<ListingModel>> getActiveItemsStream() {
    return _firestore
        .collection('listings')
        .where('type', isEqualTo: 'item')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ListingModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<ListingModel>> getAllActiveListingsStream() {
    return _firestore
        .collection('listings')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ListingModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<ListingModel>> getUserListings(String uid, {String? status}) {
    Query query = _firestore.collection('listings').where('owner_id', isEqualTo: uid);
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => ListingModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<void> toggleLike(String listingId, String userId, bool isAlreadyLiked) async {
    final docRef = _firestore.collection('listings').doc(listingId);
    if (isAlreadyLiked) {
      await docRef.update({
        'liked_by': FieldValue.arrayRemove([userId])
      });
    } else {
      await docRef.update({
        'liked_by': FieldValue.arrayUnion([userId])
      });
    }
  }
  Future<void> createListing(ListingModel listing) async {
    await _firestore.collection('listings').add(listing.toJson());
  }

  Future<List<ListingModel>> getUserActiveListings(String uid) async {
    final snapshot = await _firestore.collection('listings')
      .where('owner_id', isEqualTo: uid)
      .where('status', isEqualTo: 'active')
      .get();
    return snapshot.docs.map((doc) => ListingModel.fromJson(doc.data(), doc.id)).toList();
  }

  Stream<ListingModel?> getListingStream(String listingId) {
    return _firestore.collection('listings').doc(listingId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return ListingModel.fromJson(snapshot.data()!, snapshot.id);
    });
  }

  Future<void> updateListing(ListingModel listing) async {
    await _firestore.collection('listings').doc(listing.listingId).update(listing.toJson());
  }

  Future<void> deleteListingAndRelatedData(String listingId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    List<QueryDocumentSnapshot> allOffers = [];

    try {
      final offeredQuery = await _firestore.collection('offers')
          .where('offerer_id', isEqualTo: uid)
          .where('offered_listing_id', isEqualTo: listingId)
          .get();
      allOffers.addAll(offeredQuery.docs);
    } catch (e) {
      debugPrint('Error fetching offered offers [Type]: $e');
    }

    try {
      final targetQuery = await _firestore.collection('offers')
          .where('receiver_id', isEqualTo: uid)
          .where('target_listing_id', isEqualTo: listingId)
          .get();
      allOffers.addAll(targetQuery.docs);
    } catch (e) {
      debugPrint('Error fetching target offers [Type]: $e');
    }

    for (var offerDoc in allOffers) {
      String offerId = offerDoc.id;
      
      try {
        final roomQuery = await _firestore.collection('chat_rooms')
            .where('participants', arrayContains: uid)
            .where('active_offer_id', isEqualTo: offerId)
            .get();
        
        for (var roomDoc in roomQuery.docs) {
          try {
            await roomDoc.reference.collection('messages').add({
              'sender_id': 'system',
              'content': 'สิ่งของในข้อเสนอนี้ถูกลบออกจากระบบแล้ว',
              'timestamp': FieldValue.serverTimestamp(),
              'type': 'system_cancel',
            });
            await roomDoc.reference.update({
              'last_message_text': 'สิ่งของในข้อเสนอนี้ถูกลบออกจากระบบแล้ว',
              'last_message_type': 'system_cancel',
              'updated_at': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            debugPrint('Error updating Chat Room Message [Type]: $e');
          }
        }
      } catch (e) {
         debugPrint('Error fetching/updating Chat Rooms [Type]: $e');
      }

      try {
        await offerDoc.reference.delete();
      } catch (e) {
        debugPrint('Error deleting Offer [Type]: $e');
      }
    }

    try {
      await _firestore.collection('listings').doc(listingId).delete();
    } catch (e) {
      debugPrint('Error deleting Listing [Type]: $e');
    }
  }
}
