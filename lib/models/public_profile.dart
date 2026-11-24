/// What anyone signed in may see about a user: public_profiles/{uid},
/// mirrored from users/{uid} by the onUserWrittenSyncPublic Cloud Function.
/// Use it for everyone but yourself; users/{uid} (email, phone, coins...)
/// is readable only by its owner and admins.
class PublicProfile {
  final String uid;
  final String name;
  final String profileImgUrl;
  final String bio;
  final double rating;
  final int ratingCount;
  final bool isStudent;

  /// The account was deleted (name shows as "ผู้ใช้ที่ลบบัญชีแล้ว").
  final bool isDeleted;

  const PublicProfile({
    required this.uid,
    required this.name,
    this.profileImgUrl = '',
    this.bio = '',
    this.rating = 0,
    this.ratingCount = 0,
    this.isStudent = false,
    this.isDeleted = false,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json, String uid) =>
      PublicProfile(
        uid: uid,
        name: json['name'] as String? ?? '',
        profileImgUrl: json['profile_img_url'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        rating: (json['owner_rating_scores'] as num? ?? 0).toDouble(),
        ratingCount: (json['owner_rating_count'] as num? ?? 0).toInt(),
        isStudent: json['is_student'] == true,
        isDeleted: json['status'] == 'deleted',
      );
}
