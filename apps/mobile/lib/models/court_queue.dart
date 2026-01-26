class CourtQueue {
  final String id;
  final String courtId;
  final String userId;
  final int teamSize;
  final List<String>? additionalPlayers;
  final String status; // waiting, playing, called_next, checked_in
  final int positionInQueue;
  final DateTime createdAt;
  final DateTime? calledAt;

  CourtQueue({
    required this.id,
    required this.courtId,
    required this.userId,
    required this.teamSize,
    this.additionalPlayers,
    required this.status,
    required this.positionInQueue,
    required this.createdAt,
    this.calledAt,
  });

  factory CourtQueue.fromJson(Map<String, dynamic> json) {
    return CourtQueue(
      id: json['id'] as String,
      courtId: json['court_id'] as String,
      userId: json['user_id'] as String,
      teamSize: json['team_size'] as int? ?? 1,
      additionalPlayers: json['additional_players'] != null
          ? List<String>.from(json['additional_players'] as List)
          : null,
      status: json['status'] as String? ?? 'waiting',
      positionInQueue: json['position_in_queue'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      calledAt: json['called_at'] != null
          ? DateTime.parse(json['called_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'court_id': courtId,
        'user_id': userId,
        'team_size': teamSize,
        'additional_players': additionalPlayers,
        'status': status,
        'position_in_queue': positionInQueue,
        'created_at': createdAt.toIso8601String(),
        'called_at': calledAt?.toIso8601String(),
      };
}
