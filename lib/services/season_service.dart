import '../model/season_model.dart';

class SeasonService {
  static int getResetElo({
    required int previousElo,
    required ArcLeague previousLeague,
  }) {
    switch (previousLeague) {
      case ArcLeague.silver:
        return 1000;

      case ArcLeague.gold:
        return 1050;

      case ArcLeague.platinum:
        return 1100;

      case ArcLeague.diamond:
        return 1150;

      case ArcLeague.icon:
        return 1200;
    }
  }
}