import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String reviewId;
  final String reviewerId;
  final String transactionId;
  final String revieweeId;
  final double rating;
  final String comment;
  final DateTime? createdAt;

  ReviewModel({
    required this.reviewId,
    required this.reviewerId,
    required this.transactionId,
    required this.revieweeId,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json, String documentId) {
    return ReviewModel(
      reviewId: documentId,
      reviewerId: json['reviewer_id'] ?? '',
      transactionId: json['transaction_id'] ?? '',
      revieweeId: json['reviewee_id'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] != null 
          ? (json['created_at'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewer_id': reviewerId,
      'transaction_id': transactionId,
      'reviewee_id': revieweeId,
      'rating': rating,
      'comment': comment,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
    };
  }

  ReviewModel copyWith({
    String? reviewId,
    String? reviewerId,
    String? transactionId,
    String? revieweeId,
    double? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return ReviewModel(
      reviewId: reviewId ?? this.reviewId,
      reviewerId: reviewerId ?? this.reviewerId,
      transactionId: transactionId ?? this.transactionId,
      revieweeId: revieweeId ?? this.revieweeId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
