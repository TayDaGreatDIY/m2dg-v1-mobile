class RefereeAssignment {
  final String id;
  final String challengeId;
  final String refereeId;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;
  final DateTime? respondedAt;

  RefereeAssignment({
    required this.id,
    required this.challengeId,
    required this.refereeId,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory RefereeAssignment.fromJson(Map<String, dynamic> json) {
    return RefereeAssignment(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      refereeId: json['referee_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'challenge_id': challengeId,
    'referee_id': refereeId,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'responded_at': respondedAt?.toIso8601String(),
  };
}
