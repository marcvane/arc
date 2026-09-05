import 'package:supabase_flutter/supabase_flutter.dart';

class VoteLimitService {
  static const int maxVotesPerDay = 20;

  static final SupabaseClient _supabase =
      Supabase.instance.client;

  /// Retourne le nombre de votes déjà effectués aujourd'hui.
  static Future<int> getVotesUsedToday() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final now = DateTime.now();

    // Minuit aujourd'hui dans l'heure locale du téléphone.
    final startOfLocalDay = DateTime(
      now.year,
      now.month,
      now.day,
    );

    // Conversion en UTC pour Supabase.
    final startOfDayUtc =
        startOfLocalDay.toUtc();

    final response = await _supabase
        .from('votes')
        .select('id')
        .eq('voter_id', user.id)
        .gte(
          'created_at',
          startOfDayUtc.toIso8601String(),
        );

    return response.length;
  }

  /// Retourne le nombre de votes encore disponibles aujourd'hui.
  static Future<int> getRemainingVotes() async {
    final votesUsed =
        await getVotesUsedToday();

    final remaining =
        maxVotesPerDay - votesUsed;

    if (remaining <= 0) {
      return 0;
    }

    return remaining;
  }

  /// Indique si l'utilisateur peut encore voter aujourd'hui.
  static Future<bool> canVote() async {
    final remaining =
        await getRemainingVotes();

    return remaining > 0;
  }
}