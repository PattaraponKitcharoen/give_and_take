import 'package:cloud_firestore/cloud_firestore.dart';

/// One photo in a listing's [ListingModel.images] array: its Storage
/// download URL plus whether it was taken with the in-app camera (used to
/// show the "Camera" badge on the thumbnail).
class ListingImage {
  final String url;
  final bool isFromCamera;

  const ListingImage({required this.url, this.isFromCamera = false});

  /// Accepts either the current map format (`{'url': ..., 'isCamera': ...}`)
  /// or a bare string URL, so listings saved before this field existed
  /// (a plain `List<String>` in Firestore) still parse instead of crashing.
  factory ListingImage.fromMap(dynamic data) {
    if (data is String) {
      return ListingImage(url: data);
    }
    if (data is! Map) {
      // A malformed entry (e.g. null) must not crash ListingModel.fromJson
      // for the whole document — that would take down every stream reading
      // this listing, including the ones the wishlist heart depends on.
      return const ListingImage(url: '');
    }
    final map = Map<String, dynamic>.from(data);
    return ListingImage(
      url: map['url'] ?? '',
      isFromCamera: map['isCamera'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {'url': url, 'isCamera': isFromCamera};
}

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
  final List<ListingImage> images;
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
      ownerProfileImg:
          metadata?['owner_profile_img'] ?? json['owner_profile_img'] ?? '',
      ownerRatingScores: (metadata?['owner_rating_scores'] ??
              json['owner_rating_scores'] ??
              0.0)
          .toDouble(),
      title: metadata?['title'] ?? json['title'] ?? 'ไม่มีชื่อสินค้า',
      description: json['description'] ?? '',
      condition: metadata?['condition'] ?? json['condition'] ?? '',
      estimatedCoins: json['estimated_coins'] ?? 0,
      thumbnailUrl: metadata?['thumbnail_url'] ?? json['thumbnail_url'] ?? '',
      images: (json['images'] as List<dynamic>? ?? [])
          .map((e) => ListingImage.fromMap(e))
          .toList(),
      createdAt: json['created_at'] != null
          ? (json['created_at'] as Timestamp).toDate()
          : null,
      updatedAt: (metadata?['updated_at'] ?? json['updated_at']) != null
          ? ((metadata?['updated_at'] ?? json['updated_at']) as Timestamp)
              .toDate()
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
      'images': images.map((img) => img.toMap()).toList(),
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
    List<ListingImage>? images,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
