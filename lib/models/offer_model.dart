import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String offerId;
  final String senderId;
  final String targetUserId;
  final String targetListingId;
  final String offeredListingId;
  final int coinOffset;
  final String status;
  final String? lastOfferBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OfferModel({
    required this.offerId,
    required this.senderId,
    required this.targetUserId,
    required this.targetListingId,
    required this.offeredListingId,
    required this.coinOffset,
    required this.status,
    this.lastOfferBy,
    this.createdAt,
    this.updatedAt,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json, String documentId) {
    return OfferModel(
      offerId: documentId,
      senderId: json['sender_id'] ?? '',
      targetUserId: json['target_user_id'] ?? '',
      targetListingId: json['target_listing_id'] ?? '',
      offeredListingId: json['offered_listing_id'] ?? '',
      coinOffset: json['coin_offset'] ?? 0,
      status: json['status'] ?? 'pending',
      lastOfferBy: json['last_offer_by'],
      createdAt: json['created_at'] != null 
          ? (json['created_at'] as Timestamp).toDate() 
          : null,
      updatedAt: json['updated_at'] != null 
          ? (json['updated_at'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'target_user_id': targetUserId,
      'target_listing_id': targetListingId,
      'offered_listing_id': offeredListingId,
      'coin_offset': coinOffset,
      'status': status,
      if (lastOfferBy != null) 'last_offer_by': lastOfferBy,
      'members': [senderId, targetUserId],
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  OfferModel copyWith({
    String? offerId,
    String? senderId,
    String? targetUserId,
    String? targetListingId,
    String? offeredListingId,
    int? coinOffset,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfferModel(
      offerId: offerId ?? this.offerId,
      senderId: senderId ?? this.senderId,
      targetUserId: targetUserId ?? this.targetUserId,
      targetListingId: targetListingId ?? this.targetListingId,
      offeredListingId: offeredListingId ?? this.offeredListingId,
      coinOffset: coinOffset ?? this.coinOffset,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
