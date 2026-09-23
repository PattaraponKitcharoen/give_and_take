import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/listing_model.dart';

/// One entry of a listing's image list as handed to [ListingRepository]:
/// either a brand-new local file to upload ([NewListingImage]) or a photo
/// that's already in Storage and should be kept as-is ([ExistingListingImage]).
/// List order is preserved end-to-end, so index 0 stays the cover photo.
/// Both variants carry [isFromCamera] so the "Camera" badge survives an
/// upload (new photo) or a re-save (existing photo kept during an edit).
sealed class ListingImageInput {
  const ListingImageInput();
}

class NewListingImage extends ListingImageInput {
  final File file;
  final bool isFromCamera;
  const NewListingImage(this.file, {this.isFromCamera = false});
}

class ExistingListingImage extends ListingImageInput {
  final String url;
  final bool isFromCamera;
  const ExistingListingImage(this.url, {this.isFromCamera = false});
}

class ListingRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ListingRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Future<String> _uploadListingImage(File imageFile, String ownerId) async {
    final fileName =
        '${ownerId}_${DateTime.now().millisecondsSinceEpoch}_${imageFile.hashCode}.jpg';
    final ref = _storage.ref().child('listing_images/$fileName');
    final uploadTask = await ref.putFile(imageFile);
    return uploadTask.ref.getDownloadURL();
  }

  /// Uploads every [NewListingImage] and passes through every
  /// [ExistingListingImage]'s URL unchanged, pairing each with its
  /// [ListingImageInput.isFromCamera] flag, and resolves all of them in
  /// parallel while preserving the input order — Future.wait completes its
  /// result list in the same order as the futures it was given, regardless
  /// of which upload finishes first, so index 0 is guaranteed to stay the
  /// cover photo.
  Future<List<ListingImage>> _resolveImages(
      List<ListingImageInput> images, String ownerId) {
    final resolved = images.map((input) async {
      return switch (input) {
        NewListingImage(:final file, :final isFromCamera) => ListingImage(
            url: await _uploadListingImage(file, ownerId),
            isFromCamera: isFromCamera),
        ExistingListingImage(:final url, :final isFromCamera) =>
          ListingImage(url: url, isFromCamera: isFromCamera),
      };
    });
    return Future.wait(resolved);
  }

  Future<int> getActiveListingCount(String userId) async {
    final snap = await _firestore
        .collection('listings')
        .where('owner_id', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .count()
        .get();
    return snap.count ?? 0;
  }

  Stream<List<ListingModel>> getUserActiveListingsStream(String userId) {
    return _firestore
        .collection('listings')
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
    Query query =
        _firestore.collection('listings').where('owner_id', isEqualTo: uid);
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) =>
            ListingModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<void> createListing(ListingModel listing,
      {List<ListingImageInput> images = const []}) async {
    ListingModel listingToSave = listing;

    if (images.isNotEmpty) {
      final resolved = await _resolveImages(images, listing.ownerId);
      listingToSave = listing.copyWith(
        thumbnailUrl: resolved.first.url,
        images: resolved,
      );
    }

    await _firestore.collection('listings').add(listingToSave.toJson());
  }

  Future<List<ListingModel>> getUserActiveListings(String uid) async {
    final snapshot = await _firestore
        .collection('listings')
        .where('owner_id', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();
    return snapshot.docs
        .map((doc) => ListingModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  Stream<ListingModel?> getListingStream(String listingId) {
    return _firestore
        .collection('listings')
        .doc(listingId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return ListingModel.fromJson(snapshot.data()!, snapshot.id);
    });
  }

  /// [images], when provided, replaces the listing's photo set end-to-end
  /// (uploading any [NewListingImage]s and keeping any [ExistingListingImage]
  /// URLs, in order — index 0 becomes the new cover photo). Pass an empty
  /// list to clear all photos, or omit the parameter entirely to leave the
  /// listing's existing photos untouched.
  Future<void> updateListing(ListingModel listing,
      {List<ListingImageInput>? images}) async {
    ListingModel listingToSave = listing;

    if (images != null) {
      if (images.isEmpty) {
        listingToSave = listing.copyWith(thumbnailUrl: '', images: const []);
      } else {
        final resolved = await _resolveImages(images, listing.ownerId);
        listingToSave = listing.copyWith(
            thumbnailUrl: resolved.first.url, images: resolved);
      }
    }

    await _firestore
        .collection('listings')
        .doc(listing.listingId)
        .update(listingToSave.toJson());
  }

  Future<void> deleteListingAndRelatedData(String listingId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    List<QueryDocumentSnapshot> allOffers = [];

    try {
      final offeredQuery = await _firestore
          .collection('offers')
          .where('offerer_id', isEqualTo: uid)
          .where('offered_listing_id', isEqualTo: listingId)
          .get();
      allOffers.addAll(offeredQuery.docs);
    } catch (e) {
      debugPrint('Error fetching offered offers [Type]: $e');
    }

    try {
      final targetQuery = await _firestore
          .collection('offers')
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
        final roomQuery = await _firestore
            .collection('chat_rooms')
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
