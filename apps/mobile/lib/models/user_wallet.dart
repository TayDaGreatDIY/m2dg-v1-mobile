class UserWallet {
  final String id;
  final String userId;
  final double balance;
  final double totalWagered;
  final DateTime updatedAt;

  UserWallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.totalWagered,
    required this.updatedAt,
  });

  factory UserWallet.fromJson(Map<String, dynamic> json) {
    return UserWallet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      balance: double.tryParse(json['balance'].toString()) ?? 0.0,
      totalWagered: double.tryParse(json['total_wagered'].toString()) ?? 0.0,
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'balance': balance,
    'total_wagered': totalWagered,
    'updated_at': updatedAt.toIso8601String(),
  };

  bool canWager(double amount) => balance >= amount;
}
