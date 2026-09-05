import 'package:supabase_flutter/supabase_flutter.dart';

class EloHistoryPoint {
  final int elo;
  final DateTime createdAt;

  const EloHistoryPoint({
    required this.elo,
    required this.createdAt,
  });
}

class EloHistoryService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<EloHistoryPoint>> getMyHistory() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    final response = await _supabase
        .from('elo_history')
        .select('elo, created_at')
        .eq('profile_id', user.id)
        .order('created_at', ascending: true);

    return response.map<EloHistoryPoint>((data) {
      return EloHistoryPoint(
        elo: data['elo'] as int,
        createdAt: DateTime.parse(
          data['created_at'] as String,
        ),
      );
    }).toList();
  }
}