class UserProfile {
  final String id;
  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? skillLevel;
  final String? preferredPosition;
  final String userRole; // 'athlete', 'referee', 'verified_scorer', 'parent'
  final bool orientationCompleted;

  UserProfile({
    required this.id,
    required this.userId,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.skillLevel,
    this.preferredPosition,
    this.userRole = 'athlete',
    this.orientationCompleted = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      skillLevel: json['skill_level'] as String?,
      preferredPosition: json['preferred_position'] as String?,
      userRole: json['user_role'] as String? ?? 'athlete',
      orientationCompleted: json['orientation_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'bio': bio,
        'skill_level': skillLevel,
        'preferred_position': preferredPosition,
        'user_role': userRole,
        'orientation_completed': orientationCompleted,
      };
}
