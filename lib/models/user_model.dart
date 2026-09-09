import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String tel;
  final String bio;
  final String role;
  final String status;
  final String profileImgUrl;
  final double coinsBalance;
  final double rating;
  final Map<String, dynamic> location;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? faculty;
  final String? academicYear;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.tel,
    required this.bio,
    this.role = 'user',
    this.status = 'active',
    required this.profileImgUrl,
    required this.coinsBalance,
    this.rating = 0.0,
    this.location = const {},
    required this.isEmailVerified,
    required this.isPhoneVerified,
    this.createdAt,
    this.updatedAt,
    this.faculty,
    this.academicYear,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String documentId) {
    return UserModel(
      uid: documentId,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      tel: json['tel'] ?? '',
      bio: json['bio'] ?? '',
      role: json['role'] ?? 'user',
      status: json['status'] ?? 'active',
      profileImgUrl: json['profile_img_url'] ?? '',
      coinsBalance: (json['coins_balance'] ?? 0).toDouble(),
      rating: (json['rating'] ?? json['rating_scores'] ?? 0).toDouble(),
      location: json['location'] ?? {},
      isEmailVerified: json['is_email_verified'] ?? false,
      isPhoneVerified: json['is_phone_verified'] ?? false,
      createdAt: json['created_at'] != null 
          ? (json['created_at'] as Timestamp).toDate() 
          : null,
      updatedAt: json['updated_at'] != null 
          ? (json['updated_at'] as Timestamp).toDate() 
          : null,
      faculty: json['faculty'],
      academicYear: json['academic_year'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'tel': tel,
      'bio': bio,
      'role': role,
      'status': status,
      'profile_img_url': profileImgUrl,
      'coins_balance': coinsBalance,
      'rating': rating,
      'location': location,
      'is_email_verified': isEmailVerified,
      'is_phone_verified': isPhoneVerified,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
      if (faculty != null) 'faculty': faculty,
      if (academicYear != null) 'academic_year': academicYear,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? tel,
    String? bio,
    String? role,
    String? status,
    String? profileImgUrl,
    double? coinsBalance,
    double? rating,
    Map<String, dynamic>? location,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? faculty,
    String? academicYear,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      tel: tel ?? this.tel,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      status: status ?? this.status,
      profileImgUrl: profileImgUrl ?? this.profileImgUrl,
      coinsBalance: coinsBalance ?? this.coinsBalance,
      rating: rating ?? this.rating,
      location: location ?? this.location,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      faculty: faculty ?? this.faculty,
      academicYear: academicYear ?? this.academicYear,
    );
  }
}
