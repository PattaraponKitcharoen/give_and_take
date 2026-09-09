import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String transactionId;
  final String offerId;
  final List<String> listings;
  final List<String> members;
  final int escrowCoins;
  final String status;
  final String cancelReason;
  final Map<String, dynamic> verificationCodes;
  final List<String> confirmedByUserIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TransactionModel({
    required this.transactionId,
    required this.offerId,
    required this.listings,
    required this.members,
    required this.escrowCoins,
    required this.status,
    required this.cancelReason,
    required this.verificationCodes,
    required this.confirmedByUserIds,
    this.createdAt,
    this.updatedAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json, String documentId) {
    return TransactionModel(
      transactionId: documentId,
      offerId: json['offer_id'] ?? '',
      listings: List<String>.from(json['listings'] ?? []),
      members: List<String>.from(json['members'] ?? []),
      escrowCoins: json['escrow_coins'] ?? 0,
      status: json['status'] ?? 'pending',
      cancelReason: json['cancel_reason'] ?? '',
      verificationCodes: Map<String, dynamic>.from(json['verification_codes'] ?? {}),
      confirmedByUserIds: List<String>.from(json['confirmed_by_user_ids'] ?? []),
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
      'offer_id': offerId,
      'listings': listings,
      'members': members,
      'escrow_coins': escrowCoins,
      'status': status,
      'cancel_reason': cancelReason,
      'verification_codes': verificationCodes,
      'confirmed_by_user_ids': confirmedByUserIds,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  TransactionModel copyWith({
    String? transactionId,
    String? offerId,
    List<String>? listings,
    List<String>? members,
    int? escrowCoins,
    String? status,
    String? cancelReason,
    Map<String, dynamic>? verificationCodes,
    List<String>? confirmedByUserIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      transactionId: transactionId ?? this.transactionId,
      offerId: offerId ?? this.offerId,
      listings: listings ?? this.listings,
      members: members ?? this.members,
      escrowCoins: escrowCoins ?? this.escrowCoins,
      status: status ?? this.status,
      cancelReason: cancelReason ?? this.cancelReason,
      verificationCodes: verificationCodes ?? this.verificationCodes,
      confirmedByUserIds: confirmedByUserIds ?? this.confirmedByUserIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
