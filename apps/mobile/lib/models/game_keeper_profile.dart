import 'package:intl/intl.dart';

class GameKeeperProfile {
  final String id;
  final String userId;
  final String displayName;
  final String? profilePictureUrl;
  final int gamesKeptTotal;
  final double averageAccuracy;
  final String? bio;
  final String? certificationDate;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  GameKeeperProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.profilePictureUrl,
    required this.gamesKeptTotal,
    required this.averageAccuracy,
    this.bio,
    this.certificationDate,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GameKeeperProfile.fromJson(Map<String, dynamic> json) {
    return GameKeeperProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      profilePictureUrl: json['profile_picture_url'] as String?,
      gamesKeptTotal: json['games_kept_total'] as int? ?? 0,
      averageAccuracy: (json['average_accuracy'] as num?)?.toDouble() ?? 0.0,
      bio: json['bio'] as String?,
      certificationDate: json['certification_date'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'display_name': displayName,
      'profile_picture_url': profilePictureUrl,
      'games_kept_total': gamesKeptTotal,
      'average_accuracy': averageAccuracy,
      'bio': bio,
      'certification_date': certificationDate,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
