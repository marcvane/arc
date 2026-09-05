class DailyVoteService {
  static const int maxVotesPerDay = 20;

  static int remainingVotes({
    required int votesUsedToday,
  }) {
    final remaining = maxVotesPerDay - votesUsedToday;

    return remaining < 0 ? 0 : remaining;
  }

  static bool canVote({
    required int votesUsedToday,
  }) {
    return votesUsedToday < maxVotesPerDay;
  }

  static bool isSameDay(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static int getVotesUsedToday({
    required int storedVotesUsed,
    required DateTime? lastVoteDate,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    if (lastVoteDate == null) {
      return 0;
    }

    if (!isSameDay(lastVoteDate, currentTime)) {
      return 0;
    }

    return storedVotesUsed;
  }
}
