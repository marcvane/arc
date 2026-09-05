import 'package:supabase_flutter/supabase_flutter.dart';

class CampusChatService {
  static final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================
  // RÉCUPÉRER LES MESSAGES D'UN CAMPUS
  // ============================================

  static Future<List<Map<String, dynamic>>>
      getMessages({
    required String campusId,
    int limit = 100,
  }) async {
    final response = await _supabase
        .from('campus_messages')
        .select(
          'id, campus_id, user_id, content, created_at, '
          'profiles!campus_messages_user_id_fkey('
          'id, username, photo_1_url'
          ')',
        )
        .eq(
          'campus_id',
          campusId,
        )
        .order(
          'created_at',
          ascending: false,
        )
        .limit(limit);

    final messages =
        List<Map<String, dynamic>>.from(
      response,
    );

    // On les remet du plus ancien au plus récent
    // pour l'affichage du chat.
    return messages.reversed.toList();
  }

  // ============================================
  // ENVOYER UN MESSAGE
  // ============================================

  static Future<void> sendMessage({
    required String campusId,
    required String content,
  }) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    final cleanContent =
        content.trim();

    if (cleanContent.isEmpty) {
      return;
    }

    if (cleanContent.length > 500) {
      throw Exception(
        'Le message est trop long.',
      );
    }

    await _supabase
        .from('campus_messages')
        .insert({
      'campus_id': campusId,
      'user_id': user.id,
      'content': cleanContent,
    });
  }

  // ============================================
  // SUPPRIMER SON MESSAGE
  // ============================================

  static Future<void> deleteMessage(
    String messageId,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    await _supabase
        .from('campus_messages')
        .delete()
        .eq(
          'id',
          messageId,
        )
        .eq(
          'user_id',
          user.id,
        );
  }

  // ============================================
  // ID UTILISATEUR ACTUEL
  // ============================================

  static String? get currentUserId =>
      _supabase.auth.currentUser?.id;
}