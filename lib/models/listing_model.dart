import 'package:cloud_firestore/cloud_firestore.dart';

class ListingModel {
  final String listingId;
  final String type;
  final String status;
  final String category;
  final String ownerId;
  final String ownerName;
  final String ownerProfileImg;
  final double ownerRatingScores;
  final String title;
  final String description;
  final String condition;
  final int estimatedCoins;
  final String thumbnailUrl;
  final List<String> images;
  final List<String> likedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ListingModel({
    required this.listingId,
    required this.type,
    required this.status,
    required this.category,
    required this.ownerId,
    required this.ownerName,
    required this.ownerProfileImg,
    required this.ownerRatingScores,
    required this.title,
    required this.description,
    required this.condition,
    required this.estimatedCoins,
    required this.thumbnailUrl,
    required this.images,
    required this.likedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory ListingModel.fromJson(Map<String, dynamic> json, String documentId) {
    final metadata = json['metadata'] as Map<String, dynamic>?;

    return ListingModel(
      listingId: documentId,
      type: metadata?['type'] ?? json['type'] ?? 'item',
      status: metadata?['status'] ?? json['status'] ?? 'draft',
      category: json['category'] ?? '',
      ownerId: metadata?['owner_id'] ?? json['owner_id'] ?? '',
      ownerName: metadata?['owner_name'] ?? json['owner_name'] ?? 'ผู้ใช้งาน',
      ownerProfileImg: metadata?['owner_profile_img'] ?? json['owner_profile_img'] ?? '',
      ownerRatingScores: (metadata?['owner_rating_scores'] ?? json['owner_rating_scores'] ?? 0.0).toDouble(),
      title: metadata?['title'] ?? json['title'] ?? 'ไม่มีชื่อสินค้า',
      description: json['description'] ?? '',
      condition: metadata?['condition'] ?? json['condition'] ?? '',
      estimatedCoins: json['estimated_coins'] ?? 0,
      thumbnailUrl: metadata?['thumbnail_url'] ?? json['thumbnail_url'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      likedBy: List<String>.from(json['liked_by'] ?? []),
      createdAt: json['created_at'] != null 
          ? (json['created_at'] as Timestamp).toDate() 
          : null,
      updatedAt: (metadata?['updated_at'] ?? json['updated_at']) != null 
          ? ((metadata?['updated_at'] ?? json['updated_at']) as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'status': status,
      'category': category,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_profile_img': ownerProfileImg,
      'owner_rating_scores': ownerRatingScores,
      'title': title,
      'description': description,
      'condition': condition,
      'estimated_coins': estimatedCoins,
      'thumbnail_url': thumbnailUrl,
      'images': images,
      'liked_by': likedBy,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  ListingModel copyWith({
    String? listingId,
    String? type,
    String? status,
    String? category,
    String? ownerId,
    String? ownerName,
    String? ownerProfileImg,
    double? ownerRatingScores,
    String? title,
    String? description,
    String? condition,
    int? estimatedCoins,
    String? thumbnailUrl,
    List<String>? images,
    List<String>? likedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ListingModel(
      listingId: listingId ?? this.listingId,
      type: type ?? this.type,
      status: status ?? this.status,
      category: category ?? this.category,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerProfileImg: ownerProfileImg ?? this.ownerProfileImg,
      ownerRatingScores: ownerRatingScores ?? this.ownerRatingScores,
      title: title ?? this.title,
      description: description ?? this.description,
      condition: condition ?? this.condition,
      estimatedCoins: estimatedCoins ?? this.estimatedCoins,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      images: images ?? this.images,
      likedBy: likedBy ?? this.likedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
