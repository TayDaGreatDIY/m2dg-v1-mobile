class Challenge {
  final String id;
  final String creatorId;
  final String? opponentId;
  final String challengeType; // '1v1', '3pt', 'FT', 'team'
  final String courtId;
  final String status; // 'pending_approval', 'open', 'accepted', 'in_progress', 'completed'
  final double? wagerAmount;
  final bool hasWager;
  final bool creatorAgreedToScoring;
  final bool opponentAgreedToScoring;
  final String? scoringMethod; // 'self_ref', 'referee_requested'
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? scheduledStartTime;
  final bool creatorReady;
  final bool opponentReady;
  final bool refereeRequested;
  final String? assignedRefereeId;
  final double? prizeAmount;
  final String? description;

  Challenge({
    required this.id,
    required this.creatorId,
    this.opponentId,
    required this.challengeType,
    required this.courtId,
    required this.status,
    this.wagerAmount,
    required this.hasWager,
    required this.creatorAgreedToScoring,
    required this.opponentAgreedToScoring,
    this.scoringMethod,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.scheduledStartTime,
    this.creatorReady = false,
    this.opponentReady = false,
    this.refereeRequested = false,
    this.assignedRefereeId,
    this.prizeAmount,
    this.description,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      opponentId: json['opponent_id'] as String?,
      challengeType: json['challenge_type'] as String,
      courtId: json['court_id'] as String,
      status: json['status'] as String,
      wagerAmount: json['wager_amount'] != null
          ? double.tryParse(json['wager_amount'].toString())
          : null,
      hasWager: json['has_wager'] as bool? ?? false,
      creatorAgreedToScoring: json['creator_agreed_to_scoring'] as bool? ?? false,
      opponentAgreedToScoring: json['opponent_agreed_to_scoring'] as bool? ?? false,
      scoringMethod: json['scoring_method'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      scheduledStartTime: json['scheduled_start_time'] != null
          ? DateTime.parse(json['scheduled_start_time'] as String)
          : null,
      creatorReady: json['creator_ready'] as bool? ?? false,
      opponentReady: json['opponent_ready'] as bool? ?? false,
      refereeRequested: json['referee_requested'] as bool? ?? false,
      assignedRefereeId: json['assigned_referee_id'] as String?,
      prizeAmount: json['prize_amount'] != null
          ? double.tryParse(json['prize_amount'].toString())
          : null,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'creator_id': creatorId,
    'opponent_id': opponentId,
    'challenge_type': challengeType,
    'court_id': courtId,
    'status': status,
    'wager_amount': wagerAmount,
    'has_wager': hasWager,
    'creator_agreed_to_scoring': creatorAgreedToScoring,
    'opponent_agreed_to_scoring': opponentAgreedToScoring,
    'scoring_method': scoringMethod,
    'created_at': createdAt.toIso8601String(),
    'started_at': startedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'scheduled_start_time': scheduledStartTime?.toIso8601String(),
    'creator_ready': creatorReady,
    'opponent_ready': opponentReady,
    'referee_requested': refereeRequested,
    'assigned_referee_id': assignedRefereeId,
    'prize_amount': prizeAmount,
    'description': description,
  };
}
