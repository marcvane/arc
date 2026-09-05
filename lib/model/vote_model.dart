class ArcVote {
  final String id;

  final String voterId;

  final String profileAId;
  final String profileBId;

  final String winnerId;
  final String loserId;

  final int winnerEloBefore;
  final int winnerEloAfter;

  final int loserEloBefore;
  final int loserEloAfter;

  final DateTime createdAt;

  const ArcVote({
    required this.id,
    required this.voterId,
    required this.profileAId,
    required this.profileBId,
    required this.winnerId,
    required this.loserId,
    required this.winnerEloBefore,
    required this.winnerEloAfter,
    required this.loserEloBefore,
    required this.loserEloAfter,
    required this.createdAt,
  });
}
