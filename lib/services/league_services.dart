import '../model/season_model.dart';

class LeagueService {
  static ArcLeague getLeagueFromElo(int elo) {
    if (elo >= 2400) {
      return ArcLeague.icon;
    }

    if (elo >= 2100) {
      return ArcLeague.diamond;
    }

    if (elo >= 1800) {
      return ArcLeague.platinum;
    }

    if (elo >= 1500) {
      return ArcLeague.gold;
    }

    return ArcLeague.silver;
  }

  static String getLeagueName(ArcLeague league) {
    switch (league) {
      case ArcLeague.silver:
        return 'Argent';
      case ArcLeague.gold:
        return 'Or';
      case ArcLeague.platinum:
        return 'Platine';
      case ArcLeague.diamond:
        return 'Diamant';
      case ArcLeague.icon:
        return 'Icône';
    }
  }

  static int getNextLeagueElo(ArcLeague league) {
    switch (league) {
      case ArcLeague.silver:
        return 1500;
      case ArcLeague.gold:
        return 1800;
      case ArcLeague.platinum:
        return 2100;
      case ArcLeague.diamond:
        return 2400;
      case ArcLeague.icon:
        return 2400;
    }
  }
}
