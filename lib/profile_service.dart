import 'package:supabase_flutter/supabase_flutter.dart';

import 'model/user_model.dart';
import 'services/league_services.dart';

class ProfileService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<ArcUser>> getProfiles() async {
    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      throw Exception('Utilisateur non connecté');
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .neq('id', currentUser.id);

    return response.map<ArcUser>((data) {
      final elo = data['elo'] as int? ?? 1500;

      return ArcUser(
        id: data['id'] as String,
        username: data['username'] as String? ?? 'Utilisateur',
        age: data['age'] as int? ?? 18,
        bio: data['bio'] as String? ?? '',
        photoUrls: [
          if (data['photo_1_url'] != null)
            data['photo_1_url'] as String,
          if (data['photo_2_url'] != null)
            data['photo_2_url'] as String,
          if (data['photo_3_url'] != null)
            data['photo_3_url'] as String,
        ],
        elo: elo,
        league: LeagueService.getLeagueFromElo(elo),
        season: data['season'] as int? ?? 1,
        eloHistory: const [],
      );
    }).toList();
  }
}