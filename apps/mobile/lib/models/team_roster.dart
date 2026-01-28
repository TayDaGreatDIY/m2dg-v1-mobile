class TeamRoster {
  final String id;
  final String userId;
  final String teamName;
  final String gameType; // '5v5' or '3v3'
  final List<String> playerIds; // UUIDs of players
  final DateTime createdAt;
  final DateTime updatedAt;

  TeamRoster({
    required this.id,
    required this.userId,
    required this.teamName,
    required this.gameType,
    required this.playerIds,
    required this.createdAt,
    required this.updatedAt,
  });

  // Get required team size based on game type
  int get requiredSize => gameType == '5v5' ? 5 : 3;

  // Check if team is complete
  bool get isComplete => playerIds.length == requiredSize;

  // Check if team is missing players
  int get missingPlayers => requiredSize - playerIds.length;

  factory TeamRoster.fromJson(Map<String, dynamic> json) {
    return TeamRoster(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      teamName: json['team_name'] as String,
      gameType: json['game_type'] as String,
      playerIds: List<String>.from(json['player_ids'] as List? ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'team_name': teamName,
    'game_type': gameType,
    'player_ids': playerIds,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  TeamRoster copyWith({
    String? id,
    String? userId,
    String? teamName,
    String? gameType,
    List<String>? playerIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeamRoster(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      teamName: teamName ?? this.teamName,
      gameType: gameType ?? this.gameType,
      playerIds: playerIds ?? this.playerIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
