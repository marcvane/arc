
import 'package:supabase_flutter/supabase_flutter.dart';

import 'model/user_model.dart';
import 'services/league_services.dart';

class ProfileService {
  static final SupabaseClient _supabase =
      Supabase.instance.client;

  static Future<List<ArcUser>> getProfiles({
    bool forVoting = false,
  }) async {
    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      throw Exception('Utilisateur non connecté');
    }

    // Pour les duels :
    // - exclure son propre profil
    // - exclure les profils modérés
    // - exclure les profils sans photo principale
    //
    // Pour les autres écrans, conserver le
    // comportement historique.

    final List<Map<String, dynamic>> response;

    if (forVoting) {
      response = await _supabase
          .from('profiles')
          .select()
          .neq('id', currentUser.id)
          .eq('excluded_from_votes', false)
          .neq('photo_1_url', '');
    } else {
      response = await _supabase
          .from('profiles')
          .select()
          .neq('id', currentUser.id);
    }

    return response.map<ArcUser>((data) {
      final elo = data['elo'] as int? ?? 1500;

      return ArcUser(
        id: data['id'] as String,

        username:
            data['username'] as String? ?? 'Utilisateur',

        age: data['age'] as int? ?? 18,

        bio: data['bio'] as String? ?? '',

        photoUrls: [
          if (data['photo_1_url'] is String &&
              (data['photo_1_url'] as String)
                  .trim()
                  .isNotEmpty)
            data['photo_1_url'] as String,

          if (data['photo_2_url'] is String &&
              (data['photo_2_url'] as String)
                  .trim()
                  .isNotEmpty)
            data['photo_2_url'] as String,

          if (data['photo_3_url'] is String &&
              (data['photo_3_url'] as String)
                  .trim()
                  .isNotEmpty)
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
