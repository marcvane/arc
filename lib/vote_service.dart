import 'package:supabase_flutter/supabase_flutter.dart';

class VoteResult {
  final int winnerChange;
  final int loserChange;
  final int votesRemaining;

  const VoteResult({
    required this.winnerChange,
    required this.loserChange,
    required this.votesRemaining,
  });
}

class VoteService {
  static final SupabaseClient _supabase =
      Supabase.instance.client;

  static Future<VoteResult> castVote({
    required String profileAId,
    required String profileBId,
    required String winnerId,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    if (profileAId == profileBId) {
      throw Exception(
        'Les deux profils doivent être différents',
      );
    }

    if (winnerId != profileAId &&
        winnerId != profileBId) {
      throw Exception(
        'Le gagnant ne correspond à aucun profil',
      );
    }

    try {
      final response = await _supabase.rpc(
        'cast_vote',
        params: {
          'p_profile_a_id': profileAId,
          'p_profile_b_id': profileBId,
          'p_winner_id': winnerId,
        },
      );

      if (response == null) {
        throw Exception(
          'Aucune réponse reçue après le vote',
        );
      }

      final data =
          Map<String, dynamic>.from(response as Map);

      return VoteResult(
        winnerChange:
            (data['winner_change'] as num).toInt(),
        loserChange:
            (data['loser_change'] as num).toInt(),
        votesRemaining:
            (data['votes_remaining'] as num).toInt(),
      );
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    } catch (error) {
      throw Exception(
        'Impossible d’enregistrer le vote : $error',
      );
    }
  }
}