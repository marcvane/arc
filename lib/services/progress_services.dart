import 'league_services.dart';
import '../model/season_model.dart';

class ProgressService {
  static int eloToNextLeague(int elo) {
    final league = LeagueService.getLeagueFromElo(elo);

    final nextLeagueElo = LeagueService.getNextLeagueElo(league);

    if (league == ArcLeague.icon) {
      return 0;
    }

    final difference = nextLeagueElo - elo;

    return difference < 0 ? 0 : difference;
  }

  static double progressToNextLeague(int elo) {
    final league = LeagueService.getLeagueFromElo(elo);

    if (league == ArcLeague.icon) {
      return 1.0;
    }

   int currentLeagueStart = 0;
int nextLeagueStart = 0;

    switch (league) {
      case ArcLeague.silver:
        currentLeagueStart = 0;
        nextLeagueStart = 1500;
        break;

      case ArcLeague.gold:
        currentLeagueStart = 1500;
        nextLeagueStart = 1800;
        break;

      case ArcLeague.platinum:
        currentLeagueStart = 1800;
        nextLeagueStart = 2100;
        break;

      case ArcLeague.diamond:
        currentLeagueStart = 2100;
        nextLeagueStart = 2400;
        break;

      case ArcLeague.icon:
  currentLeagueStart = 2400;
  nextLeagueStart = 2400;
  return 1.0;
    }

    return ((elo - currentLeagueStart) /
            (nextLeagueStart - currentLeagueStart))
        .clamp(0.0, 1.0);
  }
}
