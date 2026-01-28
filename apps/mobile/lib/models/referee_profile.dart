class RefereeProfile {
  final String id;
  final String userId;
  final String displayName;
  final String? profilePictureUrl;
  final int gamesRefereedTotal;
  final List<String>? certificates; // URLs to certificate images
  final String? bio;
  final int? yearsExperience;
  final String? availability; // e.g., "Weekends", "Evenings", "Anytime"
  final List<String>? socialMediaLinks; // URLs to social profiles
  final double? averageRating;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RefereeProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.profilePictureUrl,
    this.gamesRefereedTotal = 0,
    this.certificates,
    this.bio,
    this.yearsExperience,
    this.availability,
    this.socialMediaLinks,
    this.averageRating,
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory RefereeProfile.fromJson(Map<String, dynamic> json) {
    return RefereeProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      profilePictureUrl: json['profile_picture_url'] as String?,
      gamesRefereedTotal: json['games_refereed_total'] as int? ?? 0,
      certificates: json['certificates'] != null
          ? List<String>.from(json['certificates'] as List)
          : null,
      bio: json['bio'] as String?,
      yearsExperience: json['years_experience'] as int?,
      availability: json['availability'] as String?,
      socialMediaLinks: json['social_media_links'] != null
          ? List<String>.from(json['social_media_links'] as List)
          : null,
      averageRating: json['average_rating'] != null
          ? double.tryParse(json['average_rating'].toString())
          : null,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'display_name': displayName,
    'profile_picture_url': profilePictureUrl,
    'games_refereed_total': gamesRefereedTotal,
    'certificates': certificates,
    'bio': bio,
    'years_experience': yearsExperience,
    'availability': availability,
    'social_media_links': socialMediaLinks,
    'average_rating': averageRating,
    'is_verified': isVerified,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
