import 'dart:math';
class Eloservices {
  static int calculateNewRating({
    required int playerRating,
    required int opponentRating,
    required bool won,
  }) {
    const int kFactor = 32;

    final double expectedScore =
        1 / (1 + pow(10, (opponentRating - playerRating) / 400));

    final double actualScore = won ? 1.0 : 0.0;

    return (playerRating +
            kFactor * (actualScore - expectedScore))
        .round();
  }
}
