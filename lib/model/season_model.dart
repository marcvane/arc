enum ArcLeague {
  silver,
  gold,
  platinum,
  diamond,
  icon,
}
class ArcSeason {
  final int number;
  final DateTime startDate;
  final DateTime endDate;

  const ArcSeason({
    required this.number,
    required this.startDate,
    required this.endDate,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }
}
