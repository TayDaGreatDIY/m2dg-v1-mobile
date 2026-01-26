class UserLevel {
  final String userId;
  final String level; // 'rookie', 'intermediate', 'advanced', 'pro'
  final int xp;
  final int wins;
  final int losses;
  final DateTime updatedAt;

  UserLevel({
    required this.userId,
    required this.level,
    required this.xp,
    required this.wins,
    required this.losses,
    required this.updatedAt,
  });

  factory UserLevel.fromJson(Map<String, dynamic> json) {
    return UserLevel(
      userId: json['user_id'] as String,
      level: json['level'] as String? ?? 'rookie',
      xp: json['xp'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'level': level,
    'xp': xp,
    'wins': wins,
    'losses': losses,
    'updated_at': updatedAt.toIso8601String(),
  };

  bool get isRookie => level == 'rookie';
  bool get canCreateWager => !isRookie;

  String get displayLevel {
    return switch (level) {
      'rookie' => '🌱 Rookie',
      'intermediate' => '⭐ Intermediate',
      'advanced' => '🔥 Advanced',
      'pro' => '👑 Pro',
      _ => 'Unknown',
    };
  }
}
