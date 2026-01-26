class PlayerStats {
  final String id;
  final String userId;
  final int totalGames;
  final int totalWins;
  final int totalLosses;
  final int totalPointsScored;
  final int totalPointsAgainst;
  final String? favoriteCourtId;

  PlayerStats({
    required this.id,
    required this.userId,
    this.totalGames = 0,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.totalPointsScored = 0,
    this.totalPointsAgainst = 0,
    this.favoriteCourtId,
  });

  double get winRate => totalGames > 0 ? (totalWins / totalGames) * 100 : 0.0;
  int get pointDifferential => totalPointsScored - totalPointsAgainst;

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      totalGames: json['total_games'] as int? ?? 0,
      totalWins: json['total_wins'] as int? ?? 0,
      totalLosses: json['total_losses'] as int? ?? 0,
      totalPointsScored: json['total_points_scored'] as int? ?? 0,
      totalPointsAgainst: json['total_points_against'] as int? ?? 0,
      favoriteCourtId: json['favorite_court_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'total_games': totalGames,
        'total_wins': totalWins,
        'total_losses': totalLosses,
        'total_points_scored': totalPointsScored,
        'total_points_against': totalPointsAgainst,
        'favorite_court_id': favoriteCourtId,
      };
}
