import 'season_model.dart';

class ArcUser {
  final String id;
  final String username;
  final int age;
  final String bio;
  final List<String> photoUrls;

  final int elo;
  final ArcLeague league;
  final int season;

  final List<int> eloHistory;

  const ArcUser({
    required this.id,
    required this.username,
    required this.age,
    required this.bio,
    required this.photoUrls,
    required this.elo,
    required this.league,
    required this.season,
    required this.eloHistory,
  });

  ArcUser copyWith({
    String? id,
    String? username,
    int? age,
    String? bio,
    List<String>? photoUrls,
    int? elo,
    ArcLeague? league,
    int? season,
    List<int>? eloHistory,
  }) {
    return ArcUser(
      id: id ?? this.id,
      username: username ?? this.username,
      age: age ?? this.age,
      bio: bio ?? this.bio,
      photoUrls: photoUrls ?? this.photoUrls,
      elo: elo ?? this.elo,
      league: league ?? this.league,
      season: season ?? this.season,
      eloHistory: eloHistory ?? this.eloHistory,
    );
  }
}
