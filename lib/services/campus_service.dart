import 'package:supabase_flutter/supabase_flutter.dart';

class CampusService {
  static final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================
  // RÉCUPÉRER TOUS LES CAMPUS
  // ============================================

  static Future<List<Map<String, dynamic>>>
      getCampuses() async {
    final response = await _supabase
        .from('campuses')
        .select(
          'id, name, slug, city, country, '
          'latitude, longitude',
        )
        .order('name');

    return List<Map<String, dynamic>>.from(
      response,
    );
  }

  // ============================================
  // CAMPUS POUR LA CARTE
  //
  // Ajoute :
  // - score collectif
  // - nombre de membres
  // ============================================

  static Future<List<Map<String, dynamic>>>
      getCampusesForMap() async {
    final campusResponse =
        await _supabase
            .from('campuses')
            .select(
              'id, name, slug, city, country, '
              'latitude, longitude',
            )
            .not(
              'latitude',
              'is',
              null,
            )
            .not(
              'longitude',
              'is',
              null,
            )
            .order('name');

    final campusList =
        List<Map<String, dynamic>>.from(
      campusResponse,
    );

    if (campusList.isEmpty) {
      return [];
    }

    final profilesResponse =
        await _supabase
            .from('profiles')
            .select(
              'campus_id, elo',
            )
            .not(
              'campus_id',
              'is',
              null,
            );

    final profiles =
        List<Map<String, dynamic>>.from(
      profilesResponse,
    );

    final mapCampuses =
        <Map<String, dynamic>>[];

    for (final campus in campusList) {
      final campusId =
          campus['id'].toString();

      int score = 0;
      int memberCount = 0;

      for (final profile in profiles) {
        if (profile['campus_id']
                ?.toString() ==
            campusId) {
          score +=
              (profile['elo'] as num?)
                      ?.toInt() ??
                  1500;

          memberCount++;
        }
      }

      mapCampuses.add({
        ...campus,
        'score': score,
        'member_count': memberCount,
      });
    }

    return mapCampuses;
  }

  // ============================================
  // REJOINDRE UN CAMPUS
  // ============================================

  static Future<void> joinCampus({
    required String campusId,
  }) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    // Vérifie que le campus existe réellement.
    final campus = await _supabase
        .from('campuses')
        .select('id')
        .eq(
          'id',
          campusId,
        )
        .maybeSingle();

    if (campus == null) {
      throw Exception(
        'Ce campus n’existe pas.',
      );
    }

    await _supabase
        .from('profiles')
        .update({
      'campus_id': campusId,

      // Ancienne logique formation.
      // On la neutralise sans supprimer
      // la colonne Supabase pour l'instant.
      'clan_id': null,
    }).eq(
      'id',
      user.id,
    );
  }

  // ============================================
  // QUITTER LE CAMPUS
  // ============================================

  static Future<void> leaveCampus() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    await _supabase
        .from('profiles')
        .update({
      'campus_id': null,
      'clan_id': null,
    }).eq(
      'id',
      user.id,
    );
  }

  // ============================================
  // CAMPUS DE L'UTILISATEUR
  // ============================================

  static Future<Map<String, dynamic>?>
      getMyCampus() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response = await _supabase
        .from('profiles')
        .select(
          'campus_id, '
          'campuses('
          'id, name, slug, city, country, '
          'latitude, longitude'
          ')',
        )
        .eq(
          'id',
          user.id,
        )
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(
      response,
    );
  }

  // ============================================
  // CLASSEMENT INTERNE DU CAMPUS
  // ============================================

  static Future<List<Map<String, dynamic>>>
      getCampusRanking(
    String campusId,
  ) async {
    final response = await _supabase
        .from('profiles')
        .select(
          'id, username, elo, league, '
          'photo_1_url',
        )
        .eq(
          'campus_id',
          campusId,
        )
        .order(
          'elo',
          ascending: false,
        )
        .limit(100);

    return List<Map<String, dynamic>>.from(
      response,
    );
  }

  // ============================================
  // CLASSEMENT DES CAMPUS
  //
  // V1 :
  // score collectif = somme des Elo
  // de tous les membres.
  // ============================================

  static Future<List<Map<String, dynamic>>>
      getUniversityRanking() async {
    final campusResponse =
        await _supabase
            .from('campuses')
            .select(
              'id, name, slug, city, country, '
              'latitude, longitude',
            )
            .order('name');

    final campusList =
        List<Map<String, dynamic>>.from(
      campusResponse,
    );

    final profilesResponse =
        await _supabase
            .from('profiles')
            .select(
              'campus_id, elo',
            )
            .not(
              'campus_id',
              'is',
              null,
            );

    final profiles =
        List<Map<String, dynamic>>.from(
      profilesResponse,
    );

    final ranking =
        <Map<String, dynamic>>[];

    for (final campus in campusList) {
      final campusId =
          campus['id'].toString();

      int totalElo = 0;
      int memberCount = 0;

      for (final profile in profiles) {
        if (profile['campus_id']
                ?.toString() ==
            campusId) {
          totalElo +=
              (profile['elo'] as num?)
                      ?.toInt() ??
                  1500;

          memberCount++;
        }
      }

      ranking.add({
        ...campus,
        'score': totalElo,
        'member_count': memberCount,
      });
    }

    ranking.sort(
      (a, b) {
        final scoreA =
            (a['score'] as num?)
                    ?.toInt() ??
                0;

        final scoreB =
            (b['score'] as num?)
                    ?.toInt() ??
                0;

        return scoreB.compareTo(
          scoreA,
        );
      },
    );

    return ranking;
  }

  // ============================================
  // SCORE COLLECTIF DU CAMPUS
  // ============================================

  static Future<int> getCampusScore(
    String campusId,
  ) async {
    final response =
        await _supabase
            .from('profiles')
            .select('elo')
            .eq(
              'campus_id',
              campusId,
            );

    final profiles =
        List<Map<String, dynamic>>.from(
      response,
    );

    int score = 0;

    for (final profile in profiles) {
      score +=
          (profile['elo'] as num?)
                  ?.toInt() ??
              1500;
    }

    return score;
  }
}