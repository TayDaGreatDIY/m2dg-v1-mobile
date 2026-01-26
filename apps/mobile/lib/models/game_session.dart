class GameSession {
  final String id;
  final String courtId;
  final String challengeType;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? winnerTeam;
  final int teamAScore;
  final int teamBScore;

  GameSession({
    required this.id,
    required this.courtId,
    required this.challengeType,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.winnerTeam,
    this.teamAScore = 0,
    this.teamBScore = 0,
  });

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'] as String,
      courtId: json['court_id'] as String,
      challengeType: json['challenge_type'] as String,
      status: json['status'] as String? ?? 'active',
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
      winnerTeam: json['winner_team'] as String?,
      teamAScore: json['team_a_score'] as int? ?? 0,
      teamBScore: json['team_b_score'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'court_id': courtId,
        'challenge_type': challengeType,
        'status': status,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'winner_team': winnerTeam,
        'team_a_score': teamAScore,
        'team_b_score': teamBScore,
      };
}
